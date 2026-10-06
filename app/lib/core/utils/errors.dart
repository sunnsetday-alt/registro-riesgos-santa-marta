import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Convierte excepciones técnicas en mensajes comprensibles para el usuario.
class AppError {
  AppError._();

  static String message(Object error) {
    if (error is AuthException) return _auth(error);
    if (error is PostgrestException) {
      if (error.code == '42501') return 'No tienes permisos para realizar esta acción.';
      if (error.code == 'P0001') return error.message;
      if (error.code == '23505') return 'Este registro ya existe.';
      if (error.code == '23514') return 'Algún dato no cumple las reglas de validación.';
      return error.message;
    }
    if (error is StorageException) return 'No se pudo subir la fotografía: ${error.message}';
    if (isNetwork(error)) return 'Sin conexión a Internet. Inténtalo nuevamente.';
    return 'Ocurrió un error inesperado. Inténtalo nuevamente.';
  }

  static String _auth(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'Correo o contraseña incorrectos.';
    if (m.contains('email not confirmed')) return 'Debes confirmar tu correo antes de ingresar.';
    if (m.contains('already registered')) return 'Ya existe una cuenta con este correo.';
    if (m.contains('token has expired') || m.contains('invalid')) {
      return 'El código no es válido o ya expiró.';
    }
    if (m.contains('rate limit')) return 'Demasiados intentos. Espera unos minutos.';
    return e.message;
  }

  /// Detecta errores de red (para decidir si guardar el reporte offline).
  static bool isNetwork(Object error) {
    if (error is SocketException || error is TimeoutException || error is HttpException) {
      return true;
    }
    final s = error.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('connection refused') ||
        s.contains('connection closed') ||
        s.contains('network is unreachable') ||
        s.contains('clientexception');
  }
}
