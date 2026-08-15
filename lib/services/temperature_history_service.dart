import 'package:supabase_flutter/supabase_flutter.dart';

class TemperatureSample {
  const TemperatureSample({
    required this.recordedAt,
    required this.temperature,
  });

  final DateTime recordedAt;
  final double temperature;
}

/// Reads (and optionally records) DHT samples for the 12-hour analytics graph.
///
/// History lives in `temperature_samples`. A Supabase trigger on `live`
/// UPDATE is the source of truth even when the app is closed; the app also
/// inserts at most once per minute as a fallback if the trigger is missing.
class TemperatureHistoryService {
  TemperatureHistoryService._();
  static final instance = TemperatureHistoryService._();

  final SupabaseClient _db = Supabase.instance.client;
  DateTime? _lastRecordedAt;

  Future<void> recordIfDue(double temperature) async {
    if (temperature <= 0) return;
    final now = DateTime.now();
    if (_lastRecordedAt != null &&
        now.difference(_lastRecordedAt!) < const Duration(minutes: 1)) {
      return;
    }
    try {
      await _db.from('temperature_samples').insert({
        'temperature': temperature,
      });
      _lastRecordedAt = now;
    } catch (_) {
      // Table / RLS not deployed yet — graph falls back to the live reading.
    }
  }

  Future<List<TemperatureSample>> fetchLast12Hours() async {
    try {
      final since =
          DateTime.now().toUtc().subtract(const Duration(hours: 12));
      final rows = await _db
          .from('temperature_samples')
          .select('recorded_at, temperature')
          .gte('recorded_at', since.toIso8601String())
          .order('recorded_at');
      return (rows as List)
          .map((row) {
            final map = row as Map<String, dynamic>;
            return TemperatureSample(
              recordedAt: DateTime.tryParse(map['recorded_at'].toString()) ??
                  DateTime.now(),
              temperature:
                  (num.tryParse(map['temperature'].toString()) ?? 0).toDouble(),
            );
          })
          .where((s) => s.temperature > 0)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Twelve hourly averages, oldest → newest. Null = no samples in that hour.
  static List<double?> hourlyBuckets(
    List<TemperatureSample> samples,
    DateTime now,
  ) {
    final sums = List<double>.filled(12, 0);
    final counts = List<int>.filled(12, 0);
    for (final sample in samples) {
      final hoursAgo = now.difference(sample.recordedAt).inMinutes / 60.0;
      if (hoursAgo < 0 || hoursAgo > 12) continue;
      var idx = 11 - hoursAgo.floor();
      if (idx < 0) idx = 0;
      if (idx > 11) idx = 11;
      sums[idx] += sample.temperature;
      counts[idx] += 1;
    }
    return List<double?>.generate(
      12,
      (i) => counts[i] > 0 ? sums[i] / counts[i] : null,
    );
  }

  /// Carry-forward fill so the line can draw across sparse hours.
  /// If there is no history yet, return only the live reading (no fake 12h line).
  static List<double> fillBuckets(List<double?> buckets, double? nowTemp) {
    final hasHistory = buckets.any((b) => b != null);
    if (!hasHistory) {
      return nowTemp != null && nowTemp > 0 ? [nowTemp] : const [];
    }
    final filled = List<double?>.from(buckets);
    if (nowTemp != null && nowTemp > 0) {
      filled[11] = nowTemp;
    }
    double? last;
    for (var i = 0; i < filled.length; i++) {
      if (filled[i] != null) {
        last = filled[i];
      } else if (last != null) {
        filled[i] = last;
      }
    }
    double? next;
    for (var i = filled.length - 1; i >= 0; i--) {
      if (filled[i] != null) {
        next = filled[i];
      } else if (next != null) {
        filled[i] = next;
      }
    }
    return filled.whereType<double>().toList();
  }
}
