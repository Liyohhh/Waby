import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/demo_data.dart';

class FamilyService {
  final SupabaseClient _db = Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  /// Trim + uppercase, collapse spaces ("BT - 8942" → "BT-8942").
  static String normalizeInviteCode(String code) =>
      code.trim().replaceAll(RegExp(r'\s+'), '').toUpperCase();

  /// Alphanumeric-only compare key ("BT-8942" and "BT8942" match).
  static String inviteCodeKey(String code) =>
      code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  Future<String?> myFamilyId() async {
    final uid = _uid;
    if (uid == null) return null;
    final row = await _db
        .from('profiles')
        .select('family_id')
        .eq('id', uid)
        .maybeSingle();
    return row?['family_id'] as String?;
  }

  Future<String?> getInviteCode() async {
    final familyId = await myFamilyId();
    if (familyId == null) return null;
    final row = await _db
        .from('families')
        .select('invite_code')
        .eq('id', familyId)
        .maybeSingle();
    return row?['invite_code'] as String?;
  }

  /// True when the signed-in user belongs to the shared Waby demo family.
  Future<bool> isDemoFamily() async {
    final code = await getInviteCode();
    if (code == null) return false;
    return inviteCodeKey(code) ==
        inviteCodeKey(DemoAccount.inviteCode);
  }

  Future<void> createFamily(String name) async {
    await _db.rpc('create_family', params: {'p_name': name});
  }

  Future<void> joinFamily(String code) async {
    final normalized = normalizeInviteCode(code);
    await _db.rpc('join_family', params: {'p_code': normalized});
  }
}
