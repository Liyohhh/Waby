import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/child.dart';

class ChildService {
  final SupabaseClient _db = Supabase.instance.client;

  /// Live stream of children in the caller's family (RLS-scoped).
  Stream<List<Child>> myChildrenStream() {
    if (_db.auth.currentUser == null) return Stream.value([]);

    return _db
        .from('children')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(Child.fromMap).toList());
  }
}
