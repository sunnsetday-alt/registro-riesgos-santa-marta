import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../notifications/notifications_repository.dart';
import '../offline/sync_service.dart';

/// Navegación principal: INICIO · MAPA · [REPORTAR] · MIS REPORTES · PERFIL.
/// El botón REPORTAR es central, elevado y con color de acento.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  @override
  void initState() {
    super.initState();
    // Al entrar con sesión: enviar reportes pendientes de la cola offline.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(syncServiceProvider).syncPending());
  }

  void _go(int branch) => widget.navigationShell.goBranch(
        branch,
        initialLocation: branch == widget.navigationShell.currentIndex,
      );

  @override
  Widget build(BuildContext context) {
    // Mantiene activa la suscripción Realtime de notificaciones.
    ref.watch(notificationListenerProvider);
    final index = widget.navigationShell.currentIndex;

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: AppColors.deepSea.withAlpha(30), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Row(children: [
            _NavItem(icon: Icons.home_rounded, label: 'Inicio', selected: index == 0, onTap: () => _go(0)),
            _NavItem(icon: Icons.map_rounded, label: 'Mapa', selected: index == 1, onTap: () => _go(1)),
            Expanded(
              child: Center(
                child: _ReportButton(onTap: () => context.push('/report/new')),
              ),
            ),
            _NavItem(icon: Icons.assignment_rounded, label: 'Mis reportes', selected: index == 2, onTap: () => _go(2)),
            _NavItem(icon: Icons.person_rounded, label: 'Perfil', selected: index == 3, onTap: () => _go(3)),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.ocean : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.aqua.withAlpha(90) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: TextStyle(fontSize: 10.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color)),
        ]),
      ),
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Reportar problemática',
      child: GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.reportGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppColors.coral.withAlpha(120), blurRadius: 14, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 2),
          const Text('REPORTAR',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.coral, letterSpacing: 0.4)),
        ]),
      ),
    );
  }
}
