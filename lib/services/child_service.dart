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

  Future<void> updateChild({
    required String id,
    String? name,
    DateTime? dob,
    double? weightKg,
    double? heightCm,
  }) async {
    final data = <String, dynamic>{
      'weight_kg': weightKg,
      'height_cm': heightCm,
    };
    if (name != null) data['name'] = name;
    if (dob != null) data['dob'] = dob.toIso8601String().split('T').first;
    await _db.from('children').update(data).eq('id', id);
  }

  Future<void> updateChildPhoto(String id, String? photoPath) async {
    await _db.from('children').update({'photo_path': photoPath}).eq('id', id);
  }
}
