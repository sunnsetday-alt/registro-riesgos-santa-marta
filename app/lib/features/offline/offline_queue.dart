import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../data/models/report_draft.dart';

/// Cola local (SQLite) de reportes pendientes de envío.
///
/// Cada fila guarda el borrador completo (JSON) y la ruta de su foto en el
/// almacenamiento privado de la app. Se identifica por `client_uuid`, el
/// mismo valor que usa el servidor para evitar duplicados al reintentar.
class OfflineQueue {
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'rsm_offline.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE pending_reports (
          client_uuid TEXT PRIMARY KEY,
          payload     TEXT NOT NULL,
          attempts    INTEGER NOT NULL DEFAULT 0,
          last_error  TEXT,
          created_at  TEXT NOT NULL
        )
      '''),
    );
    return _db!;
  }

  Future<void> enqueue(ReportDraft draft) async {
    final db = await _database;
    await db.insert(
      'pending_reports',
      {
        'client_uuid': draft.clientUuid,
        'payload': draft.toJson(),
        'attempts': 0,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReportDraft>> pending() async {
    final db = await _database;
    final rows = await db.query('pending_reports', orderBy: 'created_at ASC');
    return rows.map((r) => ReportDraft.fromJson(r['payload'] as String)).toList();
  }

  Future<int> count() async {
    final db = await _database;
    return Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM pending_reports')) ?? 0;
  }

  Future<void> remove(String clientUuid) async {
    final db = await _database;
    await db.delete('pending_reports', where: 'client_uuid = ?', whereArgs: [clientUuid]);
  }

  Future<void> markFailed(String clientUuid, String error) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE pending_reports SET attempts = attempts + 1, last_error = ? WHERE client_uuid = ?',
      [error, clientUuid],
    );
  }
}

final offlineQueueProvider = Provider<OfflineQueue>((ref) => OfflineQueue());
