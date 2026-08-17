class Child {
  final String id;
  final String deviceId;
  final String name;
  final DateTime? dob;
  final String? gender;
  final double? weightKg;
  final double? heightCm;
  final String? photoPath;
  final bool hardwareLinked;

  const Child({
    required this.id,
    required this.deviceId,
    required this.name,
    this.dob,
    this.gender,
    this.weightKg,
    this.heightCm,
    this.photoPath,
    this.hardwareLinked = false,
  });

  factory Child.fromMap(Map<String, dynamic> m) => Child(
        id: m['id'].toString(),
        deviceId: m['device_id'].toString(),
        name: m['name'] as String? ?? '',
        dob: m['dob'] != null ? DateTime.tryParse(m['dob'].toString()) : null,
        gender: m['gender'] as String?,
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        heightCm: (m['height_cm'] as num?)?.toDouble(),
        photoPath: m['photo_path'] as String?,
        hardwareLinked: _asBool(m['hardware_linked']),
      );

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      if (v == 'true' || v == 't' || v == '1') return true;
    }
    return false;
  }
}
