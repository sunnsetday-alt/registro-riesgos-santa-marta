import 'package:flutter/material.dart';

/// Paleta institucional inspirada en el Caribe samario.
class AppColors {
  AppColors._();

  static const deepSea = Color(0xFF03256C); // azul profundo (marca)
  static const ocean = Color(0xFF0077B6); // azul primario
  static const turquoise = Color(0xFF00B4D8); // turquesa caribe
  static const aqua = Color(0xFF90E0EF); // agua clara
  static const foam = Color(0xFFEAF7FB); // fondo suave
  static const sand = Color(0xFFF6EDDC); // arena
  static const coral = Color(0xFFFF6B5B); // acento (botón reportar)
  static const sun = Color(0xFFFFB703); // sol

  static const textPrimary = Color(0xFF0F1B2D);
  static const textSecondary = Color(0xFF5B6B7F);
  static const border = Color(0xFFDDE6EE);
  static const surface = Colors.white;
  static const background = Color(0xFFF5F9FC);

  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);

  static const reportGradient = LinearGradient(
    colors: [coral, Color(0xFFFF8A4C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [deepSea, ocean, turquoise],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Convierte '#RRGGBB' en [Color].
  static Color fromHex(String? hex, {Color fallback = ocean}) {
    if (hex == null) return fallback;
    final clean = hex.replaceAll('#', '');
    if (clean.length != 6) return fallback;
    final value = int.tryParse(clean, radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }
}
