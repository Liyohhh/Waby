import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyService {
  final SupabaseClient _db = Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  Future<String?> myFamilyId() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _db.from('profiles').select('family_id').eq('id', uid).maybeSingle();
    return row?['family_id'] as String?;
  }

  Future<void> createFamily(String name) async {
    await _db.rpc('create_family', params: {'p_name': name});
  }

  Future<void> joinFamily(String code) async {
    // Throws a PostgrestException with message 'Invalid invite code' on a bad code.
    await _db.rpc('join_family', params: {'p_code': code});
  }
}
