import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/category.dart';
import '../../../data/models/report.dart';
import '../../../data/models/report_activity.dart';
import '../../../data/models/report_draft.dart';
import '../../../data/models/report_filter.dart';
import '../../../data/supabase_providers.dart';
import 'photo_service.dart';

/// Acceso a datos de reportes para el ciudadano (y lectura compartida con
/// el panel administrativo).
class ReportsRepository {
  ReportsRepository(this._client, this._photos);
  final SupabaseClient _client;
  final PhotoService _photos;

  // ---------------------------------------------------------------- catálogos
  Future<List<Category>> fetchCategories({bool includeInactive = false}) async {
    var q = _client.from('categories').select();
    if (!includeInactive) q = q.eq('is_active', true);
    final rows = await q.order('sort_order').order('name');
    return rows.map(Category.fromMap).toList();
  }

  Future<List<Sector>> fetchSectors() async {
    final rows = await _client.from('sectors').select('id,name').eq('is_active', true).order('name');
    return rows.map(Sector.fromMap).toList();
  }

  // ------------------------------------------------------- información pública
  /// Reportes públicos (sin datos personales) para el mapa y el inicio.
  Future<List<Report>> fetchPublicReports(ReportFilter f, {int limit = 500}) async {
    var q = _client.from('public_reports').select();
    if (f.categoryIds.isNotEmpty) q = q.inFilter('category_id', f.categoryIds.toList());
    if (f.severities.isNotEmpty) q = q.inFilter('severity', f.severities.toList());
    if (f.statuses.isNotEmpty) q = q.inFilter('status', f.statuses.toList());
    if (f.sectorId != null) q = q.eq('sector_id', f.sectorId!);
    if (f.from != null) q = q.gte('created_at', f.from!.toUtc().toIso8601String());
    if (f.to != null) q = q.lt('created_at', f.to!.toUtc().toIso8601String());
    final rows = await q.order(f.orderBy, ascending: false).limit(limit);
    return rows.map(Report.fromMap).toList();
  }

  Future<List<Report>> fetchRecentPublic({int limit = 6}) async {
    final rows = await _client
        .from('public_reports')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return rows.map(Report.fromMap).toList();
  }

  Future<List<Report>> fetchNearby(double lat, double lng, {double radiusM = 1500}) async {
    final rows = await _client.rpc('nearby_reports', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_radius_m': radiusM,
      'p_limit': 10,
    }) as List<dynamic>;
    return rows.map((r) => Report.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>> fetchPublicStats() async {
    final res = await _client.rpc('get_public_stats');
    return Map<String, dynamic>.from(res as Map);
  }

  // ------------------------------------------------------- reportes propios
  Future<List<Report>> fetchMyReports() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('reports')
        .select(Report.selectWithRelations)
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return rows.map(Report.fromMap).toList();
  }

  /// Detalle completo (RLS: el dueño o el personal).
  Future<Report?> fetchReport(String id) async {
    final row = await _client
        .from('reports')
        .select(Report.selectWithRelations)
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Report.fromMap(row);
  }

  Future<List<StatusChange>> fetchHistory(String reportId) async {
    final rows = await _client
        .from('status_history')
        .select('*, profiles(full_name)')
        .eq('report_id', reportId)
        .order('created_at');
    return rows.map(StatusChange.fromMap).toList();
  }

  Future<List<Observation>> fetchObservations(String reportId) async {
    final rows = await _client
        .from('observations')
        .select('*, profiles(full_name)')
        .eq('report_id', reportId)
        .order('created_at');
    return rows.map(Observation.fromMap).toList();
  }

  // ---------------------------------------------------------------- envío
  /// Envía un reporte: sube la foto y crea el registro. Es idempotente por
  /// `client_uuid`, así que puede reintentarse desde la cola offline sin
  /// generar duplicados. Lanza excepción de red si no hay conexión.
  Future<Report> submit(ReportDraft draft) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw AuthException('Debes iniciar sesión para reportar');

    // ¿Ya se había creado en un intento anterior?
    final existing = await _client
        .from('reports')
        .select(Report.selectWithRelations)
        .eq('client_uuid', draft.clientUuid)
        .maybeSingle();
    if (existing != null) return Report.fromMap(existing);

    String? photoUrl;
    String? photoPath;
    if (draft.localPhotoPath != null && File(draft.localPhotoPath!).existsSync()) {
      final up = await _photos.upload(
        file: File(draft.localPhotoPath!),
        userId: uid,
        clientUuid: draft.clientUuid,
      );
      photoUrl = up.url;
      photoPath = up.path;
    }

    final inserted = await _client
        .from('reports')
        .insert(draft.toInsertMap(userId: uid, photoUrl: photoUrl))
        .select('id')
        .single();
    final id = inserted['id'] as String;

    if (photoPath != null) {
      await _client.from('report_photos').insert({
        'report_id': id,
        'storage_path': photoPath,
        'public_url': photoUrl,
        'uploaded_by': uid,
      });
    }

    // Se vuelve a leer: los triggers calculan código, sector, prioridad y
    // posibles duplicados después del INSERT.
    final full = await fetchReport(id);
    await _photos.deleteLocal(draft.localPhotoPath);
    return full!;
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(supabaseProvider), ref.watch(photoServiceProvider)),
);
