import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/report_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/category.dart';
import '../../../data/models/report.dart';
import '../../../data/models/report_activity.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/report_widgets.dart';
import '../../reports/application/reports_providers.dart';
import '../../reports/presentation/report_detail_screen.dart';
import '../../reports/presentation/widgets/form_widgets.dart';
import '../application/admin_providers.dart';
import '../data/admin_repository.dart';

/// Gestión de un reporte: estado, observaciones, edición y duplicados.
class AdminReportDetailScreen extends ConsumerWidget {
  const AdminReportDetailScreen({super.key, required this.reportId});
  final String reportId;

  void _refresh(WidgetRef ref) {
    ref.invalidate(reportDetailProvider(reportId));
    ref.invalidate(reportHistoryProvider(reportId));
    ref.invalidate(reportObservationsProvider(reportId));
    ref.invalidate(duplicatesProvider(reportId));
    ref.invalidate(adminReportsProvider);
    ref.invalidate(dashboardStatsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportDetailProvider(reportId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar reporte'),
        actions: [
          if (report.valueOrNull != null)
            IconButton(
              tooltip: 'Modificar información',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final ok = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  showDragHandle: true,
                  builder: (_) => _EditReportSheet(report: report.value!),
                );
                if (ok == true) _refresh(ref);
              },
            ),
        ],
      ),
      body: AsyncView<Report?>(
        value: report,
        onRetry: () => _refresh(ref),
        data: (r) {
          if (r == null) return const EmptyState(icon: Icons.search_off_rounded, title: 'Reporte no encontrado');
          return RefreshIndicator(
            onRefresh: () async => _refresh(ref),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 120), children: [
              _ActionsCard(report: r, onChanged: () => _refresh(ref)),
              const SizedBox(height: 14),
              ReportInfoSection(report: r),
              const SizedBox(height: 14),
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Índice de prioridad', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Row(children: [
                    PriorityBadge(level: r.priorityLevel, score: r.priorityScore),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: r.priorityScore / 100,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                    'Calculado con importancia, reportes similares, antigüedad, categoría y concentración geográfica.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (r.adminNotes != null && r.adminNotes!.isNotEmpty) ...[
                    const Divider(height: 24),
                    const Text('Notas administrativas', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(r.adminNotes!),
                  ],
                ]),
              ),
              _DuplicatesSection(reportId: r.id, duplicateOf: r.duplicateOf, onChanged: () => _refresh(ref)),
              if (r.userId != null) _ReporterCard(userId: r.userId!),
              const SectionHeader('Historial de estados y observaciones'),
              AppCard(child: ReportTimeline(reportId: r.id, showAuthors: true)),
            ]),
          );
        },
      ),
    );
  }
}

class _ActionsCard extends ConsumerWidget {
  const _ActionsCard({required this.report, required this.onChanged});
  final Report report;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      color: AppColors.foam,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Text('Estado actual: ', style: TextStyle(fontWeight: FontWeight.w700)),
          StatusChip(report.status),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => _StatusDialog(report: report));
                if (ok == true) onChanged();
              },
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Cambiar estado'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(context: context, builder: (_) => _ObservationDialog(reportId: report.id));
                if (ok == true) onChanged();
              },
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('Observación'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _StatusDialog extends ConsumerStatefulWidget {
  const _StatusDialog({required this.report});
  final Report report;

  @override
  ConsumerState<_StatusDialog> createState() => _StatusDialogState();
}

class _StatusDialogState extends ConsumerState<_StatusDialog> {
  String? _status;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_status == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).changeStatus(widget.report.id, _status!, _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar estado'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final s in ReportStatus.all.where((s) => s.code != widget.report.status))
            RadioListTile<String>(
              value: s.code,
              groupValue: _status,
              onChanged: (v) => setState(() => _status = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Row(children: [
                Icon(s.icon, size: 18, color: s.color),
                const SizedBox(width: 8),
                Text(s.name),
              ]),
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              labelText: 'Observación (visible para el ciudadano)',
              hintText: 'Ej.: Se verificó en campo. Se requiere intervención vial.',
            ),
          ),
          const Text('Se registrará: estado anterior, nuevo estado, fecha y administrador responsable.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
        ]),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _saving || _status == null ? null : _save,
          child: Text(_saving ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }
}

class _ObservationDialog extends ConsumerStatefulWidget {
  const _ObservationDialog({required this.reportId});
  final String reportId;

  @override
  ConsumerState<_ObservationDialog> createState() => _ObservationDialogState();
}

