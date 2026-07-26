import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contact.dart';

class ContactService {
  final SupabaseClient _db = Supabase.instance.client;

  // CREATE — family_id is stamped by the database trigger.
  Future<void> addContact({
    required String name,
    required String phone,
    required String relation,
  }) async {
    await _db.from('contacts').insert({
      'name': name,
      'phone': phone,
      'relation': relation,
    });
  }

  // READ (live stream, scoped by RLS to the caller's family)
  Stream<List<Contact>> contactsStream() {
    return _db
        .from('contacts')
        .stream(primaryKey: ['id'])
        .order('name')
        .map((rows) =>
            rows.map((r) => Contact.fromMap(r['id'].toString(), r)).toList());
  }

  // READ (one-shot fetch, scoped by RLS to the caller's family)
  Future<List<Contact>> contactsList() async {
    final rows = await _db.from('contacts').select().order('name');
    return (rows as List)
        .map((r) =>
            Contact.fromMap(r['id'].toString(), r as Map<String, dynamic>))
        .toList();
  }

  Future<int> contactsCount() async {
    final rows = await _db.from('contacts').select('id');
    return (rows as List).length;
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
