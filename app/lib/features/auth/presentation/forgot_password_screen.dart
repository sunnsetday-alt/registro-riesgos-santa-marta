import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/errors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../application/session_controller.dart';
import '../data/auth_repository.dart';
import 'auth_widgets.dart';

/// Recuperación de contraseña en dos pasos con código enviado al correo.
/// (No requiere configurar enlaces profundos en Android.)
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (Validators.email(_email.text) != null) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendRecoveryCode(_email.text);
      if (mounted) {
        setState(() => _codeSent = true);
        showSnack(context, 'Si el correo está registrado, recibirás un código.');
      }
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reset() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    final session = ref.read(sessionProvider);
    session.recovering = true;
    try {
      await ref.read(authRepositoryProvider).resetPasswordWithCode(
            email: _email.text,
            code: _code.text,
            newPassword: _password.text,
          );
      session.recovering = false;
      if (mounted) {
        showSnack(context, 'Contraseña actualizada correctamente.');
        context.go('/home');
      }
    } catch (e) {
      session.recovering = false;
      if (mounted) showSnack(context, AppError.message(e), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          const AuthHeader(title: 'Recuperar contraseña', subtitle: 'Te enviaremos un código a tu correo.'),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _email,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline_rounded)),
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                if (_codeSent) ...[
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    decoration: const InputDecoration(labelText: 'Código recibido', prefixIcon: Icon(Icons.pin_outlined)),
                    validator: (v) => (v == null || v.trim().length < 6) ? 'Ingresa el código' : null,
                  ),
                  PasswordField(controller: _password, label: 'Nueva contraseña', validator: Validators.password),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _loading ? null : _reset,
                    child: const Text('CAMBIAR CONTRASEÑA'),
                  ),
                  TextButton(onPressed: _loading ? null : _sendCode, child: const Text('Reenviar código')),
                ] else
                  FilledButton(onPressed: _loading ? null : _sendCode, child: const Text('ENVIAR CÓDIGO')),
                TextButton(onPressed: () => context.pop(), child: const Text('Volver')),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
