import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/category.dart';
import '../../../data/models/report.dart';
import '../../../data/models/report_activity.dart';
import '../../../data/models/report_filter.dart';
import '../data/reports_repository.dart';

final categoriesProvider = FutureProvider<List<Category>>(
  (ref) => ref.watch(reportsRepositoryProvider).fetchCategories(),
);

final sectorsProvider = FutureProvider<List<Sector>>(
  (ref) => ref.watch(reportsRepositoryProvider).fetchSectors(),
);

final myReportsProvider = FutureProvider.autoDispose<List<Report>>(
  (ref) => ref.watch(reportsRepositoryProvider).fetchMyReports(),
);

final recentReportsProvider = FutureProvider.autoDispose<List<Report>>(
  (ref) => ref.watch(reportsRepositoryProvider).fetchRecentPublic(),
);

final publicStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.watch(reportsRepositoryProvider).fetchPublicStats(),
);

/// Filtro activo del mapa público.
final mapFilterProvider = StateProvider<ReportFilter>((ref) => const ReportFilter());

final mapReportsProvider = FutureProvider.autoDispose<List<Report>>((ref) {
  final filter = ref.watch(mapFilterProvider);
  return ref.watch(reportsRepositoryProvider).fetchPublicReports(filter);
});

final reportDetailProvider = FutureProvider.autoDispose.family<Report?, String>(
  (ref, id) => ref.watch(reportsRepositoryProvider).fetchReport(id),
);

final reportHistoryProvider = FutureProvider.autoDispose.family<List<StatusChange>, String>(
  (ref, id) => ref.watch(reportsRepositoryProvider).fetchHistory(id),
);

final reportObservationsProvider = FutureProvider.autoDispose.family<List<Observation>, String>(
  (ref, id) => ref.watch(reportsRepositoryProvider).fetchObservations(id),
);
