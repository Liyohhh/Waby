import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'alert_feedback_service.dart';

const _kChannelCaution = 'waby_alert_caution';
const _kChannelWarning = 'waby_alert_warning';
const _kChannelCritical = 'waby_alert_critical';

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _kChannelCaution,
        'Waby Caution Alerts',
        description: 'Lower-severity Waby caution alerts',
        importance: Importance.defaultImportance,
        sound: const RawResourceAndroidNotificationSound('alert_caution'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 200, 150, 200]),
        playSound: true,
      ),
    );

    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _kChannelWarning,
        'Waby Warning Alerts',
        description: 'High-severity Waby warning alerts',
        importance: Importance.high,
        sound: const RawResourceAndroidNotificationSound('alert_warning'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 400, 150, 400]),
        playSound: true,
      ),
    );

    await android?.createNotificationChannel(
      AndroidNotificationChannel(
        _kChannelCritical,
        'Waby Critical Alerts',
        description: 'Critical Waby alerts that may wake the screen',
        importance: Importance.max,
        sound: const RawResourceAndroidNotificationSound('alert_critical'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 100, 300, 100, 300]),
        playSound: true,
      ),
    );

    _initialized = true;
  }

  Future<void> show({
    required AlertSeverity severity,
    required String title,
    required String body,
    int? notificationId,
    bool playSound = true,
  }) async {
    await init();

    late final AndroidNotificationDetails androidDetails;
    switch (severity) {
      case AlertSeverity.caution:
        androidDetails = AndroidNotificationDetails(
          _kChannelCaution,
          'Waby Caution Alerts',
          channelDescription: 'Lower-severity Waby caution alerts',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.status,
          playSound: playSound,
          enableVibration: playSound,
        );
      case AlertSeverity.warning:
        androidDetails = AndroidNotificationDetails(
          _kChannelWarning,
          'Waby Warning Alerts',
          channelDescription: 'High-severity Waby warning alerts',
          importance: Importance.high,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          playSound: playSound,
          enableVibration: playSound,
        );
      case AlertSeverity.critical:
        androidDetails = AndroidNotificationDetails(
          _kChannelCritical,
          'Waby Critical Alerts',
          channelDescription: 'Critical Waby alerts that may wake the screen',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: playSound,
          enableVibration: playSound,
        );
    }

    await _plugin.show(
      notificationId ?? severity.index,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
