import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/profile.dart';
import '../data/auth_repository.dart';

/// Estado de sesión observable por el router (refreshListenable).
///
/// Mantiene el usuario autenticado y su perfil (rol). El router usa este
/// estado para proteger rutas: sin sesión → /login; sin rol staff → no /admin.
class SessionController extends ChangeNotifier {
  SessionController(this._repo) {
    _sub = _repo.authChanges.listen((state) => _onAuth(state.event));
    _onAuth(AuthChangeEvent.initialSession);
  }

  final AuthRepository _repo;
  late final StreamSubscription<AuthState> _sub;

  Profile? _profile;
  bool _loadingProfile = false;
  bool _initialized = false;
  bool _recovering = false;

  bool get isLoggedIn => _repo.currentUser != null;
  bool get initialized => _initialized;
  Profile? get profile => _profile;
  bool get isStaff => _profile?.isStaff ?? false;
  bool get isAdmin => _profile?.isAdmin ?? false;
  String? get userId => _repo.currentUser?.id;

  /// Durante la recuperación de contraseña existe sesión temporal; el router
  /// no debe sacar al usuario de la pantalla de recuperación.
  bool get recovering => _recovering;
  set recovering(bool v) {
    _recovering = v;
    notifyListeners();
  }

  Future<void> _onAuth(AuthChangeEvent event) async {
    if (_repo.currentUser == null) {
      _profile = null;
      _initialized = true;
      notifyListeners();
      return;
    }
    if (event == AuthChangeEvent.tokenRefreshed && _profile != null) return;
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    if (_loadingProfile) return;
    _loadingProfile = true;
    try {
      _profile = await _repo.fetchCurrentProfile();
    } catch (_) {
      // Sin conexión: se conserva el perfil anterior; la app sigue funcionando
      // en modo offline para crear reportes.
    } finally {
      _loadingProfile = false;
      _initialized = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final sessionProvider = ChangeNotifierProvider<SessionController>(
  (ref) => SessionController(ref.watch(authRepositoryProvider)),
);
