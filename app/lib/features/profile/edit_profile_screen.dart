import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/errors.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/common.dart';
import '../auth/application/session_controller.dart';
import '../auth/data/auth_repository.dart';
import '../auth/presentation/auth_widgets.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pwdKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _password = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(sessionProvider).profile;
    _name = TextEditingController(text: p?.fullName ?? '');
    _phone = TextEditingController(text: p?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).updateProfile(fullName: _name.text, phone: _phone.text);
      await ref.read(sessionProvider).refreshProfile();
      if (mounted) {
        showSnack(context, 'Perfil actualizado');
        context.pop();
      }
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _changePassword() async {
    if (!(_pwdKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(_password.text);
      _password.clear();
      if (mounted) showSnack(context, 'Contraseña actualizada');
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.person_outline)),
              validator: Validators.fullName,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)', prefixIcon: Icon(Icons.phone_outlined)),
              validator: Validators.phoneOptional,
            ),
            const SizedBox(height: 18),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('GUARDAR CAMBIOS')),
          ]),
        ),
        const SectionHeader('Cambiar contraseña'),
        Form(
          key: _pwdKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PasswordField(controller: _password, label: 'Nueva contraseña', validator: Validators.password),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: _saving ? null : _changePassword, child: const Text('Actualizar contraseña')),
          ]),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tu nombre, correo y teléfono son privados: solo los ve el personal autorizado '
          'para gestionar tus reportes y nunca aparecen en el mapa público.',
          style: TextStyle(fontSize: 12.5),
        ),
      ]),
    );
  }
}
