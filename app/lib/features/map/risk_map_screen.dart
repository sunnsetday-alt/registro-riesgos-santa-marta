import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/severity.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/errors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../../data/models/report.dart';
import '../../data/models/report_filter.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/report_widgets.dart';
import '../admin/application/admin_providers.dart';
import '../reports/application/reports_providers.dart';
import 'location_service.dart';
import 'widgets/map_filter_sheet.dart';
import 'widgets/map_layers.dart';

/// "Mapa de Riesgos": todos los reportes como marcadores coloreados por
/// nivel de importancia, con filtros.
///
/// En modo [admin] usa la tabla completa (incluye rechazados y duplicados) y
/// permite abrir la gestión del reporte.
class RiskMapScreen extends ConsumerStatefulWidget {
  const RiskMapScreen({super.key, this.admin = false});
  final bool admin;

  @override
  ConsumerState<RiskMapScreen> createState() => _RiskMapScreenState();
}

class _RiskMapScreenState extends ConsumerState<RiskMapScreen> {
  final _controller = MapController();
  LatLng? _me;
  String? _selectedId;

  StateProvider<ReportFilter> get _filterProvider => widget.admin ? adminMapFilterProvider : mapFilterProvider;
  AutoDisposeFutureProvider<List<Report>> get _reportsProvider =>
      widget.admin ? adminMapReportsProvider : mapReportsProvider;

  Future<void> _locateMe() async {
    final res = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    if (!res.ok) {
      showSnack(context, res.error ?? 'No se pudo obtener tu ubicación', error: true);
      return;
    }
    setState(() => _me = LatLng(res.latitude!, res.longitude!));
    _controller.move(_me!, 15);
  }

  Future<void> _openFilters() async {
    final current = ref.read(_filterProvider);
    final result = await MapFilterSheet.show(context, current, showRejected: widget.admin);
    if (result != null) ref.read(_filterProvider.notifier).state = result;
  }

  void _openReport(Report r) {
    setState(() => _selectedId = r.id);
    _controller.move(LatLng(r.latitude, r.longitude), _controller.camera.zoom < 15 ? 15 : _controller.camera.zoom);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _ReportSheet(report: r, admin: widget.admin),
    ).whenComplete(() {
      if (mounted) setState(() => _selectedId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(_reportsProvider);
    final filter = ref.watch(_filterProvider);
    final list = reports.valueOrNull ?? const <Report>[];
    // Los críticos se dibujan encima.
    final sorted = [...list]..sort((a, b) => a.severity.compareTo(b.severity));

    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _controller,
          options: MapOptions(initialCenter: Geo.santaMarta, initialZoom: 13, minZoom: 10),
          children: [
            baseTileLayer(),
            MarkerLayer(markers: [
              for (final r in sorted)
                Marker(
                  point: LatLng(r.latitude, r.longitude),
                  width: SeverityMarker.sizeFor(r.severity) + 8,
                  height: SeverityMarker.sizeFor(r.severity) + 8,
                  child: GestureDetector(
                    onTap: () => _openReport(r),
                    child: Center(
                      child: SeverityMarker(
                          severity: r.severity, icon: r.categoryIcon, selected: r.id == _selectedId),
                    ),
                  ),
                ),
              if (_me != null)
                Marker(
                  point: _me!,
                  width: 22,
                  height: 22,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.ocean,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x5503256C), blurRadius: 10)],
                    ),
                  ),
                ),
            ]),
          ],
        ),
        mapAttribution(),
        // Barra superior
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              if (widget.admin && Navigator.of(context).canPop()) ...[
                _glass(IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => context.pop())),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: _glass(Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(children: [
                    const Icon(Icons.map_rounded, color: AppColors.ocean),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.admin ? 'Mapa completo' : 'Mapa de Riesgos',
                            style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(
                          reports.isLoading ? 'Cargando…' : '${list.length} reportes',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ]),
                    ),
                    if (reports.isLoading)
                      const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ]),
                )),
              ),
              const SizedBox(width: 8),
              _glass(Badge(
                isLabelVisible: filter.activeCount > 0,
                label: Text('${filter.activeCount}'),
                child: IconButton(icon: const Icon(Icons.tune_rounded), onPressed: _openFilters),
              )),
            ]),
          ),
        ),
        if (reports.hasError)
          Positioned(
            top: 110,
            left: 16,
            right: 16,
            child: AppCard(
              child: Row(children: [
                const Icon(Icons.wifi_off_rounded, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(child: Text(AppError.message(reports.error!))),
                TextButton(onPressed: () => ref.invalidate(_reportsProvider), child: const Text('Reintentar')),
              ]),
            ),
          ),
        const Positioned(right: 12, bottom: 100, child: SeverityLegend()),
        Positioned(
          right: 12,
          bottom: 24,
          child: FloatingActionButton(
            heroTag: 'map_locate_${widget.admin}',
            backgroundColor: Colors.white,
            onPressed: _locateMe,
            child: const Icon(Icons.my_location_rounded, color: AppColors.ocean),
          ),
        ),
      ]),
    );
  }

  Widget _glass(Widget child) => Material(
        color: Colors.white.withAlpha(240),
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(16),
        child: child,
      );
}

/// Ficha de un reporte al tocar un marcador (sin datos personales).
class _ReportSheet extends StatelessWidget {
  const _ReportSheet({required this.report, required this.admin});
  final Report report;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final r = report;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          if (r.photoUrl != null) ...[NetworkPhoto(r.photoUrl, height: 190), const SizedBox(height: 12)],
          Row(children: [
            StatusChip(r.status),
            const SizedBox(width: 8),
            if (r.isTestData) const TestDataBadge(),
            const Spacer(),
            Text(r.code, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 10),
          Text(r.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            CategoryLabel(name: r.categoryName, colorHex: r.categoryColor, icon: r.categoryIcon),
            SeverityBadge(r.severity),
            if (admin) PriorityBadge(level: r.priorityLevel, score: r.priorityScore),
          ]),
          const SizedBox(height: 12),
          Text(r.description),
          const SizedBox(height: 12),
          _line(Icons.event_outlined, Formatters.dateTime(r.createdAt)),
          if (r.address != null) _line(Icons.place_outlined, r.address!),
          if (r.sectorName != null) _line(Icons.map_outlined, r.sectorName!),
          _line(Icons.gps_fixed_rounded, Formatters.coords(r.latitude, r.longitude)),
          _line(Severity.of(r.severity).icon, Severity.of(r.severity).explanation),
          if (admin) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/admin/reports/${r.id}');
              },
              icon: const Icon(Icons.admin_panel_settings_rounded),
              label: const Text('Gestionar reporte'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5))),
        ]),
      );
}
