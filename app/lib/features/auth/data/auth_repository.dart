import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/profile.dart';
import '../../../data/supabase_providers.dart';

/// Operaciones de autenticación y perfil sobre Supabase Auth.
class AuthRepository {
  AuthRepository(this._client);
  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  Stream<AuthState> get authChanges => _client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Registra al ciudadano. Los metadatos los usa el trigger handle_new_user
  /// para crear el perfil. Devuelve true si la sesión quedó abierta (cuando la
  /// confirmación por correo está desactivada).
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final res = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
        'accepted_terms': true,
      },
    );
    return res.session != null;
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Paso 1 de recuperación: envía un código de 6 dígitos al correo
  /// (la plantilla "Reset Password" debe incluir {{ .Token }}, ver docs).
  Future<void> sendRecoveryCode(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  /// Paso 2: valida el código y establece la nueva contraseña.
  Future<void> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _client.auth.verifyOTP(type: OtpType.recovery, email: email.trim(), token: code.trim());
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> changePassword(String newPassword) =>
      _client.auth.updateUser(UserAttributes(password: newPassword));

  Future<Profile?> fetchCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row, email: user.email);
  }

  Future<void> updateProfile({required String fullName, String? phone}) async {
    final user = currentUser;
    if (user == null) throw AuthException('Sesión no iniciada');
    await _client.from('profiles').update({
      'full_name': fullName.trim(),
      'phone': (phone == null || phone.trim().isEmpty) ? null : phone.trim(),
    }).eq('id', user.id);
  }
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository(ref.watch(supabaseProvider)));
