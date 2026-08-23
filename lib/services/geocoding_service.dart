// lib/services/geocoding_service.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Turns GPS coordinates into a human-readable address, and vice versa is
/// not needed here — this app only ever reverse-geocodes a captured pin so
/// residents don't have to retype an address they just located on the map.
///
/// Uses OpenStreetMap's free Nominatim endpoint (no API key, matches the
/// OSM tiles already used in hotspot_map_screen.dart) rather than adding a
/// native geocoding plugin, since Flutter Web has no native geocoding
/// backend to call into — a plain HTTP request works identically on every
/// platform this app ships to.
class GeocodingService {
  GeocodingService._();

  static final GeocodingService instance = GeocodingService._();

  /// Best-effort: returns null on any failure so a slow or unreachable
  /// geocoder never blocks the surrounding form.
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$latitude',
        'lon': '$longitude',
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': 'com.bantaydengue.app'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final address = body['address'] as Map<String, dynamic>?;
      if (address != null) {
        final parts = [
              address['road'],
              address['suburb'] ??
                  address['village'] ??
                  address['neighbourhood'],
              address['city'] ?? address['town'] ?? address['municipality'],
            ]
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) return parts.join(', ');
      }
      return body['display_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Just the barangay-equivalent component (Nominatim has no "barangay"
  /// field for the Philippines — suburb/village/neighbourhood is the
  /// closest match in OSM's addressing scheme) — for auto-filling a
  /// resident's profile `barangay` field from their current location,
  /// separate from [reverseGeocode]'s full "road, suburb, city" display
  /// string used elsewhere for a report's location text.
  Future<String?> reverseGeocodeBarangay({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$latitude',
        'lon': '$longitude',
        'format': 'jsonv2',
        'zoom': '18',
        'addressdetails': '1',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': 'com.bantaydengue.app'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final address = body['address'] as Map<String, dynamic>?;
      final barangay =
          address?['suburb'] ?? address?['village'] ?? address?['neighbourhood'];
      return barangay is String && barangay.trim().isNotEmpty
          ? barangay.trim()
          : null;
    } catch (_) {
      return null;
    }
  }

  /// Forward geocoding: turns a typed address/landmark query into ranked
  /// candidate points, so a resident can search instead of hunting for a pin
  /// by hand. Biased to the Philippines since every report in this system is
  /// local. Best-effort: an empty list on any failure, never throws — the
  /// caller (the map picker) just shows "no matches" rather than crashing.
  Future<List<GeocodeSuggestion>> searchAddress(
    String query, {
    int limit = 5,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': trimmed,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '$limit',
        'countrycodes': 'ph',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': 'com.bantaydengue.app'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return const [];

      final body = jsonDecode(response.body) as List<dynamic>;
      return body
          .whereType<Map<String, dynamic>>()
          .map((row) {
            final lat = double.tryParse('${row['lat']}');
            final lon = double.tryParse('${row['lon']}');
            final name = row['display_name'] as String?;
            if (lat == null || lon == null || name == null) return null;
            final address = row['address'] as Map<String, dynamic>?;
            final barangay =
                address?['suburb'] ??
                address?['village'] ??
                address?['neighbourhood'];
            return GeocodeSuggestion(
              displayName: name,
              latitude: lat,
              longitude: lon,
              barangay: barangay is String && barangay.trim().isNotEmpty
                  ? barangay.trim()
                  : null,
            );
          })
          .whereType<GeocodeSuggestion>()
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class GeocodeSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;
  // Nominatim's suburb/village/neighbourhood — the closest OSM equivalent
  // to a Philippine barangay. Was previously discarded even though the API
  // already returns it (addressdetails=1 is already set on this request).
  final String? barangay;

  const GeocodeSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.barangay,
  });
}
