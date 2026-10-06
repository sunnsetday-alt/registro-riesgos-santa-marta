import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/errors.dart';
import '../../data/models/report.dart';
import '../../data/models/report_draft.dart';
import '../notifications/local_notification_service.dart';
import '../reports/data/reports_repository.dart';
import 'offline_queue.dart';

/// Resultado de enviar un reporte.
sealed class SubmitResult {
  const SubmitResult();
}

class SubmitSent extends SubmitResult {
  final Report report;
  const SubmitSent(this.report);
}

class SubmitQueued extends SubmitResult {
  const SubmitQueued();
}

/// Orquesta el envío de reportes con soporte sin conexión.
///
/// * Si no hay red (o falla por red) → guarda en la cola local.
/// * Al recuperar la conexión (o al abrir la app) → sube foto, crea el
///   reporte con su ubicación y notifica localmente el código asignado.
class SyncService extends ChangeNotifier {
  SyncService(this._repo, this._queue, this._notifications) {
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      if (_hasNetwork(results)) syncPending();
    });
    _refreshCount();
  }

  final ReportsRepository _repo;
  final OfflineQueue _queue;
  final LocalNotificationService _notifications;
  late final StreamSubscription<List<ConnectivityResult>> _sub;

  bool _syncing = false;
  int _pendingCount = 0;

  int get pendingCount => _pendingCount;
  bool get syncing => _syncing;

  static bool _hasNetwork(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  Future<bool> isOnline() async => _hasNetwork(await Connectivity().checkConnectivity());

  Future<void> _refreshCount() async {
    if (kIsWeb) return; // la cola offline aplica solo a la app móvil
    _pendingCount = await _queue.count();
    notifyListeners();
  }

  Future<SubmitResult> submit(ReportDraft draft) async {
    if (kIsWeb) return SubmitSent(await _repo.submit(draft));
    if (!await isOnline()) {
      await _queue.enqueue(draft);
      await _refreshCount();
      return const SubmitQueued();
    }
    try {
      final report = await _repo.submit(draft);
      return SubmitSent(report);
    } catch (e) {
      if (AppError.isNetwork(e)) {
        await _queue.enqueue(draft);
        await _refreshCount();
        return const SubmitQueued();
      }
      rethrow;
    }
  }

  /// Envía todos los reportes pendientes. Seguro de llamar varias veces.
  Future<int> syncPending() async {
    if (_syncing || kIsWeb) return 0;
    _syncing = true;
    notifyListeners();
    var sent = 0;
    try {
      final drafts = await _queue.pending();
      for (final d in drafts) {
        try {
          final report = await _repo.submit(d);
          await _queue.remove(d.clientUuid);
          sent++;
          await _notifications.show(
            title: 'Reporte enviado',
            body: 'Tu reporte "${report.title}" fue enviado con el código ${report.code}.',
          );
        } catch (e) {
          await _queue.markFailed(d.clientUuid, e.toString());
          if (AppError.isNetwork(e)) break; // se perdió la red: reintentar luego
        }
      }
    } finally {
      _syncing = false;
      await _refreshCount();
    }
    return sent;
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final syncServiceProvider = ChangeNotifierProvider<SyncService>((ref) => SyncService(
      ref.watch(reportsRepositoryProvider),
      ref.watch(offlineQueueProvider),
      ref.watch(localNotificationServiceProvider),
    ));
