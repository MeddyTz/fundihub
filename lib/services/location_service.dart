import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Result returned by LocationService.detectLocation()
class LocationResult {
  final double latitude;
  final double longitude;
  final String detectedAddress;

  const LocationResult({
    required this.latitude,
    required this.longitude,
    required this.detectedAddress,
  });
}

enum LocationError {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

class LocationService {
  /// Request permission and fetch current position.
  /// Returns [LocationResult] on success, throws [LocationError] on failure.
  Future<LocationResult> detectLocation() async {
    // 1. Check if location service is enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationError.serviceDisabled;
    }

    // 2. Check / request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationError.permissionDenied;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationError.permissionDeniedForever;
    }

    // 3. Get position with timeout
    late Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
    } on TimeoutException {
      throw LocationError.timeout;
    } catch (_) {
      throw LocationError.unknown;
    }

    // 4. Reverse geocode to get a human-readable address
    String detectedAddress = '';
    try {
      final placemarks = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[
          if (p.street?.isNotEmpty == true) p.street!,
          if (p.subLocality?.isNotEmpty == true) p.subLocality!,
          if (p.locality?.isNotEmpty == true) p.locality!,
          if (p.administrativeArea?.isNotEmpty == true) p.administrativeArea!,
          if (p.country?.isNotEmpty == true) p.country!,
        ];
        detectedAddress = parts.join(', ');
      }
    } catch (_) {
      // Reverse geocode failed — fall back to raw coordinates
      detectedAddress =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
    }

    return LocationResult(
      latitude: pos.latitude,
      longitude: pos.longitude,
      detectedAddress: detectedAddress,
    );
  }

  /// Human-readable error message for display in UI
  static String errorMessage(LocationError error) {
    switch (error) {
      case LocationError.serviceDisabled:
        return 'Location services are disabled. Please enable GPS in your device settings.';
      case LocationError.permissionDenied:
        return 'Location permission was denied. Please grant permission to use auto-detect.';
      case LocationError.permissionDeniedForever:
        return 'Location permission is permanently denied. Please enable it in App Settings → Permissions → Location.';
      case LocationError.timeout:
        return 'GPS timed out. Please try again or enter your location manually.';
      case LocationError.unknown:
        return 'Could not detect location. Please enter your location manually.';
    }
  }
}
