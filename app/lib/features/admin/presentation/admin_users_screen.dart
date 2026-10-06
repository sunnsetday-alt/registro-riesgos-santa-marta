import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/profile.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/application/session_controller.dart';
import '../application/admin_providers.dart';
import '../data/admin_repository.dart';

/// Gestión de usuarios: rol y activación (solo rol administrador).
class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _update(Profile p, {String? role, bool? active}) async {
    try {
      await ref.read(adminRepositoryProvider).updateUser(p.id, role: role, isActive: active);
      ref.invalidate(adminUsersProvider);
      if (mounted) showSnack(context, 'Usuario actualizado');
    } catch (e) {
      if (mounted) showSnack(context, AppError.message(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final users = ref.watch(adminUsersProvider);

    if (!session.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Usuarios')),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Solo administradores',
          message: 'La gestión de usuarios requiere el rol Administrador.',
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Buscar por nombre', prefixIcon: Icon(Icons.search_rounded), isDense: true),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 400),
                  () => ref.read(userSearchProvider.notifier).state = v);
            },
          ),
        ),
        Expanded(
          child: AsyncView<List<Profile>>(
            value: users,
            onRetry: () => ref.invalidate(adminUsersProvider),
            data: (list) => ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = list[i];
                final isMe = p.id == session.userId;
                return AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    CircleAvatar(
                      backgroundColor: p.isActive ? AppColors.ocean : AppColors.textSecondary,
                      child: Text(p.initials, style: const TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.fullName.isEmpty ? '(sin nombre)' : p.fullName,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${p.roleName}${p.isActive ? '' : ' · INACTIVO'} · desde ${Formatters.dateShort(p.createdAt)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ]),
                    ),
                    PopupMenuButton<String>(
                      enabled: !isMe,
                      tooltip: isMe ? 'No puedes modificar tu propia cuenta' : 'Acciones',
                      onSelected: (v) {
                        if (v.startsWith('role:')) _update(p, role: v.substring(5));
                        if (v == 'toggle') _update(p, active: !p.isActive);
                      },
                      itemBuilder: (_) => [
                        for (final r in Profile.roleNames.entries)
                          CheckedPopupMenuItem(value: 'role:${r.key}', checked: p.role == r.key, child: Text(r.value)),
                        const PopupMenuDivider(),
                        PopupMenuItem(value: 'toggle', child: Text(p.isActive ? 'Desactivar cuenta' : 'Activar cuenta')),
                      ],
                    ),
                  ]),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}
