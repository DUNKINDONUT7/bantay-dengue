// lib/services/location_helper.dart
//
// Shared "use my current location" plumbing. Was copy-pasted with the same
// permission-check → service-check → fetch sequence across report_form.dart,
// edit_report_screen.dart, and request_waste_screen.dart — consolidated here
// so a fix to the sequence only needs to happen once. Callers keep their own
// context-specific message wording by switching on [LocationFailure.reason].
import 'package:geolocator/geolocator.dart';

enum LocationFailureReason { permissionDenied, serviceDisabled, other }

class LocationFailure implements Exception {
  final LocationFailureReason reason;
  const LocationFailure(this.reason);
}

class LocationResult {
  final double latitude;
  final double longitude;
  const LocationResult(this.latitude, this.longitude);
}

class LocationHelper {
  /// Resolves the device's current position, or throws [LocationFailure]
  /// with a reason the caller can turn into its own tailored message.
  static Future<LocationResult> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 12),
  }) async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationFailure(LocationFailureReason.permissionDenied);
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(LocationFailureReason.serviceDisabled);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
      return LocationResult(position.latitude, position.longitude);
    } catch (_) {
      throw const LocationFailure(LocationFailureReason.other);
    }
  }
}
