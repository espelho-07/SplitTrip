import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'permission_service.dart';

/// Production-ready Location Service for GPS acquisition and reverse geocoding.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Fetches the user's current human-readable location (place/neighbourhood/city).
  /// Falls back gracefully to formatted coordinates if offline.
  Future<String?> getCurrentPlaceName() async {
    try {
      // 1. Check and request location permissions
      final hasPermission = await PermissionService.requestLocationPermission();
      if (!hasPermission) {
        debugPrint('[LocationService] Location permission denied.');
        return null;
      }

      // 2. Check if Location Services are enabled on device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location service is disabled.');
        return null;
      }

      // 3. Obtain current GPS position with reasonable timeout
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (e) {
        debugPrint('[LocationService] getCurrentPosition timed out, attempting last known position: $e');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        debugPrint('[LocationService] Could not obtain any position.');
        return null;
      }

      // 4. Reverse Geocode coordinates to readable place name
      final placeName = await _reverseGeocode(position.latitude, position.longitude);
      return placeName ?? '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
    } catch (e, stack) {
      debugPrint('[LocationService] Error obtaining location: $e\n$stack');
      return null;
    }
  }

  /// Reverse geocodes lat/long using OpenStreetMap Nominatim with failover.
  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'KithSplitTripApp/1.0 (https://kith.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final specificPlace = address['amenity'] ??
              address['shop'] ??
              address['tourism'] ??
              address['leisure'] ??
              address['building'] ??
              address['neighbourhood'] ??
              address['suburb'] ??
              address['road'];

          final cityOrTown = address['city'] ??
              address['town'] ??
              address['village'] ??
              address['state_district'] ??
              address['county'] ??
              address['state'];

          if (specificPlace != null && cityOrTown != null && specificPlace != cityOrTown) {
            return '$specificPlace, $cityOrTown';
          } else if (specificPlace != null) {
            return specificPlace.toString();
          } else if (cityOrTown != null) {
            return cityOrTown.toString();
          }
        }

        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) {
          final parts = displayName.split(',').map((s) => s.trim()).toList();
          if (parts.length >= 2) {
            return '${parts[0]}, ${parts[1]}';
          }
          return parts.first;
        }
      }
    } catch (e) {
      debugPrint('[LocationService] Reverse geocode network lookup failed: $e');
    }
    return null;
  }
}
