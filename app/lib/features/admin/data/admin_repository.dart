import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/category.dart';
import '../../../data/models/profile.dart';
import '../../../data/models/report.dart';
import '../../../data/models/report_activity.dart';
import '../../../data/models/report_filter.dart';
import '../../../data/supabase_providers.dart';

/// Operaciones del panel administrativo. Todas están protegidas en el
/// servidor por RLS y por las funciones SECURITY DEFINER que validan
/// `is_staff()` / `is_admin()`; la app solo oculta lo que no corresponde.
class AdminRepository {
  AdminRepository(this._client);
  final SupabaseClient _client;

  // ------------------------------------------------------------ reportes
  Future<List<Report>> fetchReports(ReportFilter f, {int limit = 300}) async {
    var q = _client.from('reports').select(Report.selectWithRelations);
    if (f.categoryIds.isNotEmpty) q = q.inFilter('category_id', f.categoryIds.toList());
    if (f.severities.isNotEmpty) q = q.inFilter('severity', f.severities.toList());
    if (f.statuses.isNotEmpty) q = q.inFilter('status', f.statuses.toList());
    if (f.sectorId != null) q = q.eq('sector_id', f.sectorId!);
    if (f.from != null) q = q.gte('created_at', f.from!.toUtc().toIso8601String());
    if (f.to != null) q = q.lt('created_at', f.to!.toUtc().toIso8601String());
    if (f.onlyPossibleDuplicates) q = q.eq('possible_duplicate', true);
    final s = f.search?.trim();
    if (s != null && s.isNotEmpty) {
      final safe = s.replaceAll(RegExp(r'[,()%*]'), ' ');
      q = q.or('code.ilike.%$safe%,title.ilike.%$safe%,description.ilike.%$safe%,address.ilike.%$safe%');
    }
    final rows = await q.order(f.orderBy, ascending: false).limit(limit);
    return rows.map(Report.fromMap).toList();
  }

  Future<void> changeStatus(String reportId, String status, String? note) =>
      _client.rpc('change_report_status', params: {
        'p_report_id': reportId,
        'p_status': status,
        'p_note': note,
      });

  Future<void> addObservation(String reportId, String body, {bool isPublic = true}) =>
      _client.from('observations').insert({
        'report_id': reportId,
        'body': body.trim(),
        'is_public': isPublic,
      });

  /// "Modificar información" del reporte.
  Future<void> updateReport(String id, Map<String, dynamic> changes) =>
      _client.from('reports').update(changes).eq('id', id);

  Future<List<DuplicateCandidate>> fetchDuplicates(String reportId) async {
    final rows = await _client
        .from('duplicate_candidates')
        .select('*, candidate:reports!duplicate_candidates_candidate_id_fkey(code,title)')
        .eq('report_id', reportId)
        .order('score', ascending: false);
    return rows.map(DuplicateCandidate.fromMap).toList();
  }

  Future<void> resolveDuplicate(int candidateId, String decision) =>
      _client.rpc('resolve_duplicate', params: {'p_candidate_id': candidateId, 'p_decision': decision});

  Future<int> recalculatePriorities() async =>
      ((await _client.rpc('recalculate_all_priorities')) as num).toInt();

  Future<Map<String, dynamic>> dashboardStats({DateTime? from, DateTime? to}) async {
    final res = await _client.rpc('get_dashboard_stats', params: {
      'p_from': from?.toUtc().toIso8601String(),
      'p_to': to?.toUtc().toIso8601String(),
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Datos del ciudadano que reportó (solo personal autorizado).
  Future<Profile?> fetchReporter(String userId) async {
    final row = await _client.from('profiles').select().eq('id', userId).maybeSingle();
    return row == null ? null : Profile.fromMap(row);
  }

  // ------------------------------------------------------------ usuarios
  Future<List<Profile>> fetchUsers({String? search}) async {
    var q = _client.from('profiles').select();
    final s = search?.trim();
    if (s != null && s.isNotEmpty) {
      q = q.ilike('full_name', '%${s.replaceAll(RegExp(r'[%*]'), '')}%');
    }
    final rows = await q.order('created_at', ascending: false).limit(200);
    return rows.map((r) => Profile.fromMap(r)).toList();
  }

  Future<void> updateUser(String id, {String? role, bool? isActive}) => _client.from('profiles').update({
        if (role != null) 'role': role,
        if (isActive != null) 'is_active': isActive,
      }).eq('id', id);

  // ------------------------------------------------------------ categorías
  Future<void> saveCategory(Category c, {int? id}) async {
    if (id == null) {
      await _client.from('categories').insert(c.toUpsertMap());
    } else {
      await _client.from('categories').update(c.toUpsertMap()).eq('id', id);
    }
  }
}

final adminRepositoryProvider =
    Provider<AdminRepository>((ref) => AdminRepository(ref.watch(supabaseProvider)));
