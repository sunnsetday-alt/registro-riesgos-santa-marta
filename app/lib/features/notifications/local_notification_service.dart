import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notificaciones del sistema Android (bandeja de notificaciones).
///
/// Se disparan cuando:
///  * llega una fila nueva a `notifications` por Realtime (cambios de estado:
///    recibido, validado, en proceso, atendido, cerrado, rechazado), o
///  * se sincroniza un reporte que estaba guardado sin conexión.
///
/// Para notificaciones con la app cerrada se deja preparada la tabla
/// `device_tokens` y la integración FCM (ver docs/NOTIFICACIONES.md).
class LocalNotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  int _id = 0;

  static const _channel = AndroidNotificationDetails(
    'rsm_reportes',
    'Estado de mis reportes',
    channelDescription: 'Avisos cuando tus reportes cambian de estado',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  Future<void> show({required String title, required String body}) async {
    if (kIsWeb) return;
    if (!_ready) await init();
    await _plugin.show(_id++, title, body, const NotificationDetails(android: _channel));
  }
}

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) => LocalNotificationService());
