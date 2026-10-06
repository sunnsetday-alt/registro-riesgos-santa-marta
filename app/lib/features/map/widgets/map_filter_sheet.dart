import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/report_status.dart';
import '../../../core/constants/severity.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/report_filter.dart';
import '../../reports/application/reports_providers.dart';

/// Hoja inferior con filtros: categoría, importancia, estado, fecha y sector.
class MapFilterSheet extends ConsumerStatefulWidget {
  const MapFilterSheet({super.key, required this.initial, this.showRejected = false});
  final ReportFilter initial;
  final bool showRejected;

  static Future<ReportFilter?> show(BuildContext context, ReportFilter initial, {bool showRejected = false}) {
    return showModalBottomSheet<ReportFilter>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MapFilterSheet(initial: initial, showRejected: showRejected),
    );
  }

  @override
  ConsumerState<MapFilterSheet> createState() => _MapFilterSheetState();
}

class _MapFilterSheetState extends ConsumerState<MapFilterSheet> {
  late ReportFilter f = widget.initial;

  Set<T> _toggle<T>(Set<T> s, T v) => s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  void _preset(int? days) {
    setState(() {
      // Primero se limpian ambas fechas; luego se fija solo "desde".
      f = f.copyWith(clearDates: true);
      if (days != null) f = f.copyWith(from: DateTime.now().subtract(Duration(days: days)));
    });
  }

  Future<void> _customRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: now,
      initialDateRange: f.from != null ? DateTimeRange(start: f.from!, end: f.to ?? now) : null,
    );
    if (range != null) {
      setState(() => f = f.copyWith(from: range.start, to: range.end.add(const Duration(days: 1))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final sectors = ref.watch(sectorsProvider).valueOrNull ?? const [];
    final statuses = ReportStatus.all.where((s) => widget.showRejected || s.code != ReportStatus.rechazado);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
            Text('Filtros', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            _title('Categoría'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in categories)
                FilterChip(
                  avatar: Icon(c.iconData, size: 16, color: c.color),
                  label: Text(c.name),
                  selected: f.categoryIds.contains(c.id),
                  onSelected: (_) => setState(() => f = f.copyWith(categoryIds: _toggle(f.categoryIds, c.id))),
                ),
            ]),
            _title('Nivel de importancia'),
            Wrap(spacing: 6, children: [
              for (final s in Severity.all)
                FilterChip(
                  avatar: CircleAvatar(backgroundColor: s.color, radius: 7),
                  label: Text('${s.level} ${s.label}'),
                  selected: f.severities.contains(s.level),
                  onSelected: (_) => setState(() => f = f.copyWith(severities: _toggle(f.severities, s.level))),
                ),
            ]),
            _title('Estado'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final s in statuses)
                FilterChip(
                  avatar: Icon(s.icon, size: 16, color: s.color),
                  label: Text(s.name),
                  selected: f.statuses.contains(s.code),
                  onSelected: (_) => setState(() => f = f.copyWith(statuses: _toggle(f.statuses, s.code))),
                ),
            ]),
            _title('Fecha'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              ChoiceChip(label: const Text('Todas'), selected: f.from == null, onSelected: (_) => _preset(null)),
              for (final d in [7, 30, 90])
                ChoiceChip(
                  label: Text('Últimos $d días'),
                  selected: f.from != null && f.to == null &&
                      DateTime.now().difference(f.from!).inDays == d,
                  onSelected: (_) => _preset(d),
                ),
              ActionChip(
                avatar: const Icon(Icons.date_range_rounded, size: 16),
                label: Text(f.from != null && f.to != null
                    ? '${Formatters.dateShort(f.from!)} – ${Formatters.dateShort(f.to!.subtract(const Duration(days: 1)))}'
                    : 'Rango personalizado'),
                onPressed: _customRange,
              ),
            ]),
            _title('Sector'),
            DropdownButtonFormField<int?>(
              value: f.sectorId,
              isExpanded: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.map_outlined)),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todos los sectores')),
                for (final s in sectors) DropdownMenuItem<int?>(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => f = v == null ? f.copyWith(clearSector: true) : f.copyWith(sectorId: v)),
            ),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, ReportFilter(orderBy: f.orderBy)),
                  child: const Text('Limpiar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(onPressed: () => Navigator.pop(context, f), child: const Text('Aplicar filtros')),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
      );
}
