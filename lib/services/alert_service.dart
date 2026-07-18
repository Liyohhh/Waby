import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/seat_status.dart';
import 'live_service.dart';

class AlertEvent {
  final SeatSeverity severity;
  final AlertReason reason;
  final String message;
  const AlertEvent(this.severity, this.reason, this.message);
}

class AlertService {
  AlertService._internal() {
    _sub = LiveService().liveStream().listen(_onStatus);
    refreshAlertTimerSetting();
  }
  static final AlertService instance = AlertService._internal();

  final _controller = StreamController<AlertEvent>.broadcast();
  Stream<AlertEvent> get alertStream => _controller.stream;

  late final StreamSubscription<SeatStatus> _sub;
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  // ── Configurable base escalation delay ────────────────────────────────
  // Heat uses half of this, left-behind uses the full value. Synced from
  // profiles.alert_timer_seconds (30-90s range, enforced server-side).
  int _alertTimerSeconds = 60;

  /// Call after the user changes the "Auto-alert timer" setting so the
  /// running app picks up the new value immediately.
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

  /// Total escalation window (seconds) for [reason] at the current
  /// setting. Public so AlertScreen can render an accurate countdown.
  int totalSecondsFor(AlertReason reason) {
    if (reason == AlertReason.heat) {
      return (_alertTimerSeconds / 2).ceil().clamp(15, 90);
    }
    return _alertTimerSeconds;
  }

  // Tier 1 ends at this fraction of the total; tier 2 always ends at the
  // 50% mark, so tier 3 (the countdown) is always the back half of the
  // window regardless of reason.
  double _tier1Fraction(AlertReason reason) =>
      reason == AlertReason.heat ? 0.2 : 0.25;

  // ── Grace period (pre-alert debounce) ─────────────────────────────────
  // Absorbs benign real-world scenarios (e.g. paying for gas) for
  // left-behind, and sensor noise for heat, before an alert is even shown.
  static const Duration heatDebounce = Duration(seconds: 15);
  static const Duration leftBehindGrace = Duration(minutes: 2);

  AlertReason _pendingReason = AlertReason.none;
  Timer? _graceTimer;

  // ── Active tiered alert state ──────────────────────────────────────────
  AlertReason _activeReason = AlertReason.none;
  DateTime? _activeSince;
  Timer? _tickTimer;
  int _lastFiredTier = 0;
  bool _telegramSent = false;

  // ── Non-critical (caution) one-shot state ─────────────────────────────
  AlertReason _lastCautionReason = AlertReason.none;

  /// Current tier of the active alert: 0 = none, 1 = reminder,
  /// 2 = urgent, 3 = countdown-to-emergency-contact.
  int get currentTier {
    final since = _activeSince;
    if (_activeReason == AlertReason.none || since == null) return 0;
    final total = totalSecondsFor(_activeReason);
    final elapsed = DateTime.now().difference(since).inSeconds;
    final tier1End = (total * _tier1Fraction(_activeReason)).round();
    final tier2End = (total * 0.5).round();
    if (elapsed < tier1End) return 1;
    if (elapsed < tier2End) return 2;
    return 3;
  }

  /// Time left until the Telegram emergency-contact alert fires. Zero if
  /// nothing is active.
  Duration get escalationRemaining {
    final since = _activeSince;
    if (_activeReason == AlertReason.none || since == null) {
      return Duration.zero;
    }
    final total = totalSecondsFor(_activeReason);
    final elapsed = DateTime.now().difference(since).inSeconds;
    final remaining = total - elapsed;
    return remaining <= 0 ? Duration.zero : Duration(seconds: remaining);
  }

  /// True once the Telegram emergency-contact alert has actually been
  /// sent for the currently-active alert.
  bool get telegramSent => _telegramSent;

