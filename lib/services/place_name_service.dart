import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

import '../models/seat_status.dart';

/// Turns seat lat/lng into a readable place (suburb, city) when firmware
/// leaves `live.place_name` as "Unknown place".
///
/// Lookup order:
/// 1. Device geocoder (`geocoding` — Google on Android, no API key)
/// 2. OpenStreetMap Nominatim reverse API
/// 3. BigDataCloud reverse-geocode-client API
///
/// Does not PATCH `live` — the ESP32 would overwrite it on the next 1 Hz tick.
class PlaceNameService {
  PlaceNameService._();
  static final instance = PlaceNameService._();

  final ValueNotifier<String?> resolvedLabel = ValueNotifier<String?>(null);

  String? _cachedLabel;
  double? _cachedLat;
  double? _cachedLng;
  DateTime? _lastLookup;
  DateTime? _lastAttempt;
  bool _inFlight = false;

  static bool isPlaceholder(String? name) {
    if (name == null) return true;
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return true;
    return n == 'unknown place' ||
        n == 'unknown' ||
        n == 'gps: no fix' ||
        n.startsWith('gps:');
  }

  /// Home label. Null = hide the location row.
  String? displayName(SeatStatus status) {
    if (!isPlaceholder(status.placeName)) return status.placeName!.trim();
    if (_cachedLabel != null && _isNear(status, _cachedLat, _cachedLng)) {
      return _cachedLabel;
    }
    if (status.hasGpsFix) return resolvedLabel.value ?? 'Locating…';
    return null;
  }

  /// Telegram / escalate: never send "Locating…" or "Unknown place".
  String? bestName({String? livePlace}) {
    if (!isPlaceholder(livePlace)) return livePlace!.trim();
    final cached = _cachedLabel ?? resolvedLabel.value;
    if (cached == null || cached.isEmpty || cached == 'Locating…') return null;
    if (isPlaceholder(cached)) return null;
    return cached;
  }

  Future<void> onLive(SeatStatus status) async {
    if (!isPlaceholder(status.placeName)) {
      final name = status.placeName!.trim();
      _cachedLabel = name;
      _cachedLat = status.latitude;
      _cachedLng = status.longitude;
      if (resolvedLabel.value != name) resolvedLabel.value = name;
      return;
    }
    if (!status.hasGpsFix) return;
    if (_inFlight) return;
    final now = DateTime.now();
    if (_cachedLabel != null &&
        _isNear(status, _cachedLat, _cachedLng) &&
        _lastLookup != null &&
        now.difference(_lastLookup!) < const Duration(minutes: 2)) {
      return;
    }
    if (_lastAttempt != null &&
        now.difference(_lastAttempt!) < const Duration(seconds: 15)) {
      return;
    }

    _inFlight = true;
    _lastAttempt = now;
    try {
      final name = await _lookup(status.latitude!, status.longitude!);
      if (name == null || name.isEmpty || isPlaceholder(name)) return;
      _cachedLabel = name;
      _cachedLat = status.latitude;
      _cachedLng = status.longitude;
      _lastLookup = DateTime.now();
      resolvedLabel.value = name;
    } finally {
      _inFlight = false;
    }
  }

  bool _isNear(SeatStatus status, double? lat, double? lng) {
    if (!status.hasGpsFix || lat == null || lng == null) return false;
    final dLat = status.latitude! - lat;
    final dLng = status.longitude! - lng;
    return (dLat * dLat + dLng * dLng) < 0.000001;
  }

  Future<String?> _lookup(double lat, double lng) async {
    return await _deviceGeocoder(lat, lng) ??
        await _nominatim(lat, lng) ??
        await _bigDataCloud(lat, lng);
  }

  Future<String?> _deviceGeocoder(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isEmpty) return null;
      return _compose(
        marks.first.subLocality,
        marks.first.locality,
        marks.first.subAdministrativeArea,
        marks.first.administrativeArea,
        marks.first.country,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _nominatim(double lat, double lng) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'jsonv2',
      'addressdetails': '1',
    });
    final json = await _getJson(
      uri,
      headers: const {'User-Agent': 'Waby/1.0 (baby seat monitor)'},
    );
    if (json == null) return null;
    final address = json['address'];
    if (address is Map) {
      return _compose(
        address['suburb']?.toString(),
        address['neighbourhood']?.toString() ??
            address['village']?.toString() ??
            address['town']?.toString() ??
            address['city']?.toString(),
        address['county']?.toString(),
        address['state']?.toString(),
        address['country']?.toString(),
      );
    }
    final display = json['display_name']?.toString().trim();
    if (display != null && display.isNotEmpty) {
      return display.split(',').take(2).join(',').trim();
    }
    return null;
  }

  Future<String?> _bigDataCloud(double lat, double lng) async {
    final uri = Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
      'latitude': lat.toString(),
      'longitude': lng.toString(),
      'localityLanguage': 'en',
    });
    final json = await _getJson(uri);
    if (json == null) return null;
    return _compose(
      json['locality']?.toString(),
      json['city']?.toString(),
      json['principalSubdivision']?.toString(),
      json['principalSubdivision']?.toString(),
      json['countryName']?.toString(),
    );
  }

  String? _compose(
    String? a,
    String? b,
    String? c,
    String? d,
    String? e,
  ) {
    final parts = <String>[];
    for (final raw in [a, b, c, d, e]) {
      final value = raw?.trim();
      if (value == null || value.isEmpty || isPlaceholder(value)) continue;
      if (parts.any((p) => p.toLowerCase() == value.toLowerCase())) continue;
      parts.add(value);
      if (parts.length == 2) break;
    }
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  Future<Map<String, dynamic>?> _getJson(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    try {
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}
