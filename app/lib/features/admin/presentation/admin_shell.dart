import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Panel administrativo separado de la experiencia ciudadana.
/// En pantallas anchas (tablet / web) usa NavigationRail; en móvil, barra
/// inferior. Se accede desde Perfil si el usuario tiene rol de personal.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _items = [
    (icon: Icons.dashboard_rounded, label: 'Dashboard'),
    (icon: Icons.assignment_rounded, label: 'Reportes'),
    (icon: Icons.map_rounded, label: 'Mapa'),
    (icon: Icons.group_rounded, label: 'Usuarios'),
    (icon: Icons.category_rounded, label: 'Categorías'),
  ];

  void _go(int i) => navigationShell.goBranch(i, initialLocation: i == navigationShell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final exit = IconButton(
      tooltip: 'Volver a la app ciudadana',
      icon: const Icon(Icons.logout_rounded),
      onPressed: () => context.go('/profile'),
    );

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _go,
            labelType: NavigationRailLabelType.all,
            backgroundColor: AppColors.deepSea,
            indicatorColor: AppColors.turquoise.withAlpha(90),
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 32),
            ),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconTheme(data: const IconThemeData(color: Colors.white), child: exit),
                ),
              ),
            ),
            destinations: [
              for (final it in _items) NavigationRailDestination(icon: Icon(it.icon), label: Text(it.label)),
            ],
          ),
          Expanded(child: navigationShell),
        ]),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _go,
        destinations: [
          for (final it in _items) NavigationDestination(icon: Icon(it.icon), label: it.label),
        ],
      ),
    );
  }
}
