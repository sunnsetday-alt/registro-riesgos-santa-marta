import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/report.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/report_widgets.dart';
import '../../map/widgets/map_filter_sheet.dart';
import '../application/admin_providers.dart';

/// Listado de todos los reportes: búsqueda, filtros y orden por prioridad.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(adminReportFilterProvider).search ?? '';
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      final f = ref.read(adminReportFilterProvider);
      ref.read(adminReportFilterProvider.notifier).state = f.copyWith(search: v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(adminReportFilterProvider);
    final reports = ref.watch(adminReportsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Buscar por código, título, dirección…',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Badge(
              isLabelVisible: filter.activeCount > 0,
              label: Text('${filter.activeCount}'),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.tune_rounded),
                onPressed: () async {
                  final res = await MapFilterSheet.show(context, filter, showRejected: true);
                  if (res != null) {
                    ref.read(adminReportFilterProvider.notifier).state =
                        res.copyWith(search: _search.text, orderBy: filter.orderBy,
                            onlyPossibleDuplicates: filter.onlyPossibleDuplicates);
                  }
                },
              ),
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            ChoiceChip(
              label: const Text('Mayor prioridad'),
              selected: filter.orderBy == 'priority_score',
              onSelected: (_) => ref.read(adminReportFilterProvider.notifier).state =
                  filter.copyWith(orderBy: 'priority_score'),
            ),
            const SizedBox(width: 6),
            ChoiceChip(
              label: const Text('Más recientes'),
              selected: filter.orderBy == 'created_at',
              onSelected: (_) =>
                  ref.read(adminReportFilterProvider.notifier).state = filter.copyWith(orderBy: 'created_at'),
            ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Posibles duplicados'),
              selected: filter.onlyPossibleDuplicates,
              onSelected: (v) => ref.read(adminReportFilterProvider.notifier).state =
                  filter.copyWith(onlyPossibleDuplicates: v),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(adminReportsProvider),
            child: AsyncView<List<Report>>(
              value: reports,
              onRetry: () => ref.invalidate(adminReportsProvider),
              data: (list) => list.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 60),
                      EmptyState(icon: Icons.search_off_rounded, title: 'Sin resultados', message: 'Ajusta la búsqueda o los filtros.'),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: list.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return Text('${list.length} reporte(s)',
                              style: Theme.of(context).textTheme.labelLarge);
                        }
                        final r = list[i - 1];
                        return ReportCard(
                          report: r,
                          showPriority: true,
                          onTap: () => context.push('/admin/reports/${r.id}'),
                        );
                      },
                    ),
            ),
          ),
        ),
      ]),
    );
  }
}
