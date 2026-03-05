import 'package:geolocator/geolocator.dart';

typedef LatLng = ({double lat, double lng});

/// Best-effort GPS capture. Never throws — returns null if unavailable.
class LocationService {
  static Future<LatLng?> getCurrentPosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        return null;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );
      return (lat: pos.latitude, lng: pos.longitude);
    } catch (e, stack) {
      // ignore: avoid_print
      print('[LocationService] Failed to get position: $e\n$stack');
      return null;
    }
  }
}
