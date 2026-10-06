import 'package:flutter/material.dart';

import '../../core/constants/category_icons.dart';
import '../../core/constants/report_status.dart';
import '../../core/constants/severity.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/report.dart';
import '../../data/models/report_activity.dart';
import 'common.dart';

/// Chip de estado (Recibido, En revisión, ...).
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.dense = false});
  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = ReportStatus.of(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: s.color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(s.icon, size: dense ? 12 : 14, color: s.color),
        const SizedBox(width: 4),
        Text(s.name,
            style: TextStyle(color: s.color, fontWeight: FontWeight.w700, fontSize: dense ? 11 : 12)),
      ]),
    );
  }
}

/// Insignia de nivel de importancia (1–5).
class SeverityBadge extends StatelessWidget {
  const SeverityBadge(this.level, {super.key, this.showLabel = true});
  final int level;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final s = Severity.of(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$level', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
        if (showLabel) ...[
          const SizedBox(width: 4),
          Text(s.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11)),
        ],
      ]),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.level, required this.score});
  final String level;
  final double score;

  @override
  Widget build(BuildContext context) {
    final c = PriorityLevel.color(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('${PriorityLevel.label(level)} · ${score.toStringAsFixed(0)}',
          style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class CategoryLabel extends StatelessWidget {
  const CategoryLabel({super.key, required this.name, required this.colorHex, required this.icon});
  final String name;
  final String colorHex;
  final String icon;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromHex(colorHex);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: color.withAlpha(35), borderRadius: BorderRadius.circular(8)),
        child: Icon(CategoryIcons.of(icon), size: 14, color: color),
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(name,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ),
    ]);
  }
}

/// Tarjeta de reporte usada en "Mis reportes", inicio y panel.
class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, this.onTap, this.showPriority = false});
  final Report report;
  final VoidCallback? onTap;
  final bool showPriority;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NetworkPhoto(report.photoUrl, height: 84, width: 84),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(report.code,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.ocean)),
              const Spacer(),
              StatusChip(report.status, dense: true),
            ]),
            const SizedBox(height: 4),
            Text(report.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 6),
            CategoryLabel(name: report.categoryName, colorHex: report.categoryColor, icon: report.categoryIcon),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              SeverityBadge(report.severity),
              if (showPriority) PriorityBadge(level: report.priorityLevel, score: report.priorityScore),
              if (report.possibleDuplicate)
                const Chip(
                  label: Text('Posible duplicado', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              if (report.isTestData) const TestDataBadge(),
              Text(Formatters.relative(report.createdAt),
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Línea de tiempo con el historial de estados y observaciones.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.history, required this.observations, this.showAuthors = false});
  final List<StatusChange> history;
  final List<Observation> observations;
  final bool showAuthors;

  @override
  Widget build(BuildContext context) {
    final items = <({DateTime at, Widget child, Color color, IconData icon})>[
      for (final h in history)
        (
          at: h.createdAt,
          color: ReportStatus.of(h.toStatus).color,
          icon: ReportStatus.of(h.toStatus).icon,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              h.fromStatus == null
                  ? ReportStatus.of(h.toStatus).name
                  : '${ReportStatus.of(h.fromStatus!).name} → ${ReportStatus.of(h.toStatus).name}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (h.note != null && h.note!.isNotEmpty) Text(h.note!),
            if (showAuthors && h.changedByName != null)
              Text('Por: ${h.changedByName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      for (final o in observations)
        (
          at: o.createdAt,
          color: AppColors.turquoise,
          icon: o.isPublic ? Icons.chat_bubble_outline_rounded : Icons.lock_outline_rounded,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.isPublic ? 'Observación' : 'Nota interna',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(o.body),
            if (showAuthors && o.authorName != null)
              Text('Por: ${o.authorName}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
    ]..sort((a, b) => a.at.compareTo(b.at));

    if (items.isEmpty) {
      return const Text('Sin actualizaciones todavía.', style: TextStyle(color: AppColors.textSecondary));
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: items[i].color.withAlpha(35), shape: BoxShape.circle),
                  child: Icon(items[i].icon, size: 16, color: items[i].color),
                ),
                if (i < items.length - 1)
                  Expanded(child: Container(width: 2, color: AppColors.border)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16, top: 2),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    items[i].child,
                    const SizedBox(height: 2),
                    Text(Formatters.dateTime(items[i].at),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ]),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}
