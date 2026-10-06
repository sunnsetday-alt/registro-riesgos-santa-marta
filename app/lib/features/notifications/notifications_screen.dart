import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/report_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/report_activity.dart';
import '../../shared/widgets/common.dart';
import 'notifications_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationsRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
            },
            child: const Text('Marcar leídas'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: AsyncView<List<AppNotification>>(
          value: notifications,
          onRetry: () => ref.invalidate(notificationsProvider),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(icon: Icons.notifications_none_rounded, title: 'Sin notificaciones'),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = list[i];
                    final status = ReportStatus.of(n.type);
                    return AppCard(
                      color: n.isRead ? Colors.white : AppColors.foam,
                      onTap: n.reportId == null ? null : () => context.push('/my-reports/${n.reportId}'),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        CircleAvatar(
                          backgroundColor: status.color.withAlpha(35),
                          child: Icon(n.type == 'observacion' ? Icons.chat_bubble_outline_rounded : status.icon,
                              color: n.type == 'observacion' ? AppColors.turquoise : status.color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(n.body),
                            const SizedBox(height: 4),
                            Text(Formatters.relative(n.createdAt),
                                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
