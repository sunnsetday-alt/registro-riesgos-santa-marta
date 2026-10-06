import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/constants/severity.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/report_draft.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/report_widgets.dart';
import '../../map/widgets/map_layers.dart';
import '../../offline/sync_service.dart';
import '../application/reports_providers.dart';

/// Resumen previo al envío (sección 4 del requerimiento).
class ConfirmReportScreen extends ConsumerStatefulWidget {
  const ConfirmReportScreen({super.key, required this.draft});
  final ReportDraft draft;

  @override
  ConsumerState<ConfirmReportScreen> createState() => _ConfirmReportScreenState();
}

class _ConfirmReportScreenState extends ConsumerState<ConfirmReportScreen> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      final result = await ref.read(syncServiceProvider).submit(widget.draft);
      if (!mounted) return;
      ref.invalidate(myReportsProvider);
      ref.invalidate(recentReportsProvider);
      switch (result) {
        case SubmitSent(:final report):
          context.go('/report/success', extra: {'code': report.code, 'id': report.id, 'queued': false});
        case SubmitQueued():
          context.go('/report/success', extra: {'queued': true});
      }
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final sev = Severity.of(d.severity);
    final pos = LatLng(d.latitude, d.longitude);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmar reporte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          const Text('Revisa la información antes de enviarla.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          if (d.localPhotoPath != null && File(d.localPhotoPath!).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radius),
              child: Image.file(File(d.localPhotoPath!), height: 200, fit: BoxFit.cover),
            )
          else
            const AppCard(
              child: Row(children: [
                Icon(Icons.no_photography_outlined, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Text('Sin fotografía'),
              ]),
            ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(d.description),
              const Divider(height: 28),
              _row(Icons.category_outlined, 'Categoría', d.categoryName),
              _rowWidget(Icons.priority_high_rounded, 'Importancia', SeverityBadge(d.severity)),
              Padding(
                padding: const EdgeInsets.only(left: 30, bottom: 8),
                child: Text(sev.explanation, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
              _row(Icons.place_outlined, 'Dirección',
                  (d.address == null || d.address!.isEmpty) ? 'No indicada' : d.address!),
              _row(Icons.gps_fixed_rounded, 'Coordenadas', Formatters.coords(d.latitude, d.longitude)),
              _row(Icons.event_outlined, 'Fecha', Formatters.dateTime(d.reportedAt)),
            ]),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            child: SizedBox(
              height: 170,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: pos,
                  initialZoom: 16,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  baseTileLayer(),
                  MarkerLayer(markers: [
                    Marker(
                      point: pos,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_on_rounded, color: AppColors.coral, size: 44),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _sending ? null : () => context.pop(),
                child: const Text('Editar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'ENVIANDO…' : 'ENVIAR REPORTE'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) =>
      _rowWidget(icon, label, Text(value, style: const TextStyle(fontWeight: FontWeight.w600)));

  Widget _rowWidget(IconData icon, String label, Widget value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: AppColors.ocean),
          const SizedBox(width: 10),
          SizedBox(width: 92, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: value)),
        ]),
      );
}
