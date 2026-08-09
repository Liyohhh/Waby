import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibration/vibration.dart';

import '../core/constants.dart';
import '../models/child.dart';
import '../models/seat_status.dart';
import 'alert_feedback_service.dart';
import 'car_service.dart';
import 'child_service.dart';
import 'live_service.dart';
import 'push_notification_service.dart';

String alertIdOf({
  required String childId,
  required String alertType,
  required DateTime startedAt,
}) =>
    '$childId::$alertType::${startedAt.millisecondsSinceEpoch}';

AlertSeverity severityFor(String alertType, int tier) {
  if (alertType == 'buckle') return AlertSeverity.caution;
  return switch (tier) {
    1 => AlertSeverity.caution, // grey + soft caution sound
    2 => AlertSeverity.warning, // yellow/orange + warning sound
    _ => AlertSeverity.critical, // red + critical sound
  };
}

class ActiveAlert {
  final String alertId;
  final String childId;
  final String childName;
  final String alertType;
  final DateTime startedAt;
  final int totalSeconds;
  final int tier;
  final bool telegramSent;
  final int lastNotifiedCount;
  final String message;
  final String detail;

  const ActiveAlert({
    required this.alertId,
    required this.childId,
    required this.childName,
    required this.alertType,
    required this.startedAt,
    required this.totalSeconds,
    required this.tier,
    required this.telegramSent,
    required this.lastNotifiedCount,
    required this.message,
    required this.detail,
  });

  AlertSeverity get severity => severityFor(alertType, tier);
}

