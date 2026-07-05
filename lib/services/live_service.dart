import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/seat_status.dart';

class LiveService {
  final SupabaseClient _db = Supabase.instance.client;

  Stream<SeatStatus> liveStream() {
    return _db
        .from('live')
        .stream(primaryKey: ['id'])
        .eq('id', 1)
        .map((rows) =>
            rows.isEmpty ? SeatStatus.empty() : SeatStatus.fromMap(rows.first));
  }
}
