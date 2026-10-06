import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/common.dart';
import '../data/auth_repository.dart';
import 'auth_widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _accepted = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_accepted) {
      showSnack(context, 'Debes aceptar la política de privacidad y los términos.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final loggedIn = await ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            fullName: _name.text,
            phone: _phone.text,
          );
      if (!mounted) return;
      if (!loggedIn) {
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Confirma tu correo'),
            content: Text('Enviamos un enlace de confirmación a ${_email.text.trim()}. '
                'Confírmalo y luego inicia sesión.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido'))],
          ),
        );
        if (mounted) context.go('/login');
      }
    } catch (e) {
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
          const AuthHeader(title: 'Crear cuenta', subtitle: 'Tus datos personales no se publican en el mapa.'),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline_rounded)),
                  validator: Validators.fullName,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline_rounded)),
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: Validators.phoneOptional,
                ),
                const SizedBox(height: 14),
                PasswordField(controller: _password, validator: Validators.password),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _confirm,
                  label: 'Confirmar contraseña',
                  validator: (v) => v != _password.text ? 'Las contraseñas no coinciden' : null,
                ),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: _accepted,
                  onChanged: (v) => setState(() => _accepted = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text.rich(TextSpan(
                    style: const TextStyle(fontSize: 13),
                    children: [
                      const TextSpan(text: 'Acepto la '),
                      TextSpan(
                        text: 'política de privacidad',
                        style: const TextStyle(color: AppColors.ocean, fontWeight: FontWeight.w700),
                        recognizer: TapGestureRecognizer()..onTap = () => context.push('/legal/privacidad'),
                      ),
                      const TextSpan(text: ' y los '),
                      TextSpan(
                        text: 'términos y condiciones',
                        style: const TextStyle(color: AppColors.ocean, fontWeight: FontWeight.w700),
                        recognizer: TapGestureRecognizer()..onTap = () => context.push('/legal/terminos'),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  )),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('CREAR CUENTA'),
                ),
                TextButton(onPressed: () => context.pop(), child: const Text('Ya tengo cuenta')),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