class AlertService {
  AlertService._internal() {
    _liveSub = LiveService().liveStream().listen(_onStatus);
    _childrenSub = _childService.myChildrenStream().listen(_onChildren);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick());
    });
    unawaited(refreshAlertTimerSetting()
        .then((_) => _loadFamilyId())
        .then((_) => _loadActiveCarName())
        .then((_) => _loadBuckleSnoozes()));
  }
  static final AlertService instance = AlertService._internal();

  final _activeController = StreamController<List<ActiveAlert>>.broadcast();
  Stream<List<ActiveAlert>> get activeAlertsStream => _activeController.stream;
  List<ActiveAlert> get activeAlerts => _sortedAlerts();

  final ChildService _childService = ChildService();
  late final StreamSubscription<SeatStatus> _liveSub;
  StreamSubscription<List<Child>>? _childrenSub;
  Timer? _tickTimer;

  int _alertTimerSeconds = 60;
  bool _sheetOpen = false;
  String? _familyId;
  String? _familyIdLoadedForUser;
  String? _activeCarName;
  String? _activeCarPlate;
  String _primaryChildId = 'primary-child';
  String _primaryChildName = 'Your child';
  final Map<String, _PendingAlert> _pending = {};
  final Map<String, _TrackedAlert> _active = {};
  final Set<String> _autoFired = <String>{};
  // Keyed by childId. After a caregiver acknowledges an ongoing buckle
  // reminder, suppress re-alerting for this window (e.g. a quick diaper
  // change) instead of instantly re-firing on the next live tick.
  final Map<String, DateTime> _buckleSnoozedUntil = {};
  static const Duration buckleAckSnooze = Duration(minutes: 5);
  static const _buckleSnoozePrefsKey = 'waby_buckle_snooze_until';

  bool get sheetOpen => _sheetOpen;
  void setSheetOpen(bool value) => _sheetOpen = value;

  /// Clears cached per-user state. Call on sign-out so the next user's
  /// alerts resolve their OWN family/car, not the previous user's.
  void resetForUserChange() {
    _familyId = null;
    _familyIdLoadedForUser = null;
    _activeCarName = null;
    _activeCarPlate = null;
    _buckleSnoozedUntil.clear();
    unawaited(_persistBuckleSnoozes());
  }

  Future<void> refreshAlertTimerSetting() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client
          .from('profiles')
          .select('alert_timer_seconds')
          .eq('id', userId)
          .maybeSingle();
      final v = data?['alert_timer_seconds'] as int?;
      if (v != null) _alertTimerSeconds = v;
    } catch (_) {
      // Keep previous/default value on failure.
    }
  }

  Future<void> _loadFamilyId() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        _familyId = null;
        _familyIdLoadedForUser = null;
        return;
      }
      final data = await Supabase.instance.client
          .from('profiles')
          .select('family_id')
          .eq('id', userId)
          .maybeSingle();
      _familyId = data?['family_id'] as String?;
      _familyIdLoadedForUser = userId;
    } catch (_) {
      // Keep previous value on transient failure.
    }
  }

  Future<void> _loadActiveCarName() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final row = await Supabase.instance.client
          .from('profiles')
          .select('active_car_id')
          .eq('id', uid)
          .maybeSingle();
      final carId = row?['active_car_id'] as String?;
      if (carId == null) {
        _activeCarName = null;
        _activeCarPlate = null;
        return;
      }
      final cars = await CarService().myCars();
      for (final c in cars) {
        if (c.id == carId) {
          _activeCarName = c.name;
          _activeCarPlate = c.plateNumber;
          return;
        }
      }
      _activeCarName = null;
      _activeCarPlate = null;
    } catch (_) {
      // Keep previous/null values on failure.
    }
  }

  Future<Map<String, dynamic>?> _latestLiveRow() async {
    try {
      final row = await Supabase.instance.client
          .from('live')
          .select(
              'temperature, latitude, longitude, gps_accuracy_m, place_name, updated_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row;
    } catch (_) {
      return null;
    }
  }

  int totalSecondsFor(AlertReason reason) {
    if (reason == AlertReason.heat) {
      return (_alertTimerSeconds / 2).ceil().clamp(15, 90);
    }
    return _alertTimerSeconds;
  }

  // Heat must persist for this long before the alert fires (not just be
  // momentarily read). Cabin temperature research shows real hot-car danger
  // develops over minutes, not seconds, so this window only needs to be long
  // enough to reject a transient sensor glitch/spike — 30s is ~30 consecutive
  // above-threshold pushes at the firmware's ~1s push rate, while still being
  // a small fraction of the multi-minute timescale over which real heat risk
  // actually builds.
  static const Duration heatDebounce = Duration(seconds: 30);
  static const Duration leftBehindGrace = Duration(minutes: 2);

  Duration _graceFor(AlertReason reason) {
    switch (reason) {
      case AlertReason.heat:
        return heatDebounce;
      case AlertReason.leftBehind:
        return leftBehindGrace;
      case AlertReason.buckleReminder:
      case AlertReason.lowBattery:
      case AlertReason.none:
        return Duration.zero;
    }
  }

  void _onChildren(List<Child> children) {
    if (children.isEmpty) return;
    _primaryChildId = children.first.id;
    _primaryChildName = children.first.name;

    var changed = false;
    for (final entry in _active.values) {
      if (entry.childId != _primaryChildId || entry.childName != _primaryChildName) {
        entry
          ..childId = _primaryChildId
          ..childName = _primaryChildName
          ..alertId = alertIdOf(
            childId: _primaryChildId,
            alertType: entry.alertType,
            startedAt: entry.startedAt,
          );
        changed = true;
      }
    }
    if (changed) _emit();
  }

  void _onStatus(SeatStatus status) {
    final now = DateTime.now();
    final conditions = _conditionsFor(status, now);
    final visibleTypes = conditions.map((c) => c.alertType).toSet();

    for (final type in _pending.keys.toList()) {
      if (!visibleTypes.contains(type)) {
        _pending.remove(type);
      }
    }
    for (final id in _active.keys.toList()) {
      final alert = _active[id]!;
      if (!visibleTypes.contains(alert.alertType)) {
        _resolveAlert(alert.alertId);
        if (alert.alertType == 'buckle') {
          // Rebuckled — any future unbuckle is a fresh episode, not a
          // continuation of one the caregiver already acknowledged.
          _buckleSnoozedUntil.remove(alert.childId);
          unawaited(_persistBuckleSnoozes());
        }
      }
    }

    for (final condition in conditions) {
      final active = _findActiveByType(condition.alertType);
      if (active != null) {
        active
          ..detail = condition.detail
          ..message = condition.message;
        continue;
      }

      final pending = _pending[condition.alertType];
      if (pending != null) {
        pending
          ..detail = condition.detail
          ..message = condition.message
          ..childId = condition.childId
          ..childName = condition.childName;
        continue;
      }

      if (condition.alertType == 'buckle') {
        final snoozedUntil = _buckleSnoozedUntil[condition.childId];
        if (snoozedUntil != null && now.isBefore(snoozedUntil)) {
          continue; // Acknowledged recently — same episode, stay quiet.
        }
      }

      final grace = _graceFor(condition.reason);
      if (grace == Duration.zero) {
        _activate(condition, now);
      } else {
        _pending[condition.alertType] = _PendingAlert.fromCondition(
          condition,
          detectedAt: now,
        );
      }
    }

    _emit();
  }

  Future<void> _tick() async {
    final now = DateTime.now();
    var changed = false;

    for (final type in _pending.keys.toList()) {
      final pending = _pending[type]!;
      if (now.difference(pending.detectedAt) >= _graceFor(pending.reason)) {
        _pending.remove(type);
        _activate(pending.toCondition(), now);
        changed = true;
      }
    }

    for (final tracked in _active.values.toList()) {
      if (!tracked.escalates) continue;

      if (tracked.alertType == 'left_behind') {
        final heatCoOccurring = _active.values.any(
          (a) => a.alertType == 'heat' && a.childId == tracked.childId,
        );
        if (heatCoOccurring) {
          final elapsedSeconds = now.difference(tracked.startedAt).inSeconds;
          if (tracked.totalSeconds > elapsedSeconds) {
            // Heat + left-behind together is the actual hot-car-death
            // pattern — collapse the remaining grace to zero so tier,
            // the countdown ring, and telegram auto-fire all treat it
            // as maxed out immediately instead of waiting out the full
            // left-behind timer.
            tracked.totalSeconds = elapsedSeconds;
            changed = true;
          }
        }
      }

      final tier = _tierFor(tracked.reason, tracked.startedAt, tracked.totalSeconds);
      if (tier != tracked.tier) {
        tracked.tier = tier;
        changed = true;
        // Push the new tier to the UI immediately. Don't let anything
        // below (sound, haptics) block this — a hung await here previously
        // froze the alert screen's color/wording on tier 1 forever, even
        // though sound and the final telegram escalation still fired.
        _emit();
      }

      if (tier != tracked.lastFiredTier && tier >= 2) {
        tracked.lastFiredTier = tier;
        await _emitUserFacingAlert(tracked, notify: true);
        // Distinctive "escalation moment" haptic at each transition.
        // Fire-and-forget: never await a vibration call from inside the
        // tick loop, since a plugin-level hang here must not block future
        // ticks or emits.
        if (await Vibration.hasVibrator()) {
          final burst = tier == 3
              ? Int64List.fromList(
                  [0, 60, 40, 60, 40, 60, 40, 60, 40, 300],
                )
              : Int64List.fromList([0, 80, 60, 80, 60, 80, 60, 200]);
          unawaited(Vibration.vibrate(pattern: burst));
        }
      }

      if (_remainingSeconds(tracked.startedAt, tracked.totalSeconds) <= 0 &&
          !_autoFired.contains(tracked.alertId)) {
        _autoFired.add(tracked.alertId);
        final shouldEscalateLocally = await _markEscalated(tracked);
        if (!shouldEscalateLocally) {
          // Server-side pg_cron already fired Telegram for this alert.
          // Skip the local function invoke, but still reflect the sent state.
          tracked.telegramSent = true;
          tracked.lastNotifiedCount = 0;
          changed = true;
          continue;
        }
        await _escalate(tracked);
        tracked.telegramSent = true;
        await AlertFeedbackService.instance.stop();
        await PushNotificationService.instance.cancelAll();
        changed = true;
      }
    }

    if (changed) _emit();
  }

  Future<void> _loadBuckleSnoozes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_buckleSnoozePrefsKey);
      if (raw == null || raw.isEmpty) return;
      final now = DateTime.now();
      for (final entry in raw.split('|')) {
        final parts = entry.split('=');
        if (parts.length != 2) continue;
        final until = DateTime.tryParse(parts[1]);
        if (until != null && until.isAfter(now)) {
          _buckleSnoozedUntil[parts[0]] = until;
        }
      }
    } catch (_) {
      // Non-fatal — snooze just won't survive restart.
    }
  }

  Future<void> _persistBuckleSnoozes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      _buckleSnoozedUntil.removeWhere((_, until) => !until.isAfter(now));
      if (_buckleSnoozedUntil.isEmpty) {
        await prefs.remove(_buckleSnoozePrefsKey);
        return;
      }
      final encoded = _buckleSnoozedUntil.entries
          .map((e) => '${e.key}=${e.value.toIso8601String()}')
          .join('|');
      await prefs.setString(_buckleSnoozePrefsKey, encoded);
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> acknowledgeAlert(String alertId) async {
    final alert = _active[alertId];
    if (alert != null && alert.alertType == 'buckle') {
      _buckleSnoozedUntil[alert.childId] =
          DateTime.now().add(buckleAckSnooze);
      unawaited(_persistBuckleSnoozes());
    }
    _resolveAlert(alertId);
    _emit();
  }

  void _resolveAlert(String alertId) {
    final removed = _active.remove(alertId);
    _autoFired.remove(alertId);
    if (removed != null) {
      unawaited(_markResolved(removed));
      unawaited(AlertFeedbackService.instance.stop());
      unawaited(PushNotificationService.instance.cancelAll());
    }
  }

  void _activate(
    _AlertCondition condition,
    DateTime startedAt, {
    bool logToServer = true,
  }) {
    final alert = _TrackedAlert(
      alertId: alertIdOf(
        childId: condition.childId,
        alertType: condition.alertType,
        startedAt: startedAt,
      ),
      childId: condition.childId,
      childName: condition.childName,
      alertType: condition.alertType,
      reason: condition.reason,
      startedAt: startedAt,
      totalSeconds: totalSecondsFor(condition.reason),
      tier: condition.alertType == 'heat' ? 3 : 1,
      lastFiredTier: condition.alertType == 'heat' ? 3 : 1,
      telegramSent: false,
      lastNotifiedCount: 0,
      message: condition.message,
      detail: condition.detail,
      eventRowId: null,
    );
    _active[alert.alertId] = alert;
    final escalates =
        condition.alertType == 'heat' || condition.alertType == 'left_behind';
    if (logToServer && escalates) {
      unawaited(_insertAlertEvent(alert));
    }
    unawaited(_emitUserFacingAlert(alert));
    unawaited(_writeLog(condition.reason, condition.message));
  }

  _TrackedAlert? _findActiveByType(String alertType) {
    for (final alert in _active.values) {
      if (alert.alertType == alertType) return alert;
    }
    return null;
  }

  int _tierFor(AlertReason reason, DateTime startedAt, int totalSeconds) {
    // Heat is an immediate physical danger reading, not a state that needs
    // time to confirm — treat it as critical the moment it's active rather
    // than ramping through caution/warning first.
    if (reason == AlertReason.heat) return 3;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final t2 = (totalSeconds * 0.33).round();
    final t3 = (totalSeconds * 0.66).round();
    if (elapsed < t2) return 1;
    if (elapsed < t3) return 2;
    return 3;
  }

  double _remainingSeconds(DateTime startedAt, int totalSeconds) {
    final elapsed = DateTime.now().difference(startedAt).inMilliseconds / 1000.0;
    return (totalSeconds - elapsed).clamp(0.0, totalSeconds.toDouble());
  }

  Future<void> _emitUserFacingAlert(
    _TrackedAlert alert, {
    bool notify = true,
  }) async {
    final inForeground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

    if (inForeground) {
      await AlertFeedbackService.instance.fire(
        alert.severity,
        tier: alert.tier,
        respectReminderPrefs: alert.alertType == 'buckle',
      );
    }

    if (!notify || inForeground) return;

    if (alert.alertType == 'buckle' &&
        alert.severity == AlertSeverity.caution) {
      final prefs = await SharedPreferences.getInstance();
      final allowPush = prefs.getBool(kPushNotificationsPrefKey) ?? true;
      if (!allowPush) return;
    }

    final (title, body) = _notificationCopyFor(alert);
    await PushNotificationService.instance.show(
      severity: alert.severity,
      title: title,
      body: body,
      notificationId: alert.alertId.hashCode,
    );
  }

  Future<void> sendTestNotification() async {
    await PushNotificationService.instance.show(
      severity: AlertSeverity.caution,
      title: 'Waby test alert',
      body: 'This is a test notification from Waby.',
    );
  }

  Future<void> _writeLog(AlertReason reason, String message) async {
    try {
      await Supabase.instance.client.from('logs').insert({
        'event': reason.name,
        'value': message,
      });
    } catch (_) {
      // Non-fatal — logging failure should never block the alert flow.
    }
  }

  Future<void> _insertAlertEvent(_TrackedAlert alert) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (_familyId == null || _familyIdLoadedForUser != currentUserId) {
      await _loadFamilyId();
    }
    final familyId = _familyId;
    if (familyId == null) return;
    try {
      final row = await Supabase.instance.client.from('alert_events').insert({
        'family_id': familyId,
        'child_id': alert.childId,
        'alert_type': alert.alertType,
        'severity': alert.severity.name,
        'message': alert.message,
        'total_seconds': alert.totalSeconds,
        'started_at': alert.startedAt.toIso8601String(),
      }).select('id').single();
      alert.eventRowId = row['id']?.toString();
      if (alert.telegramSent) {
        await _markEscalated(alert);
      }
      if (!_active.containsKey(alert.alertId)) {
        await _markResolved(alert);
      }
    } catch (_) {
      // Non-fatal — server-side escalation is a fallback only.
    }
  }

  Future<bool> _markEscalated(_TrackedAlert alert) async {
    final eventRowId = alert.eventRowId;
    if (eventRowId == null) return true;
    try {
      final rows = await Supabase.instance.client
          .from('alert_events')
          .update({
            'escalated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', eventRowId)
          .isFilter('escalated_at', null)
          .select('id');
      if (rows.isNotEmpty) return true;
      debugPrint(
        'AlertService: server-side escalation already claimed for $eventRowId',
      );
      return false;
    } catch (_) {
      // If the fallback marker fails, keep local escalation behavior.
      return true;
    }
  }

  Future<void> _markResolved(_TrackedAlert alert) async {
    final eventRowId = alert.eventRowId;
    if (eventRowId == null) return;
    try {
      await Supabase.instance.client
          .from('alert_events')
          .update({
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', eventRowId)
          .isFilter('resolved_at', null);
    } catch (_) {
      // Non-fatal.
    }
  }

  Future<void> _escalate(_TrackedAlert alert) async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      if (_familyId == null || _familyIdLoadedForUser != currentUserId) {
        await _loadFamilyId();
      }
      final familyId = _familyId;
      if (familyId == null) return;

      await _loadActiveCarName();

      final live = await _latestLiveRow();
      final response = await Supabase.instance.client.functions.invoke(
        'send-telegram-alert',
        body: {
          'event': _eventNameFor(alert.reason),
          'family_id': familyId,
          'child_name': alert.childName,
          if (_activeCarName != null && _activeCarName!.isNotEmpty)
            'car_name': _activeCarName,
          if (_activeCarPlate != null && _activeCarPlate!.isNotEmpty)
            'car_plate': _activeCarPlate,
          if (alert.reason == AlertReason.heat && live?['temperature'] != null)
            'temperature_c': (live!['temperature'] as num).toDouble(),
          if (live?['latitude'] != null)
            'latitude': (live!['latitude'] as num).toDouble(),
          if (live?['longitude'] != null)
            'longitude': (live!['longitude'] as num).toDouble(),
          if (live?['gps_accuracy_m'] != null)
            'gps_accuracy_m': (live!['gps_accuracy_m'] as num).toDouble(),
          if (live?['place_name'] != null &&
              (live!['place_name'] as String).isNotEmpty)
            'place_name': live['place_name'],
          if (live?['updated_at'] != null)
            'last_seen': live!['updated_at'].toString(),
          'message': alert.message,
        },
      );
      final data = response.data;
      alert.lastNotifiedCount =
          (data is Map && data['sent'] is int) ? data['sent'] as int : 0;
    } catch (_) {
      // Non-fatal — Telegram delivery failure shouldn't crash the app.
    }
  }

  String _eventNameFor(AlertReason reason) {
    switch (reason) {
      case AlertReason.leftBehind:
        return 'left_behind';
      case AlertReason.heat:
        return 'heat_alarm';
      case AlertReason.buckleReminder:
        return 'buckle_reminder';
      case AlertReason.lowBattery:
        return 'low_battery';
      case AlertReason.none:
        return 'none';
    }
  }

  (String, String) _notificationCopyFor(_TrackedAlert alert) {
    switch (alert.alertType) {
      case 'left_behind':
        return (
          alert.tier >= 2 ? 'Left-behind alert escalating' : 'Left-behind alert',
          '${alert.childName} may be in the car. Check immediately.',
        );
      case 'heat':
        return (
          alert.tier >= 2 ? 'Heat alert escalating' : 'Heat alarm',
          '${alert.childName} may be overheating. Check now.',
        );
      case 'buckle':
        return ('Buckle reminder', '${alert.childName} is not buckled in.');
      case 'low_battery':
        return ('Low battery alert', 'Seat device battery is running low.');
      default:
        return ('Waby alert', alert.message);
    }
  }

  List<_AlertCondition> _conditionsFor(SeatStatus status, DateTime now) {
    final conditions = <_AlertCondition>[];
    final childId = _primaryChildId;
    final childName = _primaryChildName;

    if (status.present &&
        !status.buckled &&
        status.distanceNear &&
        status.carMoving) {
      // Gated on carMoving so a parked-car unbuckle (diaper change, etc.)
      // doesn't trigger a reminder.
      conditions.add(_AlertCondition(
        childId: childId,
        childName: childName,
        reason: AlertReason.buckleReminder,
        alertType: 'buckle',
        severity: AlertSeverity.caution,
        message: 'Child is in the seat but not buckled in.',
        detail: '$childName · Buckle unlatched',
      ));
    }
    if (status.present && status.temperature > kHeatThresholdC) {
      conditions.add(_AlertCondition(
        childId: childId,
        childName: childName,
        reason: AlertReason.heat,
        alertType: 'heat',
        severity: AlertSeverity.critical,
        message: 'Seat temperature has exceeded a safe level.',
        detail: "$childName's seat — ${status.temperature.toStringAsFixed(1)}°C",
      ));
    }
    if (status.present && !status.distanceNear) {
      conditions.add(_AlertCondition(
        childId: childId,
        childName: childName,
        reason: AlertReason.leftBehind,
        alertType: 'left_behind',
        severity: AlertSeverity.warning,
        message: 'Child detected in the seat with no caregiver nearby.',
        detail: '$childName · Caregiver not nearby',
      ));
    }
    return conditions;
  }

  List<ActiveAlert> _sortedAlerts() {
    final alerts = _active.values.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return alerts
        .map(
          (a) => ActiveAlert(
            alertId: a.alertId,
            childId: a.childId,
            childName: a.childName,
            alertType: a.alertType,
            startedAt: a.startedAt,
            totalSeconds: a.totalSeconds,
            tier: a.tier,
            telegramSent: a.telegramSent,
            lastNotifiedCount: a.lastNotifiedCount,
            message: a.message,
            detail: a.detail,
          ),
        )
        .toList(growable: false);
  }

  void _emit() {
    if (_activeController.isClosed) return;
    _activeController.add(_sortedAlerts());
  }

  void fireTestAlert(AlertReason reason) {
    if (reason == AlertReason.none) return;
    final now = DateTime.now();
    final childId = _primaryChildId;
    final childName = _primaryChildName;
    switch (reason) {
      case AlertReason.buckleReminder:
        _activate(
          _AlertCondition(
            childId: childId,
            childName: childName,
            reason: reason,
            alertType: 'buckle',
            severity: AlertSeverity.caution,
            message: 'Child is in the seat but not buckled in.',
            detail: '$childName · Buckle unlatched',
          ),
          now,
          logToServer: false,
        );
      case AlertReason.heat:
        _activate(
          _AlertCondition(
            childId: childId,
            childName: childName,
            reason: reason,
            alertType: 'heat',
            severity: AlertSeverity.critical,
            message: 'Seat temperature has exceeded a safe level.',
            detail: "$childName's seat — 41.0°C",
          ),
          now,
          logToServer: false,
        );
      case AlertReason.leftBehind:
        _activate(
          _AlertCondition(
            childId: childId,
            childName: childName,
            reason: reason,
            alertType: 'left_behind',
            severity: AlertSeverity.warning,
            message: 'Child detected in the seat with no caregiver nearby.',
            detail: '$childName · Caregiver not nearby',
          ),
          now,
          logToServer: false,
        );
      case AlertReason.lowBattery:
        return;
      case AlertReason.none:
        break;
    }
    _emit();
  }

  void dispose() {
    _liveSub.cancel();
    _childrenSub?.cancel();
    _tickTimer?.cancel();
    unawaited(AlertFeedbackService.instance.stop());
    unawaited(PushNotificationService.instance.cancelAll());
    _activeController.close();
  }
}