  Future<void> initNotifications() async {
    if (_notificationsInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _notificationsInitialized = true;
  }

  void _onStatus(SeatStatus status) {
    final reason = status.reason;
    final severity = status.severity;
    final message = _messageFor(reason);

    if (reason == AlertReason.none) {
      _clearPending();
      _clearActive();
      _lastCautionReason = AlertReason.none;
      _controller.add(AlertEvent(severity, reason, message));
      return;
    }

    // Non-critical: single one-shot notification, no grace period, no
    // escalation ladder at all. Matches CAUTION severity (buckle reminder,
    // low battery) — caregiver is confirmed nearby, or it's a maintenance
    // notice, neither is a safety emergency.
    if (severity != SeatSeverity.warning) {
      _clearPending();
      _clearActive();
      if (reason != _lastCautionReason) {
        _lastCautionReason = reason;
        _showPushNotification(severity, message);
        _writeLog(reason, message);
        _controller.add(AlertEvent(severity, reason, message));
      }
      return;
    }

    // From here: severity == warning (heat or left-behind).
    _lastCautionReason = AlertReason.none;

    if (_activeReason == reason) return; // already ticking
    if (_pendingReason == reason) return; // already in its grace period

    // New critical condition — start its grace period from scratch.
    _clearPending();
    _clearActive();
    _pendingReason = reason;
    final debounce =
        reason == AlertReason.heat ? heatDebounce : leftBehindGrace;
    _graceTimer = Timer(debounce, () => _promoteToActive(reason));
  }

  void _promoteToActive(AlertReason reason) {
    _pendingReason = AlertReason.none;
    _activeReason = reason;
    _activeSince = DateTime.now();
    _telegramSent = false;

    final message = _messageFor(reason);
    _showPushNotification(SeatSeverity.warning, message);
    _writeLog(reason, message);
    _controller.add(AlertEvent(SeatSeverity.warning, reason, message));
    _lastFiredTier = 1;

    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _tick() async {
    final reason = _activeReason;
    final since = _activeSince;
    if (reason == AlertReason.none || since == null) return;

    final total = totalSecondsFor(reason);
    final elapsed = DateTime.now().difference(since).inSeconds;
    final tier1End = (total * _tier1Fraction(reason)).round();
    final tier2End = (total * 0.5).round();

    int tier;
    if (elapsed < tier1End) {
      tier = 1;
    } else if (elapsed < tier2End) {
      tier = 2;
    } else if (elapsed < total) {
      tier = 3;
    } else {
      tier = 4; // past the countdown — fire Telegram
    }

    if (tier == 2 && _lastFiredTier < 2) {
      _lastFiredTier = 2;
      await _showPushNotification(
        SeatSeverity.warning,
        'URGENT — still unresolved: ${_messageFor(reason)}',
      );
    } else if (tier == 3 && _lastFiredTier < 3) {
      _lastFiredTier = 3;
      // No separate push here — AlertScreen switches to the visible
      // countdown ring at this point on its own polling.
    }

    if (tier >= 4 && !_telegramSent) {
      _telegramSent = true;
      await _escalate(reason, _messageFor(reason));
    }
  }

  void _clearPending() {
    _graceTimer?.cancel();
    _graceTimer = null;
    _pendingReason = AlertReason.none;
  }

  void _clearActive() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _activeReason = AlertReason.none;
    _activeSince = null;
    _lastFiredTier = 0;
    _telegramSent = false;
  }

  /// Call this from AlertScreen when the caregiver acknowledges the alert.
  /// Resets state entirely — if the underlying condition is still true on
  /// the next sensor reading, a fresh grace period starts before it can
  /// alert again, avoiding an instant re-trigger loop right after ack.
  void acknowledge() {
    _clearActive();
  }

  /// Fires a synthetic sensor reading through the exact same detection
  /// logic real alerts use — genuinely exercises the tier system, logging,
  /// and push notifications, not just the AlertScreen UI. Skips the grace
  /// period (the whole point is instant preview), but keeps the real
  /// Tier 1→2→3→Telegram timing from that point on.
  void fireTestAlert(AlertReason reason) {
    if (reason == AlertReason.none) return;
    final severity = (reason == AlertReason.buckleReminder ||
            reason == AlertReason.lowBattery)
        ? SeatSeverity.caution
        : SeatSeverity.warning;
    final message = _messageFor(reason);

    if (severity != SeatSeverity.warning) {
      _clearPending();
      _clearActive();
      _lastCautionReason = reason;
      _showPushNotification(severity, message);
      _writeLog(reason, message);
      _controller.add(AlertEvent(severity, reason, message));
      return;
    }

    _clearPending();
    _clearActive();
    _promoteToActive(reason);
  }

  Future<void> _showPushNotification(
      SeatSeverity severity, String message) async {
    await initNotifications();
    const androidDetails = AndroidNotificationDetails(
      'waby_alerts',
      'Waby Alerts',
      channelDescription: 'Seat safety alerts',
      importance: Importance.max,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _notifications.show(
      0,
      severity == SeatSeverity.warning ? 'Waby Warning' : 'Waby Caution',
      message,
      details,
    );
  }

  /// Fires a real push notification through the same channel and setup as
  /// live alerts, without needing to trigger an actual sensor condition.
  Future<void> sendTestNotification() async {
    await _showPushNotification(
      SeatSeverity.caution,
      'This is a test notification from Waby.',
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

  Future<void> _escalate(AlertReason reason, String message) async {
    if (_activeReason != reason) return; // condition changed/cleared already
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

      await Supabase.instance.client.functions.invoke(
        'send-telegram-alert',
        body: {
          'event': _eventNameFor(reason),
          'message': message,
          'family_id': familyId,
        },
      );
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

  String _messageFor(AlertReason reason) {
    switch (reason) {
      case AlertReason.leftBehind:
        return 'Child detected in the seat with no caregiver nearby.';
      case AlertReason.heat:
        return 'Seat temperature has exceeded a safe level.';
      case AlertReason.buckleReminder:
        return 'Child is in the seat but not buckled in.';
      case AlertReason.lowBattery:
        return 'Device battery is running low.';
      case AlertReason.none:
        return '';
    }
  }

  void dispose() {
    _sub.cancel();
    _graceTimer?.cancel();
    _tickTimer?.cancel();
    _controller.close();
  }
}
