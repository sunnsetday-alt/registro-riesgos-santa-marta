import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/category.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/report.dart';
import '../../../data/models/report_activity.dart';
import '../../../data/models/report_filter.dart';
import '../../reports/data/reports_repository.dart';
import '../data/admin_repository.dart';

/// Filtro del listado administrativo (por defecto: ordenado por prioridad).
final adminReportFilterProvider =
    StateProvider<ReportFilter>((ref) => const ReportFilter(orderBy: 'priority_score'));

final adminReportsProvider = FutureProvider.autoDispose<List<Report>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchReports(ref.watch(adminReportFilterProvider));
});

/// Filtro y datos del mapa completo del administrador.
final adminMapFilterProvider = StateProvider<ReportFilter>((ref) => const ReportFilter());

final adminMapReportsProvider = FutureProvider.autoDispose<List<Report>>((ref) {
  return ref.watch(adminRepositoryProvider).fetchReports(ref.watch(adminMapFilterProvider), limit: 1000);
});

/// Rango del dashboard (null = últimos 30 días para la serie, todo para totales).
final dashboardRangeProvider = StateProvider<int?>((ref) => 30);

final dashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  final days = ref.watch(dashboardRangeProvider);
  final from = days == null ? null : DateTime.now().subtract(Duration(days: days - 1));
  return ref.watch(adminRepositoryProvider).dashboardStats(
        from: from == null ? null : DateTime(from.year, from.month, from.day),
      );
});

final duplicatesProvider = FutureProvider.autoDispose.family<List<DuplicateCandidate>, String>(
  (ref, id) => ref.watch(adminRepositoryProvider).fetchDuplicates(id),
);

final reporterProvider = FutureProvider.autoDispose.family<Profile?, String>(
  (ref, userId) => ref.watch(adminRepositoryProvider).fetchReporter(userId),
);

final userSearchProvider = StateProvider<String>((ref) => '');

final adminUsersProvider = FutureProvider.autoDispose<List<Profile>>(
  (ref) => ref.watch(adminRepositoryProvider).fetchUsers(search: ref.watch(userSearchProvider)),
);

final adminCategoriesProvider = FutureProvider.autoDispose<List<Category>>(
  (ref) => ref.watch(reportsRepositoryProvider).fetchCategories(includeInactive: true),
);
