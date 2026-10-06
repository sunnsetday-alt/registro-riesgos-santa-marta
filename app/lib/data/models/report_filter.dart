/// Filtros del mapa y del listado administrativo.
class ReportFilter {
  final Set<int> categoryIds;
  final Set<int> severities;
  final Set<String> statuses;
  final DateTime? from;
  final DateTime? to;
  final int? sectorId;
  final String? search;
  final bool onlyPossibleDuplicates;
  final String orderBy; // 'created_at' | 'priority_score'

  const ReportFilter({
    this.categoryIds = const {},
    this.severities = const {},
    this.statuses = const {},
    this.from,
    this.to,
    this.sectorId,
    this.search,
    this.onlyPossibleDuplicates = false,
    this.orderBy = 'created_at',
  });

  bool get isEmpty =>
      categoryIds.isEmpty &&
      severities.isEmpty &&
      statuses.isEmpty &&
      from == null &&
      to == null &&
      sectorId == null &&
      (search == null || search!.isEmpty) &&
      !onlyPossibleDuplicates;

  int get activeCount =>
      (categoryIds.isNotEmpty ? 1 : 0) +
      (severities.isNotEmpty ? 1 : 0) +
      (statuses.isNotEmpty ? 1 : 0) +
      (from != null || to != null ? 1 : 0) +
      (sectorId != null ? 1 : 0) +
      (onlyPossibleDuplicates ? 1 : 0);

  ReportFilter copyWith({
    Set<int>? categoryIds,
    Set<int>? severities,
    Set<String>? statuses,
    DateTime? from,
    DateTime? to,
    int? sectorId,
    String? search,
    bool? onlyPossibleDuplicates,
    String? orderBy,
    bool clearDates = false,
    bool clearSector = false,
  }) =>
      ReportFilter(
        categoryIds: categoryIds ?? this.categoryIds,
        severities: severities ?? this.severities,
        statuses: statuses ?? this.statuses,
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
        sectorId: clearSector ? null : (sectorId ?? this.sectorId),
        search: search ?? this.search,
        onlyPossibleDuplicates: onlyPossibleDuplicates ?? this.onlyPossibleDuplicates,
        orderBy: orderBy ?? this.orderBy,
      );
}
