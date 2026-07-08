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
  }
  static final AlertService instance = AlertService._internal();

  final _controller = StreamController<AlertEvent>.broadcast();
  Stream<AlertEvent> get alertStream => _controller.stream;

  late final StreamSubscription<SeatStatus> _sub;
  final _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationsInitialized = false;

  Timer? _escalationTimer;
  DateTime? _escalationStartedAt;
  AlertReason _lastReason = AlertReason.none;
  static const Duration escalationDelay = Duration(seconds: 20);

  /// Time left before L3 Telegram escalation; zero if not armed.
  Duration get escalationRemaining {
    final started = _escalationStartedAt;
    if (started == null) return Duration.zero;
    final remaining = escalationDelay - DateTime.now().difference(started);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> initNotifications() async {
    if (_notificationsInitialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _notificationsInitialized = true;
  }

  void _onStatus(SeatStatus status) {
    final reason = status.reason;
    final severity = status.severity;
    final message = _messageFor(reason);

    _controller.add(AlertEvent(severity, reason, message));

    if (reason == AlertReason.none) {
      _escalationTimer?.cancel();
      _escalationStartedAt = null;
      _lastReason = AlertReason.none;
      return;
    }

    // Only re-notify and re-arm escalation on a NEW reason, not every stream tick.
    if (reason != _lastReason) {
      _lastReason = reason;
      _showPushNotification(severity, message);
      _writeLog(reason, message);

      _escalationTimer?.cancel();
      if (severity == SeatSeverity.warning) {
        _escalationStartedAt = DateTime.now();
        _escalationTimer = Timer(escalationDelay, () => _escalate(reason, message));
      } else {
        _escalationStartedAt = null;
      }
    }
  }

  /// Call this from AlertScreen when the caregiver acknowledges the alert.
  void acknowledge() {
    _escalationTimer?.cancel();
    _escalationStartedAt = null;
  }

  Future<void> _showPushNotification(SeatSeverity severity, String message) async {
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
    // Re-check current reason hasn't changed/cleared before escalating.
    if (_lastReason != reason) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'send-telegram-alert',
        body: {'event': _eventNameFor(reason), 'message': message},
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
    _escalationTimer?.cancel();
    _escalationStartedAt = null;
    _controller.close();
  }
}
