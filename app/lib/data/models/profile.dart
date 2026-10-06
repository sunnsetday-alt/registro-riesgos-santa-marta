class Profile {
  final String id;
  final String fullName;
  final String? phone;
  final String role;
  final bool isActive;
  final String? entityId;
  final DateTime createdAt;
  final String? email; // solo disponible para el usuario actual

  const Profile({
    required this.id,
    required this.fullName,
    this.phone,
    required this.role,
    required this.isActive,
    this.entityId,
    required this.createdAt,
    this.email,
  });

  static const staffRoles = {'admin', 'official', 'entity_admin'};
  static const roleNames = {
    'citizen': 'Ciudadano',
    'official': 'Funcionario',
    'entity_admin': 'Administrador de entidad',
    'admin': 'Administrador',
  };

  bool get isStaff => isActive && staffRoles.contains(role);
  bool get isAdmin => isActive && role == 'admin';
  String get roleName => roleNames[role] ?? role;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  factory Profile.fromMap(Map<String, dynamic> m, {String? email}) => Profile(
        id: m['id'] as String,
        fullName: (m['full_name'] as String?) ?? '',
        phone: m['phone'] as String?,
        role: (m['role'] as String?) ?? 'citizen',
        isActive: (m['is_active'] as bool?) ?? true,
        entityId: m['entity_id'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        email: email,
      );
}
