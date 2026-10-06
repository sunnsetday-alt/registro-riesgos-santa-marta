import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/report_status.dart';
import '../../../core/constants/severity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/geo.dart';
import '../../../data/models/report_filter.dart';
import '../../../shared/widgets/common.dart';
import '../../map/widgets/map_layers.dart';
import '../application/admin_providers.dart';
import '../data/admin_repository.dart';
import 'widgets/charts.dart';

/// Dashboard administrativo: indicadores, gráficos y zonas críticas.
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final range = ref.watch(dashboardRangeProvider);

    void openList({Set<String> statuses = const {}, Set<int> severities = const {}, bool duplicates = false}) {
      ref.read(adminReportFilterProvider.notifier).state = ReportFilter(
          statuses: statuses, severities: severities, onlyPossibleDuplicates: duplicates, orderBy: 'priority_score');
      context.go('/admin/reports');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        leading: IconButton(
          tooltip: 'Volver a la app ciudadana',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/profile'),
        ),
        actions: [
          IconButton(
            tooltip: 'Recalcular prioridades',
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () async {
              try {
                final n = await ref.read(adminRepositoryProvider).recalculatePriorities();
                ref.invalidate(dashboardStatsProvider);
                if (context.mounted) showSnack(context, 'Prioridad recalculada en $n reportes abiertos');
              } catch (e) {
                if (context.mounted) showSnack(context, AppError.message(e), error: true);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardStatsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final opt in const [(7, '7 días'), (30, '30 días'), (90, '90 días'), (null, 'Todo')])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(opt.$2),
                      selected: range == opt.$1,
                      onSelected: (_) => ref.read(dashboardRangeProvider.notifier).state = opt.$1,
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            AsyncView<Map<String, dynamic>>(
              value: stats,
              onRetry: () => ref.invalidate(dashboardStatsProvider),
              data: (s) => _DashboardBody(stats: s, openList: openList),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats, required this.openList});
  final Map<String, dynamic> stats;
  final void Function({Set<String> statuses, Set<int> severities, bool duplicates}) openList;

  int _n(String key) => (stats[key] as num?)?.toInt() ?? 0;

  List<Map<String, dynamic>> _list(String key) =>
      ((stats[key] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  int _status(String code) {
    final s = _list('by_status').where((e) => e['code'] == code);
    return s.isEmpty ? 0 : (s.first['count'] as num).toInt();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) => _build(context, c.maxWidth));

  Widget _build(BuildContext context, double maxWidth) {
    final wide = maxWidth > 700;
    final kpis = <Widget>[
      KpiCard(label: 'Total de reportes', value: _n('total'), icon: Icons.assignment_rounded, color: AppColors.ocean,
          onTap: () => openList()),
      KpiCard(label: 'Recibidos', value: _status('recibido'), icon: Icons.inbox_rounded,
          color: ReportStatus.of('recibido').color, onTap: () => openList(statuses: {'recibido'})),
      KpiCard(label: 'En revisión', value: _status('en_revision'), icon: Icons.manage_search_rounded,
          color: ReportStatus.of('en_revision').color, onTap: () => openList(statuses: {'en_revision'})),
      KpiCard(label: 'Críticos abiertos', value: _n('critical_open'), icon: Icons.crisis_alert_rounded,
          color: AppColors.danger, onTap: () => openList(severities: {5})),
      KpiCard(label: 'En proceso', value: _status('en_proceso'), icon: Icons.engineering_rounded,
          color: ReportStatus.of('en_proceso').color, onTap: () => openList(statuses: {'en_proceso'})),
      KpiCard(label: 'Atendidos', value: _status('atendido'), icon: Icons.task_alt_rounded,
          color: ReportStatus.of('atendido').color, onTap: () => openList(statuses: {'atendido'})),
      KpiCard(label: 'Cerrados', value: _status('cerrado'), icon: Icons.lock_rounded,
          color: ReportStatus.of('cerrado').color, onTap: () => openList(statuses: {'cerrado'})),
      KpiCard(label: 'Posibles duplicados', value: _n('possible_duplicates'), icon: Icons.copy_all_rounded,
          color: const Color(0xFF7C3AED), onTap: () => openList(duplicates: true)),
    ];

    final byCategory = [
      for (final e in _list('by_category'))
        (label: e['name'] as String, value: (e['count'] as num).toInt(), color: AppColors.fromHex(e['color'] as String?)),
    ];
    final bySector = [
      for (final e in _list('by_sector'))
        (label: e['name'] as String, value: (e['count'] as num).toInt(), color: AppColors.turquoise),
    ];
    final byStatus = [
      for (final e in _list('by_status'))
        (label: e['name'] as String, value: (e['count'] as num).toInt(), color: AppColors.fromHex(e['color'] as String?)),
    ];
    final bySeverity = _list('by_severity');
    final byDate = [
      for (final e in _list('by_date')) (date: DateTime.parse(e['date'] as String), count: (e['count'] as num).toInt()),
    ];
    final byPriority = _list('by_priority');
    final hotspots = _list('hotspots');

    final charts = <Widget>[
      ChartCard(
        title: 'Reportes por fecha',
        subtitle: 'Reportes creados por día',
        child: DailyLineChart(points: byDate),
      ),
      ChartCard(
        title: 'Reportes por categoría',
        height: 260,
        child: HorizontalBars(items: byCategory, maxItems: 10),
      ),
      ChartCard(
        title: 'Reportes por nivel de importancia',
        child: SeverityBarChart(
          counts: [for (final e in bySeverity) (e['count'] as num).toInt()],
          colors: [for (final s in Severity.all) s.color],
          labels: [for (final s in Severity.all) '${s.level}\n${s.label}'],
        ),
      ),
      ChartCard(title: 'Reportes por estado', height: 200, child: DonutChart(items: byStatus)),
      ChartCard(
        title: 'Reportes por sector',
        subtitle: 'Zonas con mayor concentración de problemáticas',
        height: 260,
        child: HorizontalBars(items: bySector, maxItems: 10),
      ),
      ChartCard(
        title: 'Prioridad de reportes abiertos',
        height: 140,
        child: HorizontalBars(items: [
          for (final e in byPriority)
            (
              label: PriorityLevel.label(e['level'] as String),
              value: (e['count'] as num).toInt(),
              color: PriorityLevel.color(e['level'] as String),
            ),
        ]),
      ),
      _HotspotsCard(hotspots: hotspots),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GridView.count(
        crossAxisCount: wide ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: wide ? 2.4 : 1.9,
        children: kpis,
      ),
      const SizedBox(height: 14),
      if (wide)
        Wrap(spacing: 14, runSpacing: 14, children: [
          for (final c in charts)
            SizedBox(width: (maxWidth - 14) / 2, child: c),
        ])
      else
        for (final c in charts) Padding(padding: const EdgeInsets.only(bottom: 14), child: c),
    ]);
  }
}

/// Zonas críticas: celdas de ~110 m con 2+ reportes abiertos.
class _HotspotsCard extends StatelessWidget {
  const _HotspotsCard({required this.hotspots});
  final List<Map<String, dynamic>> hotspots;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Zonas críticas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const Text('Puntos con varios reportes abiertos a menos de ~110 m',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          child: SizedBox(
            height: 220,
            child: FlutterMap(
              options: MapOptions(initialCenter: Geo.santaMarta, initialZoom: 12),
              children: [
                baseTileLayer(),
                CircleLayer(circles: [
                  for (final h in hotspots)
                    CircleMarker(
                      point: LatLng((h['lat'] as num).toDouble(), (h['lng'] as num).toDouble()),
                      radius: 60.0 + 25 * (h['count'] as num).toDouble(),
                      useRadiusInMeter: true,
                      color: Severity.of(((h['avg_severity'] as num?) ?? 3).round()).color.withAlpha(110),
                      borderColor: Severity.of(((h['avg_severity'] as num?) ?? 3).round()).color,
                      borderStrokeWidth: 2,
                    ),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (hotspots.isEmpty)
          const Text('No hay concentraciones de reportes abiertos.',
              style: TextStyle(color: AppColors.textSecondary))
        else
          for (final h in hotspots.take(5))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.danger.withAlpha(30),
                child: Text('${h['count']}', style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w800)),
              ),
              title: Text((h['sector'] as String?) ?? 'Sin sector'),
              subtitle: Text('Importancia promedio: ${h['avg_severity']} · '
                  '${(h['lat'] as num).toStringAsFixed(4)}, ${(h['lng'] as num).toStringAsFixed(4)}'),
            ),
      ]),
    );
  }
}
