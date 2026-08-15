import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/seat_status.dart';

class LiveService {
  final SupabaseClient _db = Supabase.instance.client;

  /// ESP32 PATCHes `live` id=1 (`present`, `buckled`, `battery`, …).
  /// Seed the stream with a REST read so Home isn't stuck on a stale/empty row
  /// until the next Realtime event.
  Stream<SeatStatus> liveStream() async* {
    try {
      final row = await _db.from('live').select().eq('id', 1).maybeSingle();
      if (row != null) yield SeatStatus.fromMap(row);
    } catch (_) {}

    yield* _db
        .from('live')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .map((rows) =>
            rows.isEmpty ? SeatStatus.empty() : SeatStatus.fromMap(rows.first));
  }
}
