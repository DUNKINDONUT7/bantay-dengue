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
}
