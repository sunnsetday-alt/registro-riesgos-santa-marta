import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/report_draft.dart';
import '../../features/admin/presentation/admin_categories_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_report_detail_screen.dart';
import '../../features/admin/presentation/admin_reports_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/auth/application/session_controller.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/map/risk_map_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/edit_profile_screen.dart';
import '../../features/profile/legal_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reports/presentation/confirm_report_screen.dart';
import '../../features/reports/presentation/create_report_screen.dart';
import '../../features/reports/presentation/my_reports_screen.dart';
import '../../features/reports/presentation/report_detail_screen.dart';
import '../../features/reports/presentation/report_success_screen.dart';
import '../../features/shell/main_shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Rutas accesibles sin sesión.
const _publicRoutes = {'/login', '/register', '/forgot-password'};

final routerProvider = Provider<GoRouter>((ref) {
  // `read` (no `watch`): el router se crea una sola vez y se re-evalúa
  // mediante refreshListenable cuando cambia la sesión.
  final session = ref.read(sessionProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    refreshListenable: session,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!session.initialized) return loc == '/splash' ? null : '/splash';

      final isPublic = _publicRoutes.contains(loc) || loc.startsWith('/legal');
      if (!session.isLoggedIn) return isPublic ? null : '/login';

      // Con sesión: fuera de login/registro (salvo durante la recuperación).
      if (loc == '/splash' || ((_publicRoutes.contains(loc)) && !session.recovering)) return '/home';

      // Autorización por rol (la base de datos aplica la misma regla vía RLS).
      if (loc.startsWith('/admin') && session.profile != null && !session.isStaff) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/legal/:doc', builder: (_, s) => LegalScreen(doc: s.pathParameters['doc']!)),

      // ---------------------------------------------------- app ciudadana
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/map', builder: (_, __) => const RiskMapScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/my-reports',
              builder: (_, __) => const MyReportsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, s) => ReportDetailScreen(reportId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, __) => const ProfileScreen(),
              routes: [
                GoRoute(path: 'edit', parentNavigatorKey: _rootKey, builder: (_, __) => const EditProfileScreen()),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),

      // ---------------------------------------------------- flujo de reporte
      GoRoute(path: '/report/new', builder: (_, __) => const CreateReportScreen()),
      GoRoute(
        path: '/report/confirm',
        redirect: (_, s) => s.extra is ReportDraft ? null : '/report/new',
        builder: (_, s) => ConfirmReportScreen(draft: s.extra! as ReportDraft),
      ),
      GoRoute(
        path: '/report/success',
        builder: (_, s) {
          final m = (s.extra as Map<String, dynamic>?) ?? const {'queued': true};
          return ReportSuccessScreen(
            queued: m['queued'] as bool? ?? false,
            code: m['code'] as String?,
            reportId: m['id'] as String?,
          );
        },
      ),

      // ---------------------------------------------------- panel administrativo
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AdminShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/admin/reports',
              builder: (_, __) => const AdminReportsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: _rootKey,
                  builder: (_, s) => AdminReportDetailScreen(reportId: s.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/map', builder: (_, __) => const RiskMapScreen(admin: true)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/users', builder: (_, __) => const AdminUsersScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/admin/categories', builder: (_, __) => const AdminCategoriesScreen()),
          ]),
        ],
      ),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}
