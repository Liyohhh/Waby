import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/child.dart';

class ChildService {
  final SupabaseClient _db = Supabase.instance.client;

  Stream<List<Child>> myChildrenStream() {
    return _db
        .from('children')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(Child.fromMap).toList());
  }
}
