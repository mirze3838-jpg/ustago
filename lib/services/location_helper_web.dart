// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'location_helper.dart';

// Brauzerdə "GPS xidməti" anlayışı yoxdur; geolocation API mövcuddursa aktiv sayırıq.
Future<String> _queryPermission() async {
  try {
    final perms = html.window.navigator.permissions;
    if (perms == null) return 'denied';
    final status = await perms.query({'name': 'geolocation'});
    final state = status.state ?? 'prompt';
    if (state == 'granted') return 'granted';
    if (state == 'denied') return 'permanentlyDenied';
    return 'denied';
  } catch (_) {
    return 'denied';
  }
}

Future<LocationStatusResult> checkLocationStatus() async {
  final supported = html.window.navigator.geolocation != null;
  final perm = await _queryPermission();
  return LocationStatusResult(gpsEnabled: supported, permission: perm);
}

Future<String> requestLocationPermission() async {
  final current = await _queryPermission();
  if (current == 'granted' || current == 'permanentlyDenied') return current;
  try {
    // Brauzerin rəsmi icazə pəncərəsi yalnız getCurrentPosition çağırışı ilə açılır
    await html.window.navigator.geolocation
        .getCurrentPosition(enableHighAccuracy: true, timeout: const Duration(seconds: 20));
    return 'granted';
  } on html.PositionError catch (e) {
    if (e.code == 1) return 'permanentlyDenied';
    // İcazə verildi, amma mövqe alınmadı
    return await _queryPermission() == 'granted' ? 'granted' : 'denied';
  } catch (_) {
    return await _queryPermission();
  }
}

Future<bool> openLocationSettings() async => false;

Future<bool> openAppSettings() async => false;

Future<LocationPosition> getCurrentPosition() async {
  try {
    final pos = await html.window.navigator.geolocation
        .getCurrentPosition(enableHighAccuracy: true, timeout: const Duration(seconds: 20));
    final c = pos.coords;
    final lat = c?.latitude?.toDouble();
    final lng = c?.longitude?.toDouble();
    if (lat == null || lng == null) {
      throw const LocationException('UNAVAILABLE', 'Konum məlumatı alınmadı');
    }
    return LocationPosition(lat: lat, lng: lng, accuracy: c?.accuracy?.toDouble());
  } on html.PositionError catch (e) {
    if (e.code == 1) throw const LocationException('NO_PERMISSION', 'Konum icazəsi verilməyib');
    if (e.code == 3) throw const LocationException('TIMEOUT', 'Konum vaxtında alınmadı');
    throw const LocationException('UNAVAILABLE', 'Konum hazırda əlçatan deyil');
  } on LocationException {
    rethrow;
  } catch (e) {
    throw LocationException('UNKNOWN', 'Konum alınarkən xəta: $e');
  }
}
