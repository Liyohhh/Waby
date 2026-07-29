import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/car.dart';

class CarService {
  final SupabaseClient _db = Supabase.instance.client;

  /// Live stream of cars in the caller's family (RLS-scoped).
  Stream<List<Car>> carsStream() {
    return _db
        .from('cars')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) => rows.map(Car.fromMap).toList());
  }

  Future<List<Car>> myCars() async {
    final rows = await _db.from('cars').select().order('created_at');
    return (rows as List)
        .map((r) => Car.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  // family_id is stamped by the database trigger — do not pass it here.
  Future<void> addCar({
    required String name,
    required String color,
    String? plateNumber,
  }) async {
    await _db.from('cars').insert({
      'name': name,
      'color': color,
      'plate_number': plateNumber,
    });
  }

  Future<void> updateCar({
    required String id,
    required String name,
    required String color,
    String? plateNumber,
  }) async {
    await _db.from('cars').update({
      'name': name,
      'color': color,
      'plate_number': plateNumber,
    }).eq('id', id);
  }

  Future<void> deleteCar(String id) async {
    await _db.from('cars').delete().eq('id', id);
  }
}
