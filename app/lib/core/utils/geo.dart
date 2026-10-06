import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Utilidades geográficas para Santa Marta.
class Geo {
  Geo._();

  /// Centro aproximado de Santa Marta (Centro Histórico).
  static const santaMarta = LatLng(11.2408, -74.1990);

  /// Límites aceptados por la base de datos (Distrito de Santa Marta).
  static const minLat = 10.80, maxLat = 11.45, minLng = -74.40, maxLng = -73.50;

  static bool isInsideDistrict(double lat, double lng) =>
      lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;

  /// Distancia Haversine en metros (misma fórmula que la base de datos).
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(a)));
  }
}
