import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// Resultado de solicitar la ubicación.
class LocationResult {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String? error;
  const LocationResult({this.latitude, this.longitude, this.accuracy, this.error});
  bool get ok => latitude != null && longitude != null;
}

/// Acceso al GPS con manejo de permisos en español.
class LocationService {
  Future<LocationResult> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return const LocationResult(error: 'Activa el GPS del dispositivo para ubicar el reporte.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return const LocationResult(error: 'Permiso de ubicación denegado. Puedes ubicar el punto manualmente en el mapa.');
    }
    if (perm == LocationPermission.deniedForever) {
      return const LocationResult(
          error: 'El permiso de ubicación está bloqueado. Actívalo en Ajustes o ubica el punto manualmente.');
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationResult(latitude: pos.latitude, longitude: pos.longitude, accuracy: pos.accuracy);
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationResult(latitude: last.latitude, longitude: last.longitude, accuracy: last.accuracy);
      }
      return const LocationResult(error: 'No se pudo obtener la ubicación. Ubica el punto manualmente.');
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
