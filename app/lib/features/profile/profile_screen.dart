import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../shared/widgets/common.dart';
import '../auth/application/session_controller.dart';
import '../auth/data/auth_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final p = session.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          AppCard(
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.ocean,
                child: Text(p?.initials ?? '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p?.fullName.isNotEmpty == true ? p!.fullName : 'Ciudadano',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  Text(p?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Chip(
                    label: Text(p?.roleName ?? 'Ciudadano', style: const TextStyle(fontSize: 11.5)),
                    visualDensity: VisualDensity.compact,
                  ),
                ]),
              ),
            ]),
          ),
          if (p != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text('Miembro desde ${Formatters.date(p.createdAt)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
          if (session.isStaff) ...[
            const SectionHeader('Administración'),
            AppCard(
              color: AppColors.deepSea,
              onTap: () => context.go('/admin'),
              child: const Row(children: [
                Icon(Icons.admin_panel_settings_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Abrir panel administrativo',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.white),
              ]),
            ),
          ],
          const SectionHeader('Cuenta'),
          _tile(context, Icons.edit_outlined, 'Editar perfil', () => context.push('/profile/edit')),
          _tile(context, Icons.notifications_none_rounded, 'Notificaciones', () => context.push('/notifications')),
          const SectionHeader('Información'),
          _tile(context, Icons.privacy_tip_outlined, 'Política de privacidad', () => context.push('/legal/privacidad')),
          _tile(context, Icons.description_outlined, 'Términos y condiciones', () => context.push('/legal/terminos')),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Deseas cerrar tu sesión?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cerrar sesión')),
                  ],
                ),
              );
              if (ok == true) await ref.read(authRepositoryProvider).signOut();
            },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text('Registro de Riesgos Santa Marta · v1.0.0',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          onTap: onTap,
          child: Row(children: [
            Icon(icon, color: AppColors.ocean),
            const SizedBox(width: 14),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ]),
        ),
      );
}
