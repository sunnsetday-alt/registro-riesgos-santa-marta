import 'package:flutter/material.dart';

/// Escala de importancia 1–5 con su explicación visual.
class Severity {
  final int level;
  final String label;
  final String explanation;
  final Color color;
  final IconData icon;

  const Severity(this.level, this.label, this.explanation, this.color, this.icon);

  static const all = <Severity>[
    Severity(1, 'Muy baja', 'Molestia menor. No representa riesgo para las personas.',
        Color(0xFF22C55E), Icons.sentiment_satisfied_alt_rounded),
    Severity(2, 'Baja', 'Afecta la calidad de vida, pero puede esperar.',
        Color(0xFF84CC16), Icons.info_outline_rounded),
    Severity(3, 'Media', 'Afecta a varias personas o puede empeorar si no se atiende.',
        Color(0xFFEAB308), Icons.report_gmailerrorred_rounded),
    Severity(4, 'Alta', 'Riesgo de accidentes, daños materiales o afectación grave del servicio.',
        Color(0xFFF97316), Icons.warning_amber_rounded),
    Severity(5, 'Crítica', 'Peligro inmediato para la vida o la integridad. Requiere atención urgente.',
        Color(0xFFDC2626), Icons.crisis_alert_rounded),
  ];

  static Severity of(int level) => all[(level.clamp(1, 5)) - 1];
}

/// Niveles del índice de prioridad calculado por el servidor.
class PriorityLevel {
  static const labels = {
    'baja': 'Baja prioridad',
    'media': 'Prioridad media',
    'alta': 'Alta prioridad',
    'critica': 'Prioridad crítica',
  };

  static const colors = {
    'baja': Color(0xFF64748B),
    'media': Color(0xFFEAB308),
    'alta': Color(0xFFF97316),
    'critica': Color(0xFFDC2626),
  };

  static String label(String code) => labels[code] ?? code;
  static Color color(String code) => colors[code] ?? const Color(0xFF64748B);
}
