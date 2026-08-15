import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

/// In-app alert audio + haptic feedback (foreground path).
///
/// Volume ramps with escalation [tier] (baseline → escalated). Call [stop]
/// whenever the alert ends so playback never leaks past the alert UI.
enum AlertSeverity { caution, warning, critical }

const kPushNotificationsPrefKey = 'settings_app_alerts';
const kVibrationPrefKey = 'settings_vibration';
const kSoundPrefKey = 'settings_sound';

class AlertFeedbackService {
  AlertFeedbackService._internal();
  static final AlertFeedbackService instance = AlertFeedbackService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  static const _assetFor = {
    AlertSeverity.caution: 'sounds/alert_caution.mp3',
    AlertSeverity.warning: 'sounds/alert_warning.mp3',
    AlertSeverity.critical: 'sounds/alert_critical.mp3',
  };

  /// Volume by severity and escalation tier — each step is a clear jump.
  double _volumeFor(AlertSeverity severity, int tier) {
    if (severity == AlertSeverity.caution) return 0.6;
    if (tier <= 2) return 0.85;
    return 1.0;
  }

  /// Start (or re-start) looping alert sound + vibration for [severity].
  /// Passing a higher [tier] raises volume for the escalation ramp.
  ///
  /// [respectReminderPrefs] should only be true for buckle reminders. Danger
  /// alerts may start softly at tier 1, but they still must not be silenced by
  /// the reminder toggles.
  Future<void> fire(
    AlertSeverity severity, {
    required int tier,
    bool respectReminderPrefs = true,
  }) async {
    final asset = _assetFor[severity];
    if (asset == null) return;

    var allowSound = true;
    var allowVibration = true;
    if (severity == AlertSeverity.caution && respectReminderPrefs) {
      final prefs = await SharedPreferences.getInstance();
      allowSound = prefs.getBool(kSoundPrefKey) ?? false;
      allowVibration = prefs.getBool(kVibrationPrefKey) ?? true;
      if (!allowSound && !allowVibration) return;
    }

    final volume = _volumeFor(severity, tier);
    try {
      if (allowSound) {
        await _player.stop();
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.setVolume(volume);
        await _player.play(AssetSource(asset));
        _playing = true;
      } else {
        await _player.stop();
        _playing = false;
      }

      if (allowVibration && await Vibration.hasVibrator()) {
        final pattern = switch (tier) {
          1 => Int64List.fromList([0, 400, 200, 400]), // slow double-pulse
          2 => Int64List.fromList([0, 200, 100, 200, 100, 200]), // medium burst
          _ => Int64List.fromList(
              [0, 200, 100, 200, 100, 200, 100, 200],
            ), // rapid burst
        };
        await Vibration.vibrate(pattern: pattern, repeat: 0);
      }
    } catch (_) {
      // Non-fatal — audio failure must never block the alert path.
    }
  }

  /// Short pulse so the Settings toggle can prove the motor works.
  Future<void> previewVibration() async {
    try {
      if (!await Vibration.hasVibrator()) return;
      await Vibration.vibrate(duration: 180);
    } catch (_) {}
  }

  Future<void> cancelVibration() async {
    try {
      await Vibration.cancel();
    } catch (_) {}
  }

  /// Stop looping audio (idempotent).
  Future<void> stop() async {
    await cancelVibration();
    if (!_playing) {
      try {
        await _player.stop();
      } catch (_) {}
      return;
    }
    _playing = false;
    try {
      await _player.stop();
    } catch (_) {
      // Non-fatal.
    }
  }
}