class _AlertCondition {
  final String childId;
  final String childName;
  final AlertReason reason;
  final String alertType;
  final AlertSeverity severity;
  final String message;
  final String detail;

  const _AlertCondition({
    required this.childId,
    required this.childName,
    required this.reason,
    required this.alertType,
    required this.severity,
    required this.message,
    required this.detail,
  });
}

class _PendingAlert {
  final AlertReason reason;
  final String alertType;
  final DateTime detectedAt;
  String childId;
  String childName;
  String message;
  String detail;
  final AlertSeverity severity;

  _PendingAlert({
    required this.reason,
    required this.alertType,
    required this.detectedAt,
    required this.childId,
    required this.childName,
    required this.message,
    required this.detail,
    required this.severity,
  });

  factory _PendingAlert.fromCondition(
    _AlertCondition condition, {
    required DateTime detectedAt,
  }) {
    return _PendingAlert(
      reason: condition.reason,
      alertType: condition.alertType,
      detectedAt: detectedAt,
      childId: condition.childId,
      childName: condition.childName,
      message: condition.message,
      detail: condition.detail,
      severity: condition.severity,
    );
  }

  _AlertCondition toCondition() => _AlertCondition(
        childId: childId,
        childName: childName,
        reason: reason,
        alertType: alertType,
        severity: severity,
        message: message,
        detail: detail,
      );
}

class _TrackedAlert {
  String alertId;
  String childId;
  String childName;
  final String alertType;
  final AlertReason reason;
  final DateTime startedAt;
  int totalSeconds;
  int tier;
  int lastFiredTier;
  bool telegramSent;
  int lastNotifiedCount;
  String message;
  String detail;
  String? eventRowId;

  _TrackedAlert({
    required this.alertId,
    required this.childId,
    required this.childName,
    required this.alertType,
    required this.reason,
    required this.startedAt,
    required this.totalSeconds,
    required this.tier,
    required this.lastFiredTier,
    required this.telegramSent,
    required this.lastNotifiedCount,
    required this.message,
    required this.detail,
    required this.eventRowId,
  });

  AlertSeverity get severity => severityFor(alertType, tier);

  bool get escalates => alertType == 'heat' || alertType == 'left_behind';
}
