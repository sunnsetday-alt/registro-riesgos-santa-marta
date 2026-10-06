/// Reporte ciudadano.
///
/// Se construye tanto desde la vista pública `public_reports` (columnas
/// planas como `category_name`) como desde la tabla `reports` con relaciones
/// embebidas (`categories(...)`, `report_statuses(...)`, `sectors(...)`).
class Report {
  final String id;
  final String code;
  final String? userId; // null en la vista pública (privacidad)
  final String title;
  final String description;
  final int categoryId;
  final String categoryCode;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final int severity;
  final double priorityScore;
  final String priorityLevel;
  final String status;
  final double latitude;
  final double longitude;
  final String? address;
  final int? sectorId;
  final String? sectorName;
  final String? photoUrl;
  final bool possibleDuplicate;
  final String? duplicateOf;
  final bool isTestData;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? reportedAt;

  const Report({
    required this.id,
    required this.code,
    this.userId,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.severity,
    required this.priorityScore,
    required this.priorityLevel,
    required this.status,
    required this.latitude,
    required this.longitude,
    this.address,
    this.sectorId,
    this.sectorName,
    this.photoUrl,
    this.possibleDuplicate = false,
    this.duplicateOf,
    this.isTestData = false,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.reportedAt,
  });

  /// Columnas a pedir a la tabla `reports` para obtener relaciones.
  static const selectWithRelations =
      '*, categories(code,name,color,icon), sectors(name)';

  factory Report.fromMap(Map<String, dynamic> m) {
    final cat = m['categories'] as Map<String, dynamic>?;
    final sector = m['sectors'] as Map<String, dynamic>?;
    DateTime? parse(dynamic v) => v == null ? null : DateTime.parse(v as String);

    return Report(
      id: m['id'] as String,
      code: m['code'] as String,
      userId: m['user_id'] as String?,
      title: m['title'] as String,
      description: m['description'] as String,
      categoryId: (m['category_id'] as num).toInt(),
      categoryCode: (m['category_code'] ?? cat?['code'] ?? 'otros') as String,
      categoryName: (m['category_name'] ?? cat?['name'] ?? 'Otros') as String,
      categoryColor: (m['category_color'] ?? cat?['color'] ?? '#64748B') as String,
      categoryIcon: (m['category_icon'] ?? cat?['icon'] ?? 'report') as String,
      severity: (m['severity'] as num).toInt(),
      priorityScore: (m['priority_score'] as num?)?.toDouble() ?? 0,
      priorityLevel: (m['priority_level'] as String?) ?? 'baja',
      status: m['status'] as String,
      latitude: (m['latitude'] as num).toDouble(),
      longitude: (m['longitude'] as num).toDouble(),
      address: m['address'] as String?,
      sectorId: (m['sector_id'] as num?)?.toInt(),
      sectorName: (m['sector_name'] ?? sector?['name']) as String?,
      photoUrl: m['photo_url'] as String?,
      possibleDuplicate: (m['possible_duplicate'] as bool?) ?? false,
      duplicateOf: m['duplicate_of'] as String?,
      isTestData: (m['is_test_data'] as bool?) ?? false,
      adminNotes: m['admin_notes'] as String?,
      createdAt: parse(m['created_at'])!,
      updatedAt: parse(m['updated_at']) ?? parse(m['created_at'])!,
      resolvedAt: parse(m['resolved_at']),
      reportedAt: parse(m['reported_at']),
    );
  }
}