class _ObservationDialogState extends ConsumerState<_ObservationDialog> {
  final _body = TextEditingController();
  bool _public = true;
  bool _saving = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_body.text.trim().length < 2) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).addObservation(widget.reportId, _body.text, isPublic: _public);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar observación'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _body,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Escribe la observación…'),
        ),
        SwitchListTile(
          value: _public,
          onChanged: (v) => setState(() => _public = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Visible para el ciudadano'),
          subtitle: Text(_public ? 'Se le notificará la actualización.' : 'Nota interna del equipo.'),
        ),
      ]),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: _saving ? null : _save, child: const Text('Agregar')),
      ],
    );
  }
}

class _DuplicatesSection extends ConsumerWidget {
  const _DuplicatesSection({required this.reportId, required this.duplicateOf, required this.onChanged});
  final String reportId;
  final String? duplicateOf;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dups = ref.watch(duplicatesProvider(reportId)).valueOrNull ?? const <DuplicateCandidate>[];
    if (dups.isEmpty) return const SizedBox.shrink();

    Future<void> decide(DuplicateCandidate d, String decision) async {
      try {
        await ref.read(adminRepositoryProvider).resolveDuplicate(d.id, decision);
        onChanged();
      } catch (e) {
        if (context.mounted) showSnack(context, AppError.message(e), error: true);
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Posibles duplicados'),
      for (final d in dups)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: AppCard(
            color: d.decision == 'pendiente' ? const Color(0xFFF5F3FF) : Colors.white,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.copy_all_rounded, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${d.candidateCode} · ${d.candidateTitle}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 6),
              Text('A ${d.distanceM.toStringAsFixed(0)} m · similitud de texto ${(d.textSimilarity * 100).round()}% · '
                  'puntaje ${(d.score * 100).round()}%',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text('Decisión: ${d.decision}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                TextButton(
                  onPressed: () => context.push('/admin/reports/${d.candidateId}'),
                  child: const Text('Ver original'),
                ),
                if (d.decision != 'confirmado')
                  FilledButton.tonal(onPressed: () => decide(d, 'confirmado'), child: const Text('Es duplicado')),
                if (d.decision != 'descartado')
                  OutlinedButton(onPressed: () => decide(d, 'descartado'), child: const Text('No es duplicado')),
              ]),
            ]),
          ),
        ),
      const Text(
        'Ningún reporte se elimina automáticamente. Confirmar un duplicado lo vincula al original '
        'y lo oculta del mapa público; el original sube de prioridad.',
        style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
      ),
    ]);
  }
}

/// Datos de contacto del ciudadano (privados; solo personal autorizado).
class _ReporterCard extends ConsumerWidget {
  const _ReporterCard({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(reporterProvider(userId)).valueOrNull;
    if (p == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader('Ciudadano (información privada)'),
      AppCard(
        child: Row(children: [
          const Icon(Icons.lock_person_outlined, color: AppColors.ocean),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.fullName.isEmpty ? 'Sin nombre' : p.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (p.phone != null) Text(p.phone!),
              const Text('Uso exclusivo para la gestión del reporte.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

/// "Modificar información" del reporte.
class _EditReportSheet extends ConsumerStatefulWidget {
  const _EditReportSheet({required this.report});
  final Report report;

  @override
  ConsumerState<_EditReportSheet> createState() => _EditReportSheetState();
}

class _EditReportSheetState extends ConsumerState<_EditReportSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.report.title);
  late final _description = TextEditingController(text: widget.report.description);
  late final _address = TextEditingController(text: widget.report.address ?? '');
  late final _notes = TextEditingController(text: widget.report.adminNotes ?? '');
  late int _categoryId = widget.report.categoryId;
  late int _severity = widget.report.severity;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_title, _description, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(adminRepositoryProvider).updateReport(widget.report.id, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'admin_notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'category_id': _categoryId,
        'severity': _severity,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(categoriesProvider).valueOrNull ?? const <Category>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
          Text('Modificar información', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Título'), validator: Validators.reportTitle),
          const SizedBox(height: 12),
          TextFormField(
            controller: _description,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: 'Descripción'),
            validator: Validators.reportDescription,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: cats.any((c) => c.id == _categoryId) ? _categoryId : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [for (final c in cats) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _categoryId = v ?? _categoryId),
          ),
          const SizedBox(height: 14),
          const Text('Nivel de importancia', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SeveritySelector(value: _severity, onChanged: (v) => setState(() => _severity = v)),
          const SizedBox(height: 12),
          TextFormField(controller: _address, decoration: const InputDecoration(labelText: 'Dirección / referencia'),
              validator: Validators.address),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notes,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Notas administrativas (internas)'),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Guardando…' : 'Guardar cambios')),
        ]),
      ),
    );
  }
}
