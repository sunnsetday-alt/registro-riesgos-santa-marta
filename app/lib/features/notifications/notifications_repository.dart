import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/report_activity.dart';
import '../../data/supabase_providers.dart';
import '../auth/application/session_controller.dart';
import 'local_notification_service.dart';

class NotificationsRepository {
  NotificationsRepository(this._client);
  final SupabaseClient _client;

  Future<List<AppNotification>> fetch() async {
    final rows = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', uid)
        .isFilter('read_at', null);
  }

  /// Escucha en tiempo real las notificaciones nuevas del usuario.
  RealtimeChannel subscribe(String userId, void Function(AppNotification) onInsert) {
    return _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onInsert(AppNotification.fromMap(payload.newRecord)),
        )
        .subscribe();
  }

  Future<void> unsubscribe(RealtimeChannel channel) => _client.removeChannel(channel);
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(supabaseProvider)));

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(notificationsRepositoryProvider).fetch(),
);

/// Conecta Realtime ↔ notificaciones del sistema mientras haya sesión.
/// Se activa desde el shell principal con `ref.watch(notificationListenerProvider)`.
final notificationListenerProvider = Provider<void>((ref) {
  final uid = ref.watch(sessionProvider.select((s) => s.userId));
  if (uid == null) return;
  final repo = ref.watch(notificationsRepositoryProvider);
  final local = ref.watch(localNotificationServiceProvider);
  final channel = repo.subscribe(uid, (n) {
    local.show(title: n.title, body: n.body);
    ref.invalidate(notificationsProvider);
  });
  ref.onDispose(() => repo.unsubscribe(channel));
});
