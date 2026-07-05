import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contact.dart';

class ContactService {
  final SupabaseClient _db = Supabase.instance.client;

  String? get _userId => _db.auth.currentUser?.id;

  // CREATE — always tags the row with the current user's id
  Future<void> addContact({
    required String name,
    required String phone,
    required String relation,
  }) async {
    final uid = _userId;
    await _db.from('contacts').insert({
      if (uid != null) 'user_id': uid,
      'name': name,
      'phone': phone,
      'relation': relation,
    });
  }

  // READ (live stream, filtered to this user, ordered by name)
  Stream<List<Contact>> contactsStream() {
    final uid = _userId;
    // No authenticated user → return an empty stream
    if (uid == null) return Stream.value([]);

    return _db
        .from('contacts')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('name')
        .map((rows) =>
            rows.map((r) => Contact.fromMap(r['id'].toString(), r)).toList());
  }

  // UPDATE
  Future<void> updateContact(Contact c) async {
    await _db.from('contacts').update({
      'name': c.name,
      'phone': c.phone,
      'relation': c.relation,
    }).eq('id', c.id);
  }

  // DELETE
  Future<void> deleteContact(String id) async {
    await _db.from('contacts').delete().eq('id', id);
  }
}
