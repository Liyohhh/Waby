import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceService {
  final SupabaseClient _db = Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  /// Creates a device and its child together. family_id is stamped by a DB trigger.
  /// The first child in the family is hardware-linked to `live` id=1; later
  /// children are simulated.
  Future<void> addDeviceWithChild({
    required String deviceName,
    required String childName,
    DateTime? dob,
    String? gender,
    double? weightKg,
    double? heightCm,
    String? childId,
    String? photoPath,
    String? deviceId,
    String? devicePhotoPath,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in');

    final device = await _db
        .from('devices')
        .insert({
          'id': ?deviceId,
          'user_id': uid,
          'name': deviceName,
          'photo_path': ?devicePhotoPath,
        })
        .select('id')
        .single();

    var hardwareLinked = true;
    try {
      final existing = await _db
          .from('children')
          .select('id')
          .eq('hardware_linked', true)
          .limit(1);
      hardwareLinked = existing.isEmpty;
    } catch (_) {
      hardwareLinked = true;
    }

    final childRow = <String, dynamic>{
      'id': ?childId,
      'device_id': device['id'],
      'user_id': uid,
      'name': childName,
      if (dob != null) 'dob': dob.toIso8601String().split('T').first,
      'gender': ?gender,
      'weight_kg': ?weightKg,
      'height_cm': ?heightCm,
      'photo_path': ?photoPath,
      'hardware_linked': hardwareLinked,
    };

    try {
      await _db.from('children').insert(childRow);
    } on PostgrestException catch (e) {
      if (hardwareLinked && e.code == '23505') {
        childRow['hardware_linked'] = false;
        await _db.from('children').insert(childRow);
      } else {
        rethrow;
      }
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    await _db.from('devices').delete().eq('id', deviceId);
  }
}
