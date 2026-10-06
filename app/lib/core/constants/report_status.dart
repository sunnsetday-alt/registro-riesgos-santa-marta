import 'package:flutter/material.dart';

/// Estados del ciclo de vida de un reporte (códigos iguales a la tabla
/// public.report_statuses).
class ReportStatus {
  final String code;
  final String name;
  final Color color;
  final IconData icon;

  const ReportStatus(this.code, this.name, this.color, this.icon);

  static const recibido = 'recibido';
  static const enRevision = 'en_revision';
  static const validado = 'validado';
  static const enProceso = 'en_proceso';
  static const atendido = 'atendido';
  static const cerrado = 'cerrado';
  static const rechazado = 'rechazado';

  static const all = <ReportStatus>[
    ReportStatus(recibido, 'Recibido', Color(0xFF0EA5E9), Icons.inbox_rounded),
    ReportStatus(enRevision, 'En revisión', Color(0xFF8B5CF6), Icons.manage_search_rounded),
    ReportStatus(validado, 'Validado', Color(0xFF14B8A6), Icons.verified_rounded),
    ReportStatus(enProceso, 'En proceso', Color(0xFFF59E0B), Icons.engineering_rounded),
    ReportStatus(atendido, 'Atendido', Color(0xFF22C55E), Icons.task_alt_rounded),
    ReportStatus(cerrado, 'Cerrado', Color(0xFF475569), Icons.lock_rounded),
    ReportStatus(rechazado, 'Rechazado', Color(0xFFEF4444), Icons.block_rounded),
  ];

  static ReportStatus of(String code) => all.firstWhere(
        (s) => s.code == code,
        orElse: () => ReportStatus(code, code, const Color(0xFF64748B), Icons.help_outline),
      );

  static bool isOpen(String code) =>
      code != atendido && code != cerrado && code != rechazado;
}
