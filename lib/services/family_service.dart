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

  /// Joins a family by invite code and returns the family's name for a
  /// confirmation message.
  Future<String> joinFamily(String code) async {
    final normalized = normalizeInviteCode(code);
    final result = await _db
        .rpc('join_family', params: {'p_code': normalized}) as List;
    final row = result.first as Map<String, dynamic>;
    return (row['family_name'] as String?) ?? 'your family';
  }

  /// Profiles in the caller's family (RLS-scoped).
  Future<List<Map<String, dynamic>>> fetchFamilyMembers() async {
    final rows = await _db
        .from('profiles')
        .select('id, full_name, nickname, role, email, relation')
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Live stream of family profiles (RLS-scoped; includes relation).
  Stream<List<Map<String, dynamic>>> familyMembersStream() {
    return _db
        .from('profiles')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  /// Family owner, current user id, and member rows for management UI.
  Future<Map<String, dynamic>> fetchFamilyData() async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final me = await _db
        .from('profiles')
        .select('family_id')
        .eq('id', uid)
        .single();
    final familyId = me['family_id'];
    if (familyId == null) throw Exception('No family');

    final family = await _db
        .from('families')
        .select('created_by')
        .eq('id', familyId)
        .single();
    final members = await _db
        .from('profiles')
        .select('id, full_name, nickname, email, role, avatar_path')
        .order('created_at');

    return {
      'ownerId': family['created_by'],
      'myId': uid,
      'members': List<Map<String, dynamic>>.from(members),
    };
  }

  Future<void> removeFamilyMember(String targetId) async {
    await _db.rpc('remove_family_member', params: {'p_target': targetId});
  }

  Future<void> leaveFamily() async {
    await _db.rpc('leave_family');
  }
}
