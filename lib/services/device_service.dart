import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {
  final SupabaseClient _db = Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  /// Creates a device and its child together. family_id is stamped by a DB trigger.
  Future<void> addDeviceWithChild({
    required String deviceName,
    required String childName,
    DateTime? dob,
    double? weightKg,
    double? heightCm,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final device = await _db
        .from('devices')
        .insert({'user_id': uid, 'name': deviceName})
        .select('id')
        .single();

    await _db.from('children').insert({
      'device_id': device['id'],
      'user_id': uid,
      'name': childName,
      if (dob != null) 'dob': dob.toIso8601String().split('T').first,
      if (weightKg != null) 'weight_kg': weightKg,
      if (heightCm != null) 'height_cm': heightCm,
    });
  }
}
