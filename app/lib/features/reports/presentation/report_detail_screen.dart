import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/severity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/report.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/report_widgets.dart';
import '../../map/widgets/map_layers.dart';
import '../application/reports_providers.dart';

/// Detalle de un reporte propio: toda la información + historial de estados
/// y observaciones públicas del personal.
class ReportDetailScreen extends ConsumerWidget {
  const ReportDetailScreen({super.key, required this.reportId});
  final String reportId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportDetailProvider(reportId));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del reporte')),
      body: AsyncView<Report?>(
        value: report,
        onRetry: () => ref.invalidate(reportDetailProvider(reportId)),
        data: (r) => r == null
            ? const EmptyState(icon: Icons.search_off_rounded, title: 'Reporte no encontrado')
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(reportDetailProvider(reportId));
                  ref.invalidate(reportHistoryProvider(reportId));
                  ref.invalidate(reportObservationsProvider(reportId));
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                  children: [
                    ReportInfoSection(report: r),
                    const SectionHeader('Historial y actualizaciones'),
                    AppCard(child: ReportTimeline(reportId: reportId)),
                  ],
                ),
              ),
      ),
    );
  }
}

/// Bloque reutilizable con foto, datos y mini-mapa (también lo usa el panel).
class ReportInfoSection extends StatelessWidget {
  const ReportInfoSection({super.key, required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final pos = LatLng(r.latitude, r.longitude);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (r.photoUrl != null) NetworkPhoto(r.photoUrl, height: 230, radius: AppTheme.radius),
      const SizedBox(height: 14),
      Row(children: [
        Text(r.code, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ocean)),
        const SizedBox(width: 8),
        if (r.isTestData) const TestDataBadge(),
        const Spacer(),
        StatusChip(r.status),
      ]),
      const SizedBox(height: 8),
      Text(r.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        CategoryLabel(name: r.categoryName, colorHex: r.categoryColor, icon: r.categoryIcon),
        SeverityBadge(r.severity),
      ]),
      const SizedBox(height: 14),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(r.description),
          const Divider(height: 24),
          _info(Icons.priority_high_rounded, 'Importancia: ${Severity.of(r.severity).label}'),
          _info(Icons.event_outlined, 'Reportado: ${Formatters.dateTime(r.createdAt)}'),
          if (r.resolvedAt != null) _info(Icons.task_alt_rounded, 'Resuelto: ${Formatters.dateTime(r.resolvedAt!)}'),
          if (r.address != null) _info(Icons.place_outlined, r.address!),
          if (r.sectorName != null) _info(Icons.map_outlined, 'Sector: ${r.sectorName}'),
          _info(Icons.gps_fixed_rounded, Formatters.coords(r.latitude, r.longitude)),
        ]),
      ),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: SizedBox(
          height: 180,
          child: FlutterMap(
            options: MapOptions(initialCenter: pos, initialZoom: 16),
            children: [
              baseTileLayer(),
              MarkerLayer(markers: [
                Marker(
                  point: pos,
                  width: 46,
                  height: 46,
                  child: Icon(Icons.location_on_rounded, size: 46, color: Severity.of(r.severity).color),
                ),
              ]),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _info(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}

/// Historial + observaciones de un reporte.
class ReportTimeline extends ConsumerWidget {
  const ReportTimeline({super.key, required this.reportId, this.showAuthors = false});
  final String reportId;
  final bool showAuthors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(reportHistoryProvider(reportId));
    final observations = ref.watch(reportObservationsProvider(reportId));
    if (history.isLoading || observations.isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
    }
    if (history.hasError || observations.hasError) {
      return const Text('No se pudo cargar el historial.');
    }
    return StatusTimeline(
      history: history.value ?? const [],
      observations: observations.value ?? const [],
      showAuthors: showAuthors,
    );
  }
}
