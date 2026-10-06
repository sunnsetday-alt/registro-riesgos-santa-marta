import 'dart:convert';

/// Datos del formulario "Reportar problemática" antes de enviarse.
/// También es el formato que se guarda en la cola offline.
class ReportDraft {
  final String clientUuid; // idempotencia: evita duplicar al reintentar
  final String title;
  final String description;
  final int categoryId;
  final String categoryName;
  final int severity;
  final double latitude;
  final double longitude;
  final String? address;
  final String? localPhotoPath;
  final DateTime reportedAt;

  const ReportDraft({
    required this.clientUuid,
    required this.title,
    required this.description,
    required this.categoryId,
    required this.categoryName,
    required this.severity,
    required this.latitude,
    required this.longitude,
    this.address,
    this.localPhotoPath,
    required this.reportedAt,
  });

  ReportDraft copyWith({String? localPhotoPath}) => ReportDraft(
        clientUuid: clientUuid,
        title: title,
        description: description,
        categoryId: categoryId,
        categoryName: categoryName,
        severity: severity,
        latitude: latitude,
        longitude: longitude,
        address: address,
        localPhotoPath: localPhotoPath ?? this.localPhotoPath,
        reportedAt: reportedAt,
      );

  /// Fila para insertar en `reports` (el servidor completa el resto).
  Map<String, dynamic> toInsertMap({required String userId, String? photoUrl}) => {
        'user_id': userId,
        'client_uuid': clientUuid,
        'title': title.trim(),
        'description': description.trim(),
        'category_id': categoryId,
        'severity': severity,
        'latitude': latitude,
        'longitude': longitude,
        'address': (address == null || address!.trim().isEmpty) ? null : address!.trim(),
        'photo_url': photoUrl,
        'reported_at': reportedAt.toUtc().toIso8601String(),
      };

  String toJson() => jsonEncode({
        'clientUuid': clientUuid,
        'title': title,
        'description': description,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'severity': severity,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'localPhotoPath': localPhotoPath,
        'reportedAt': reportedAt.toIso8601String(),
      });

  factory ReportDraft.fromJson(String source) {
    final m = jsonDecode(source) as Map<String, dynamic>;
    return ReportDraft(
      clientUuid: m['clientUuid'] as String,
      title: m['title'] as String,
      description: m['description'] as String,
      categoryId: m['categoryId'] as int,
      categoryName: m['categoryName'] as String,
      severity: m['severity'] as int,
      latitude: (m['latitude'] as num).toDouble(),
      longitude: (m['longitude'] as num).toDouble(),
      address: m['address'] as String?,
      localPhotoPath: m['localPhotoPath'] as String?,
      reportedAt: DateTime.parse(m['reportedAt'] as String),
    );
  }
}
