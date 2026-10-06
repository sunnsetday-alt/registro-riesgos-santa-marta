import 'package:flutter/material.dart';

/// Traduce la clave de ícono almacenada en `categories.icon` a un ícono de
/// Material. Agregar nuevas claves aquí permite nuevas categorías sin
/// migraciones.
class CategoryIcons {
  CategoryIcons._();

  static const Map<String, IconData> map = {
    'road': Icons.add_road_rounded,
    'traffic': Icons.traffic_rounded,
    'water': Icons.water_drop_rounded,
    'plumbing': Icons.plumbing_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'delete': Icons.delete_rounded,
    'shield': Icons.shield_rounded,
    'eco': Icons.eco_rounded,
    'apartment': Icons.apartment_rounded,
    'park': Icons.park_rounded,
    'signpost': Icons.signpost_rounded,
    'flood': Icons.flood_rounded,
    'forest': Icons.forest_rounded,
    'more': Icons.more_horiz_rounded,
    'report': Icons.report_rounded,
  };

  static IconData of(String? key) => map[key] ?? Icons.report_rounded;
}
