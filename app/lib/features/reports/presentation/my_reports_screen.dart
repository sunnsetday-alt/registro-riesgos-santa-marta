import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/report.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/report_widgets.dart';
import '../../offline/sync_service.dart';
import '../application/reports_providers.dart';

class MyReportsScreen extends ConsumerWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(myReportsProvider);
    final sync = ref.watch(syncServiceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mis reportes')),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncServiceProvider).syncPending();
          ref.invalidate(myReportsProvider);
          await ref.read(myReportsProvider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          children: [
            if (sync.pendingCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  color: AppColors.sand,
                  child: Row(children: [
                    sync.syncing
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_off_rounded, color: Color(0xFFB7791F)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${sync.pendingCount} reporte(s) guardado(s) sin conexión. '
                        'Se enviarán automáticamente cuando recuperes la conexión.',
                      ),
                    ),
                    TextButton(
                      onPressed: sync.syncing
                          ? null
                          : () async {
                              final n = await ref.read(syncServiceProvider).syncPending();
                              ref.invalidate(myReportsProvider);
                              if (context.mounted && n > 0) showSnack(context, '$n reporte(s) enviado(s)');
                            },
                      child: const Text('Enviar'),
                    ),
                  ]),
                ),
              ),
            AsyncView<List<Report>>(
              value: reports,
              onRetry: () => ref.invalidate(myReportsProvider),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'Aún no tienes reportes',
                      message: 'Cuando reportes una problemática podrás seguir su estado aquí.',
                      action: FilledButton.icon(
                        onPressed: () => context.push('/report/new'),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Reportar problemática'),
                      ),
                    )
                  : Column(children: [
                      for (final r in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: ReportCard(report: r, onTap: () => context.push('/my-reports/${r.id}')),
                        ),
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}
