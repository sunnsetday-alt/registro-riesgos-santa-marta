import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../../data/models/report.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/report_widgets.dart';
import '../auth/application/session_controller.dart';
import '../map/location_service.dart';
import '../notifications/notifications_repository.dart';
import '../offline/sync_service.dart';
import '../reports/application/reports_providers.dart';
import '../reports/data/reports_repository.dart';

/// Problemáticas cercanas a la ubicación del ciudadano.
final nearbyReportsProvider = FutureProvider.autoDispose<({List<Report> reports, double lat, double lng})?>((ref) async {
  final loc = await ref.watch(locationServiceProvider).current();
  if (!loc.ok || !Geo.isInsideDistrict(loc.latitude!, loc.longitude!)) return null;
  final list = await ref.watch(reportsRepositoryProvider).fetchNearby(loc.latitude!, loc.longitude!);
  return (reports: list, lat: loc.latitude!, lng: loc.longitude!);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(sessionProvider.select((s) => s.profile));
    final stats = ref.watch(publicStatsProvider);
    final recent = ref.watch(recentReportsProvider);
    final nearby = ref.watch(nearbyReportsProvider);
    final pending = ref.watch(syncServiceProvider.select((s) => s.pendingCount));
    final unread = ref.watch(notificationsProvider).valueOrNull?.where((n) => !n.isRead).length ?? 0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicStatsProvider);
          ref.invalidate(recentReportsProvider);
          ref.invalidate(nearbyReportsProvider);
          ref.invalidate(notificationsProvider);
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Hero(name: profile?.fullName, unread: unread)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            sliver: SliverList.list(children: [
              if (pending > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppCard(
                    color: AppColors.sand,
                    onTap: () => context.go('/my-reports'),
                    child: Row(children: [
                      const Icon(Icons.cloud_off_rounded, color: Color(0xFFB7791F)),
                      const SizedBox(width: 12),
                      Expanded(child: Text('$pending reporte(s) pendiente(s) de envío.')),
                      const Icon(Icons.chevron_right_rounded),
                    ]),
                  ),
                ),
              const SectionHeader('Estadísticas generales'),
              stats.when(
                data: (s) => _StatsRow(stats: s),
                loading: () => const SizedBox(height: 92, child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const Text('Estadísticas no disponibles sin conexión.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 14),
              _MapAccessCard(onTap: () => context.go('/map')),
              SectionHeader('Problemáticas cercanas', action: 'Ver mapa', onAction: () => context.go('/map')),
              nearby.when(
                data: (n) {
                  if (n == null) {
                    return const Text('Activa la ubicación para ver problemáticas cerca de ti.',
                        style: TextStyle(color: AppColors.textSecondary));
                  }
                  if (n.reports.isEmpty) {
                    return const Text('No hay reportes a menos de 1,5 km de tu ubicación.',
                        style: TextStyle(color: AppColors.textSecondary));
                  }
                  return SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: n.reports.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (_, i) {
                        final r = n.reports[i];
                        final d = Geo.distanceMeters(n.lat, n.lng, r.latitude, r.longitude);
                        return _NearbyCard(report: r, distance: d);
                      },
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('No se pudieron cargar las problemáticas cercanas.',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SectionHeader('Reportes recientes'),
              AsyncView<List<Report>>(
                value: recent,
                onRetry: () => ref.invalidate(recentReportsProvider),
                data: (list) => list.isEmpty
                    ? const EmptyState(icon: Icons.inbox_outlined, title: 'Todavía no hay reportes')
                    : Column(children: [
                        for (final r in list)
                          Padding(padding: const EdgeInsets.only(bottom: 10), child: ReportCard(report: r)),
                      ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({this.name, required this.unread});
  final String? name;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final first = (name ?? '').trim().split(' ').first;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(children: [
          // Ola decorativa sutil
          Positioned(
            right: -40,
            top: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(18)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.waves_rounded, color: AppColors.aqua),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(first.isEmpty ? 'Hola' : 'Hola, $first',
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: () => context.push('/notifications'),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              const Text('Registro de Riesgos Santa Marta',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, height: 1.15)),
              const SizedBox(height: 10),
              const Text(
                'Reporta una problemática de tu ciudad y ayúdanos a identificar dónde se necesita atención.',
                style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.reportGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  boxShadow: [BoxShadow(color: AppColors.coral.withAlpha(110), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(54),
                  ),
                  onPressed: () => context.push('/report/new'),
                  icon: const Icon(Icons.add_location_alt_rounded),
                  label: const Text('REPORTAR PROBLEMÁTICA'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String key, IconData icon, Color color) => Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ((stats[key] as num?) ?? 0).toDouble()),
                duration: const Duration(milliseconds: 700),
                builder: (_, v, __) => Text('${v.round()}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              ),
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ),
        );
    return Row(children: [
      tile('Reportes', 'total', Icons.assignment_rounded, AppColors.ocean),
      const SizedBox(width: 8),
      tile('Abiertos', 'open', Icons.pending_actions_rounded, AppColors.warning),
      const SizedBox(width: 8),
      tile('Atendidos', 'resolved', Icons.task_alt_rounded, AppColors.success),
      const SizedBox(width: 8),
      tile('Críticos', 'critical_open', Icons.crisis_alert_rounded, AppColors.danger),
    ]);
  }
}

class _MapAccessCard extends StatelessWidget {
  const _MapAccessCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.foam,
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppColors.ocean, borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.map_rounded, color: Colors.white),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Mapa de Riesgos', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Mira dónde se concentran las problemáticas de la ciudad.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: AppColors.ocean),
      ]),
    );
  }
}

class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.report, required this.distance});
  final Report report;
  final double distance;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        onTap: () => context.go('/map'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SeverityBadge(report.severity, showLabel: false),
            const SizedBox(width: 6),
            Expanded(
              child: Text(Formatters.distance(distance),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ocean)),
            ),
            StatusChip(report.status, dense: true),
          ]),
          const SizedBox(height: 8),
          Text(report.title, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          CategoryLabel(name: report.categoryName, colorHex: report.categoryColor, icon: report.categoryIcon),
        ]),
      ),
    );
  }
}
