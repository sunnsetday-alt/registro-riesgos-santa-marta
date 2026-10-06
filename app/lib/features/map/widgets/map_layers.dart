import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../core/config/env.dart';
import '../../../core/constants/category_icons.dart';
import '../../../core/constants/severity.dart';

/// Capa base del mapa. El proveedor se configura por variables de entorno
/// (OpenStreetMap por defecto, Mapbox u otro con MAP_TILE_URL).
TileLayer baseTileLayer() => TileLayer(
      urlTemplate: Env.mapTileUrl,
      additionalOptions: {
        if (Env.mapAccessToken.isNotEmpty) 'accessToken': Env.mapAccessToken,
      },
      userAgentPackageName: Env.appPackage,
      maxZoom: 19,
    );

/// Atribución obligatoria del proveedor de mapas.
Widget mapAttribution() => Positioned(
      left: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: Colors.white.withAlpha(210), borderRadius: BorderRadius.circular(6)),
        child: Text(Env.mapAttribution, style: const TextStyle(fontSize: 10)),
      ),
    );

/// Marcador de un reporte: color según el nivel de importancia e ícono
/// según la categoría. Los críticos son más grandes.
class SeverityMarker extends StatelessWidget {
  const SeverityMarker({super.key, required this.severity, required this.icon, this.selected = false});
  final int severity;
  final String icon;
  final bool selected;

  static double sizeFor(int severity) => severity >= 5 ? 46 : (severity == 4 ? 40 : 34);

  @override
  Widget build(BuildContext context) {
    final s = Severity.of(severity);
    final size = sizeFor(severity) + (selected ? 8 : 0);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: s.color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: selected ? 4 : 3),
        boxShadow: [BoxShadow(color: s.color.withAlpha(110), blurRadius: selected ? 14 : 8)],
      ),
      child: Icon(CategoryIcons.of(icon), color: Colors.white, size: size * 0.48),
    );
  }
}

/// Leyenda de colores por nivel de importancia.
class SeverityLegend extends StatelessWidget {
  const SeverityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in Severity.all.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('${s.level} ${s.label}', style: const TextStyle(fontSize: 11)),
              ]),
            ),
        ],
      ),
    );
  }
}
