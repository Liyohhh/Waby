import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/child.dart';
import '../models/seat_status.dart';
import 'alert_feedback_service.dart';
import 'child_service.dart';
import 'live_service.dart';
import 'push_notification_service.dart';

String alertIdOf({
  required String childId,
  required String alertType,
  required DateTime startedAt,
}) =>
    '$childId::$alertType::${startedAt.millisecondsSinceEpoch}';

class ActiveAlert {
  final String alertId;
  final String childId;
  final String childName;
  final String alertType;
  final AlertSeverity severity;
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
    required this.severity,
    required this.startedAt,
    required this.totalSeconds,
    required this.tier,
    required this.telegramSent,
    required this.lastNotifiedCount,
    required this.message,
    required this.detail,
  });
}

class AlertService {
  AlertService._internal() {
    _liveSub = LiveService().liveStream().listen(_onStatus);
    _childrenSub = _childService.myChildrenStream().listen(_onChildren);
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick());
    });
    refreshAlertTimerSetting();
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
  String _primaryChildId = 'primary-child';
  String _primaryChildName = 'Your child';
  final Map<String, _PendingAlert> _pending = {};
  final Map<String, _TrackedAlert> _active = {};
  final Set<String> _autoFired = <String>{};

  bool get sheetOpen => _sheetOpen;
  void setSheetOpen(bool value) => _sheetOpen = value;

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

  int totalSecondsFor(AlertReason reason) {
    if (reason == AlertReason.heat) {
      return (_alertTimerSeconds / 2).ceil().clamp(15, 90);
    }
    return _alertTimerSeconds;
  }

  double _tier1Fraction(AlertReason reason) =>
      reason == AlertReason.heat ? 0.2 : 0.25;

  static const Duration heatDebounce = Duration(seconds: 15);
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
      if (!tracked.isCritical) continue;

      final tier = _tierFor(tracked.reason, tracked.startedAt, tracked.totalSeconds);
      if (tier != tracked.tier) {
        tracked.tier = tier;
        changed = true;
      }

      if (tier >= 2 && tracked.lastFiredTier < tier && tier <= 3) {
        tracked.lastFiredTier = tier;
        await _emitUserFacingAlert(tracked, notify: tier == 2);
      }

      if (_remainingSeconds(tracked.startedAt, tracked.totalSeconds) <= 0 &&
          !_autoFired.contains(tracked.alertId)) {
        _autoFired.add(tracked.alertId);
        tracked.telegramSent = true;
        await _escalate(tracked);
        await AlertFeedbackService.instance.stop();
        await PushNotificationService.instance.cancelAll();
        changed = true;
      }
    }

    if (changed) _emit();
  }

  Future<void> acknowledgeAlert(String alertId) async {
    _resolveAlert(alertId);
    _emit();
  }

  void _resolveAlert(String alertId) {
    final removed = _active.remove(alertId);
    _autoFired.remove(alertId);
    if (removed != null) {
      unawaited(AlertFeedbackService.instance.stop());
      unawaited(PushNotificationService.instance.cancelAll());
    }
  }

  void _activate(_AlertCondition condition, DateTime startedAt) {
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
      severity: condition.severity,
      startedAt: startedAt,
      totalSeconds: totalSecondsFor(condition.reason),
      tier: 1,
      lastFiredTier: 1,
      telegramSent: false,
      lastNotifiedCount: 0,
      message: condition.message,
      detail: condition.detail,
    );
    _active[alert.alertId] = alert;
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
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final tier1End = (totalSeconds * _tier1Fraction(reason)).round();
    final tier2End = (totalSeconds * 0.5).round();
    if (elapsed < tier1End) return 1;
    if (elapsed < tier2End) return 2;
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
      );
    }

    if (!notify || inForeground) return;

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

  Future<void> _escalate(_TrackedAlert alert) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('family_id')
          .eq('id', userId)
          .maybeSingle();
      final familyId = profile?['family_id'] as String?;
      if (familyId == null) return;

      final response = await Supabase.instance.client.functions.invoke(
        'send-telegram-alert',
        body: {
          'event': _eventNameFor(alert.reason),
          'message': alert.message,
          'family_id': familyId,
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

    if (status.present && !status.buckled && status.distanceNear) {
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
    if (status.present && status.temperature > 30) {
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
    if (status.battery < 20) {
      conditions.add(_AlertCondition(
        childId: childId,
        childName: childName,
        reason: AlertReason.lowBattery,
        alertType: 'low_battery',
        severity: AlertSeverity.caution,
        message: 'Device battery is running low.',
        detail: 'Seat device battery — ${status.battery}%',
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
            severity: a.severity,
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
            detail: "$childName's seat — 34.0°C",
          ),
          now,
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
        );
      case AlertReason.lowBattery:
        _activate(
          _AlertCondition(
            childId: childId,
            childName: childName,
            reason: reason,
            alertType: 'low_battery',
            severity: AlertSeverity.caution,
            message: 'Device battery is running low.',
            detail: 'Seat device battery — 15%',
          ),
          now,
        );
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
  final AlertSeverity severity;
  final DateTime startedAt;
  final int totalSeconds;
  int tier;
  int lastFiredTier;
  bool telegramSent;
  int lastNotifiedCount;
  String message;
  String detail;

  _TrackedAlert({
    required this.alertId,
    required this.childId,
    required this.childName,
    required this.alertType,
    required this.reason,
    required this.severity,
    required this.startedAt,
    required this.totalSeconds,
    required this.tier,
    required this.lastFiredTier,
    required this.telegramSent,
    required this.lastNotifiedCount,
    required this.message,
    required this.detail,
  });

  bool get isCritical =>
      severity == AlertSeverity.warning || severity == AlertSeverity.critical;
}
