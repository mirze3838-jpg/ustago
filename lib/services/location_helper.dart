// UstaGo — GPS / konum icazəsi üçün vahid servis.
// Android: MainActivity.kt daxilindəki "com.ustago.app/location" MethodChannel.
// Web: brauzerin navigator.geolocation API-si.
import 'location_helper_io.dart' if (dart.library.html) 'location_helper_web.dart' as impl;

/// İcazə statusları: 'granted' | 'denied' | 'permanentlyDenied'
class LocationStatusResult {
  final bool gpsEnabled;
  final String permission;

  const LocationStatusResult({required this.gpsEnabled, required this.permission});

  bool get isGranted => permission == 'granted';
  bool get isPermanentlyDenied => permission == 'permanentlyDenied';
}

class LocationPosition {
  final double lat;
  final double lng;
  final double? accuracy;

  const LocationPosition({required this.lat, required this.lng, this.accuracy});
}

class LocationException implements Exception {
  /// 'GPS_DISABLED' | 'NO_PERMISSION' | 'TIMEOUT' | 'UNAVAILABLE' | 'UNKNOWN'
  final String code;
  final String message;

  const LocationException(this.code, this.message);

  @override
  String toString() => 'LocationException($code): $message';
}

class LocationHelper {
  static Future<LocationStatusResult> checkLocationStatus() => impl.checkLocationStatus();

  static Future<String> requestLocationPermission() => impl.requestLocationPermission();

  static Future<bool> openLocationSettings() => impl.openLocationSettings();

  static Future<bool> openAppSettings() => impl.openAppSettings();

  /// Cari mövqeyi qaytarır; xəta halında [LocationException] atır.
  static Future<LocationPosition> getCurrentPosition() => impl.getCurrentPosition();
}
