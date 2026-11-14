import 'package:flutter/services.dart';
import 'location_helper.dart';

const MethodChannel _channel = MethodChannel('com.ustago.app/location');

Future<LocationStatusResult> checkLocationStatus() async {
  try {
    final res = await _channel.invokeMapMethod<String, dynamic>('checkLocationStatus');
    return LocationStatusResult(
      gpsEnabled: res?['gpsEnabled'] == true,
      permission: (res?['permission'] ?? 'denied').toString(),
    );
  } on MissingPluginException {
    // Native kanal yoxdursa (məs. köhnə build) - konumu əl ilə seçmək olar
    return const LocationStatusResult(gpsEnabled: false, permission: 'denied');
  } catch (_) {
    return const LocationStatusResult(gpsEnabled: false, permission: 'denied');
  }
}

Future<String> requestLocationPermission() async {
  try {
    final res = await _channel.invokeMethod<String>('requestLocationPermission');
    return res ?? 'denied';
  } catch (_) {
    return 'denied';
  }
}

Future<bool> openLocationSettings() async {
  try {
    return (await _channel.invokeMethod<bool>('openLocationSettings')) ?? false;
  } catch (_) {
    return false;
  }
}

Future<bool> openAppSettings() async {
  try {
    return (await _channel.invokeMethod<bool>('openAppSettings')) ?? false;
  } catch (_) {
    return false;
  }
}

Future<LocationPosition> getCurrentPosition() async {
  try {
    final res = await _channel
        .invokeMapMethod<String, dynamic>('getCurrentPosition')
        .timeout(const Duration(seconds: 20));
    final lat = (res?['lat'] as num?)?.toDouble();
    final lng = (res?['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      throw const LocationException('UNAVAILABLE', 'Konum məlumatı alınmadı');
    }
    return LocationPosition(lat: lat, lng: lng, accuracy: (res?['accuracy'] as num?)?.toDouble());
  } on PlatformException catch (e) {
    throw LocationException(e.code, e.message ?? 'Konum alınarkən xəta baş verdi');
  } on LocationException {
    rethrow;
  } catch (e) {
    throw LocationException('UNKNOWN', 'Konum alınarkən xəta: $e');
  }
}
