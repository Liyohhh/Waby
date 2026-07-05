class Child {
  final String id;
  final String deviceId;
  final String name;
  final DateTime? dob;
  final double? weightKg;
  final double? heightCm;

  const Child({
    required this.id,
    required this.deviceId,
    required this.name,
    this.dob,
    this.weightKg,
    this.heightCm,
  });

  factory Child.fromMap(Map<String, dynamic> m) => Child(
        id: m['id'].toString(),
        deviceId: m['device_id'].toString(),
        name: m['name'] as String? ?? '',
        dob: m['dob'] != null ? DateTime.tryParse(m['dob'].toString()) : null,
        weightKg: (m['weight_kg'] as num?)?.toDouble(),
        heightCm: (m['height_cm'] as num?)?.toDouble(),
      );
}
