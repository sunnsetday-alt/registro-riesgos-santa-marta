/// Registro del historial de estados.
class StatusChange {
  final int id;
  final String? fromStatus;
  final String toStatus;
  final String? note;
  final String? changedByName; // solo visible para personal
  final DateTime createdAt;

  const StatusChange({
    required this.id,
    this.fromStatus,
    required this.toStatus,
    this.note,
    this.changedByName,
    required this.createdAt,
  });

  factory StatusChange.fromMap(Map<String, dynamic> m) => StatusChange(
        id: (m['id'] as num).toInt(),
        fromStatus: m['from_status'] as String?,
        toStatus: m['to_status'] as String,
        note: m['note'] as String?,
        changedByName: (m['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Observación agregada por el personal.
class Observation {
  final String id;
  final String body;
  final bool isPublic;
  final String? authorName;
  final DateTime createdAt;

  const Observation({
    required this.id,
    required this.body,
    required this.isPublic,
    this.authorName,
    required this.createdAt,
  });

  factory Observation.fromMap(Map<String, dynamic> m) => Observation(
        id: m['id'] as String,
        body: m['body'] as String,
        isPublic: (m['is_public'] as bool?) ?? true,
        authorName: (m['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Posible duplicado detectado por el servidor.
class DuplicateCandidate {
  final int id;
  final String reportId;
  final String candidateId;
  final String candidateCode;
  final String candidateTitle;
  final double distanceM;
  final double textSimilarity;
  final double score;
  final String decision;

  const DuplicateCandidate({
    required this.id,
    required this.reportId,
    required this.candidateId,
    required this.candidateCode,
    required this.candidateTitle,
    required this.distanceM,
    required this.textSimilarity,
    required this.score,
    required this.decision,
  });

  factory DuplicateCandidate.fromMap(Map<String, dynamic> m) {
    final c = m['candidate'] as Map<String, dynamic>?;
    return DuplicateCandidate(
      id: (m['id'] as num).toInt(),
      reportId: m['report_id'] as String,
      candidateId: m['candidate_id'] as String,
      candidateCode: (c?['code'] as String?) ?? '',
      candidateTitle: (c?['title'] as String?) ?? '',
      distanceM: (m['distance_m'] as num).toDouble(),
      textSimilarity: (m['text_similarity'] as num).toDouble(),
      score: (m['score'] as num).toDouble(),
      decision: m['decision'] as String,
    );
  }
}

/// Notificación in-app.
class AppNotification {
  final String id;
  final String? reportId;
  final String type;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    this.reportId,
    required this.type,
    required this.title,
    required this.body,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
        id: m['id'] as String,
        reportId: m['report_id'] as String?,
        type: m['type'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        readAt: m['read_at'] == null ? null : DateTime.parse(m['read_at'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Sector de la ciudad.
class Sector {
  final int id;
  final String name;
  const Sector(this.id, this.name);
  factory Sector.fromMap(Map<String, dynamic> m) =>
      Sector((m['id'] as num).toInt(), m['name'] as String);
}
