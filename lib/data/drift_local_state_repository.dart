import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database/drift_orbit_database.dart';
import 'database/orbit_database.dart';
import 'orbit_corrupt_data.dart';
import 'orbit_local_state_codec.dart';
import 'orbit_local_state_repository.dart';

/// Production local-state repository backed by the real SQLite database
/// (Drift) from STEP 1.
///
/// Storage model:
/// 1. `app_state_snapshots` (single row id = 1) keeps the FULL JSON snapshot
///    of the current `Map<String, Object?>` state — every field that is not
///    normalized yet (drafts, mail state, accounts, brain history and event
///    decorations like color/time/attendees) survives loss-free here.
/// 2. The `tasks` and `events` tables hold the relational projection used by
///    OrbitDataEngine. On [load] the snapshot's `tasks`/`events` entries are
///    refreshed from those tables (merge by id), so relational data is
///    authoritative for the columns it owns while legacy-only decorations
///    stay intact.
///
/// The legacy SharedPreferences JSON is migrated once on first load and is
/// never deleted or overwritten afterwards — it remains the backup copy of
/// this step.
final class DriftLocalStateRepository
    implements OrbitLocalStateRepository, OrbitCorruptDataRecovery {
  DriftLocalStateRepository({
    DriftOrbitDatabase? database,
    SharedPreferencesLocalStateRepository? legacyRepository,
    this.defaultWorkspaceId = 'workspace-work',
  }) : _injectedDb = database,
       _legacy = legacyRepository;

  /// Identity of the single snapshot row.
  static const int snapshotRowId = 1;

  /// Fallback ARGB color for relational events that have no snapshot entry
  /// (production never creates those; OrbitDataEngine writes alone would).
  static const int _fallbackEventColor = 0xFF4285F4;

  final DriftOrbitDatabase? _injectedDb;
  final SharedPreferencesLocalStateRepository? _legacy;
  final String defaultWorkspaceId;
  DriftOrbitDatabase? _db;

  /// Test hook: throws after the snapshot upsert but before the relational
  /// writes, proving that the whole [save] transaction rolls back.
  bool failNextSaveMidTransaction = false;

  bool _migrationAttempted = false;

  Future<DriftOrbitDatabase> get _store async {
    final existing = _db ?? _injectedDb;
    if (existing != null) {
      await existing.open();
      return existing;
    }
    final created = DriftOrbitDatabase(file: await _defaultDatabaseFile());
    _db = created;
    await created.open();
    return created;
  }

  /// Resolves the production SQLite file location (application support
  /// directory; sqlite3_flutter_libs provides the native engine on Android).
  static Future<File> _defaultDatabaseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}orbit_local_state.sqlite',
    );
  }

  @override
  Future<Map<String, Object?>> load() async {
    final db = await _store;
    var snapshot = await _readSnapshotPayload(db);
    if (snapshot == null) {
      // One-time migration from the legacy SharedPreferences JSON. The old
      // storage is never cleared here — it stays as the backup of this step.
      await _migrateLegacyIfNeeded(db);
      snapshot = await _readSnapshotPayload(db);
      if (snapshot == null) {
        // Nothing legacy and nothing snapshot: genuinely empty state.
        return <String, Object?>{};
      }
    }
    return _composeState(db, snapshot);
  }

  Future<String?> _readSnapshotPayload(DriftOrbitDatabase db) async {
    final rows = await db.query(
      snapshotTableName,
      where: 'id = ?',
      whereArgs: [snapshotRowId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final payload = rows.single['payload_json'];
    return payload is String ? payload : null;
  }

  Future<void> _migrateLegacyIfNeeded(DriftOrbitDatabase db) async {
    if (_migrationAttempted) {
      return;
    }
    _migrationAttempted = true;
    final legacyState =
        await (_legacy?.load() ??
            SharedPreferencesLocalStateRepository().load());
    await save(legacyState);
  }

  /// Builds the returned state: full snapshot payload with `tasks`/`events`
  /// refreshed from the relational tables.
  Future<Map<String, Object?>> _composeState(
    DriftOrbitDatabase db,
    String payloadJson,
  ) async {
    final decoded = jsonDecode(payloadJson);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('ORBIT state snapshot must be a JSON object');
    }
    OrbitLocalStateCodec.validate(decoded);

    final relationalTasks = await db.query(
      OrbitDatabaseSchema.tableTasks,
      where: 'workspace_id = ?',
      whereArgs: [defaultWorkspaceId],
    );
    final relationalEvents = await db.query(
      OrbitDatabaseSchema.tableEvents,
      where: 'workspace_id = ?',
      whereArgs: [defaultWorkspaceId],
    );

    // A genuinely empty state (empty legacy JSON migration) stays empty:
    // no synthetic tasks/events keys are injected.
    if (decoded.isEmpty && relationalTasks.isEmpty && relationalEvents.isEmpty) {
      return decoded;
    }
    decoded['tasks'] = _mergeTasks(decoded['tasks'], relationalTasks);
    decoded['events'] = _mergeEvents(decoded['events'], relationalEvents);
    return decoded;
  }

  static List<Object?> _mergeTasks(
    Object? snapshotTasks,
    List<Map<String, Object?>> rows,
  ) {
    final byId = <String, Map<String, Object?>>{
      for (final row in rows)
        if (row['id'] is String) row['id']! as String: row,
    };
    final merged = <Object?>[];
    final seen = <String>{};
    if (snapshotTasks is List<Object?>) {
      for (final item in snapshotTasks) {
        if (item is! Map<String, Object?>) continue;
        final id = item['id'];
        final row = id is String ? byId[id] : null;
        if (row != null) {
          merged.add(_mergeTask(item, row));
          seen.add(id as String);
        } else {
          merged.add(item);
        }
      }
    }
    // Relational rows unknown to the snapshot surface in legacy task shape
    // so OrbitDataEngine-driven writes stay visible after reload.
    for (final entry in byId.entries) {
      if (!seen.contains(entry.key)) {
        merged.add(_taskRowToLegacy(entry.value));
      }
    }
    return merged;
  }

  static Map<String, Object?> _mergeTask(
    Map<String, Object?> snapshotEntry,
    Map<String, Object?> row,
  ) {
    final merged = <String, Object?>{...snapshotEntry};
    if (row['id'] is String) merged['id'] = row['id'];
    if (row['title'] is String) merged['title'] = row['title'];
    final project = row['project'];
    if (project is String || project == null) merged['project'] = project;
    final due = row['due_date'];
    if (due is String || due == null) merged['due'] = due;
    if (row['is_done'] is num) {
      merged['done'] = (row['is_done'] as num).toInt() == 1;
    }
    if (row['priority'] is num) {
      merged['priority'] = (row['priority'] as num).toInt();
    }
    return merged;
  }

  static Map<String, Object?> _taskRowToLegacy(
    Map<String, Object?> row,
  ) => <String, Object?>{
    'id': row['id'],
    'title': row['title'],
    'project': row['project'],
    'due': row['due_date'],
    'done': row['is_done'] is num && (row['is_done'] as num).toInt() == 1,
    'priority': row['priority'] is num ? (row['priority'] as num).toInt() : 0,
  };

  static List<Object?> _mergeEvents(
    Object? snapshotEvents,
    List<Map<String, Object?>> rows,
  ) {
    final byId = <String, Map<String, Object?>>{
      for (final row in rows)
        if (row['id'] is String) row['id']! as String: row,
    };
    final merged = <Object?>[];
    final seen = <String>{};
    if (snapshotEvents is List<Object?>) {
      for (final item in snapshotEvents) {
        if (item is! Map<String, Object?>) continue;
        final id = item['id'];
        final row = id is String ? byId[id] : null;
        if (row != null) {
          merged.add(_mergeEvent(item, row));
          seen.add(id as String);
        } else {
          merged.add(item);
        }
      }
    }
    for (final entry in byId.entries) {
      if (!seen.contains(entry.key)) {
        merged.add(_eventRowToLegacy(entry.value));
      }
    }
    return merged;
  }

  static Map<String, Object?> _mergeEvent(
    Map<String, Object?> snapshotEntry,
    Map<String, Object?> row,
  ) {
    final merged = <String, Object?>{...snapshotEntry};
    if (row['title'] is String) merged['title'] = row['title'];
    final location = row['location'];
    if (location == null || location is String) merged['location'] = location;
    final description = row['description'];
    if (description == null || description is String) {
      merged['description'] = description;
    }
    final start = row['start_time'];
    if (start is num && start.toInt() > 0) {
      final startDt = DateTime.fromMillisecondsSinceEpoch(start.toInt());
      merged['date'] = startDt.toIso8601String();
      merged['time'] =
          '${startDt.hour.toString().padLeft(2, '0')}:'
          '${startDt.minute.toString().padLeft(2, '0')}';
      final end = row['end_time'];
      if (end is num && end.toInt() > start.toInt()) {
        final endDt = DateTime.fromMillisecondsSinceEpoch(end.toInt());
        merged['endTime'] =
            '${endDt.hour.toString().padLeft(2, '0')}:'
            '${endDt.minute.toString().padLeft(2, '0')}';
      }
    }
    return merged;
  }

  static Map<String, Object?> _eventRowToLegacy(Map<String, Object?> row) {
    final start = row['start_time'];
    final end = row['end_time'];
    final startMs = start is num ? start.toInt() : 0;
    final endMs = end is num ? end.toInt() : 0;
    final date = startMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(startMs)
        : null;
    String? endTime;
    if (date != null && endMs > startMs) {
      final endDt = DateTime.fromMillisecondsSinceEpoch(endMs);
      endTime =
          '${endDt.hour.toString().padLeft(2, '0')}:'
          '${endDt.minute.toString().padLeft(2, '0')}';
    }
    final location = row['location'];
    final description = row['description'];
    return <String, Object?>{
      'id': row['id'],
      'time': date != null
          ? '${date.hour.toString().padLeft(2, '0')}:'
                '${date.minute.toString().padLeft(2, '0')}'
          : '00:00',
      'title': row['title'],
      'meta': '',
      'color': _fallbackEventColor,
      'date': ?date?.toIso8601String(),
      'endTime': ?endTime,
      if (description is String) 'description': description,
      if (location is String) 'location': location,
    };
  }

  @override
  Future<void> save(Map<String, Object?> state) async {
    final db = await _store;
    final taskEntries = _taskEntriesOf(state);
    final eventEntries = _eventEntriesOf(state);
    final payload = jsonEncode(state);
    final now = DateTime.now().millisecondsSinceEpoch;
    final failMidTransaction = failNextSaveMidTransaction;
    failNextSaveMidTransaction = false;

    await db.transaction((_) async {
      // 1. Full JSON snapshot: single-row upsert, atomic with the rest.
      await db.insert(snapshotTableName, {
        'id': snapshotRowId,
        'payload_json': payload,
        'updated_at': now,
      });
      if (failMidTransaction) {
        throw StateError('Simulated ORBIT Drift save failure');
      }

      // 2. Relational task projection (replace-on-conflict by id;
      // created_at survives from the existing row).
      for (final entry in taskEntries) {
        final existing = await db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'id = ?',
          whereArgs: [entry['id']],
          limit: 1,
        );
        final createdAt = existing.isNotEmpty
            ? (existing.single['created_at'] as num?)?.toInt() ?? now
            : now;
        await db.insert(OrbitDatabaseSchema.tableTasks, {
          ...entry,
          'created_at': createdAt,
        });
      }

      // 3. Relational event projection (replace-on-conflict by id;
      // is_all_day/category preserved from the existing row).
      for (final entry in eventEntries) {
        final existing = await db.query(
          OrbitDatabaseSchema.tableEvents,
          where: 'id = ?',
          whereArgs: [entry['id']],
          limit: 1,
        );
        await db.insert(OrbitDatabaseSchema.tableEvents, {
          ...entry,
          'is_all_day': existing.isNotEmpty ? existing.single['is_all_day'] : 0,
          'category': existing.isNotEmpty
              ? existing.single['category']
              : 'work',
        });
      }

      // 4. Sync deletions: rows removed from the state disappear from the
      // relational projection as well.
      final keepTaskIds = taskEntries.map((e) => e['id']).toSet();
      for (final row in await db.query(OrbitDatabaseSchema.tableTasks)) {
        final id = row['id'];
        if (id is String && !keepTaskIds.contains(id)) {
          await db.delete(
            OrbitDatabaseSchema.tableTasks,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
      final keepEventIds = eventEntries.map((e) => e['id']).toSet();
      for (final row in await db.query(OrbitDatabaseSchema.tableEvents)) {
        final id = row['id'];
        if (id is String && !keepEventIds.contains(id)) {
          await db.delete(
            OrbitDatabaseSchema.tableEvents,
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    });
  }

  /// Legacy task map → relational row (all values are bound parameters in
  /// the actual INSERT; the map only names the columns).
  List<Map<String, Object?>> _taskEntriesOf(Map<String, Object?> state) {
    final raw = state['tasks'];
    if (raw is! List<Object?>) return const <Map<String, Object?>>[];
    final entries = <Map<String, Object?>>[];
    for (final item in raw) {
      if (item is! Map<String, Object?>) continue;
      entries.add(<String, Object?>{
        'id': item['id']! as String,
        'workspace_id': defaultWorkspaceId,
        'title': item['title']! as String,
        'project': item['project'] as String?,
        'due_date': item['due'] as String?,
        'is_done': ((item['done'] as bool?) ?? false) ? 1 : 0,
        'priority': (item['priority'] as num?)?.toInt() ?? 0,
      });
    }
    return entries;
  }

  /// Legacy event map → relational row. `date` (+optional `endTime`) derives
  /// start/end; entries without a date keep their previous relational times.
  List<Map<String, Object?>> _eventEntriesOf(Map<String, Object?> state) {
    final raw = state['events'];
    if (raw is! List<Object?>) return const <Map<String, Object?>>[];
    final entries = <Map<String, Object?>>[];
    for (final item in raw) {
      if (item is! Map<String, Object?>) continue;
      final dateRaw = item['date'];
      final date = dateRaw is String ? DateTime.tryParse(dateRaw) : null;
      final endTimeRaw = item['endTime'];
      var endTimeParts = const <int>[0, 0];
      if (endTimeRaw is String) {
        final parts = endTimeRaw.split(':');
        endTimeParts = [
          int.tryParse(parts.first) ?? 0,
          parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
        ];
      }
      // date already carries the start time-of-day; endTime only refines
      // the end instant.
      final startMs = date != null ? date.millisecondsSinceEpoch : 0;
      final endMs = date != null
          ? DateTime(
              date.year,
              date.month,
              date.day,
              endTimeParts[0],
              endTimeParts[1],
            ).millisecondsSinceEpoch
          : 0;
      entries.add(<String, Object?>{
        'id': item['id']! as String,
        'workspace_id': defaultWorkspaceId,
        'title': (item['title'] as String?) ?? 'Событие',
        'description': item['description'] as String?,
        'start_time': startMs,
        'end_time': endMs,
        'location': item['location'] as String?,
      });
    }
    return entries;
  }

  @override
  Future<void> resetCorruptData() async {
    final db = await _store;
    await db.transaction((_) async {
      // Removes the Drift state only. The legacy SharedPreferences backup is
      // intentionally NOT touched (step requirement: it remains the backup).
      await db.delete(
        snapshotTableName,
        where: 'id = ?',
        whereArgs: [snapshotRowId],
      );
      await db.delete(OrbitDatabaseSchema.tableTasks);
      await db.delete(OrbitDatabaseSchema.tableEvents);
    });
    _migrationAttempted = false;
  }

  @override
  Future<String> exportCorruptBackup() async {
    final db = await _store;
    final rows = await db.query(
      snapshotTableName,
      where: 'id = ?',
      whereArgs: [snapshotRowId],
      limit: 1,
    );
    String? raw = rows.isNotEmpty
        ? rows.single['payload_json'] as String?
        : null;
    if (raw == null || raw.isEmpty) {
      // Diagnostics-only fallback to the untouched legacy SharedPreferences
      // payload; this never feeds the load path, so it cannot create a
      // split-brain state.
      final prefs = await SharedPreferences.getInstance();
      raw =
          prefs.getString(SharedPreferencesLocalStateRepository.backupKey) ??
          prefs.getString(SharedPreferencesLocalStateRepository.storageKey);
    }
    if (raw == null || raw.isEmpty) {
      throw StateError('No corrupt local backup is available');
    }
    final path = await const MethodChannel('orbit/qa').invokeMethod<String>(
      'exportText',
      <String, Object?>{
        'name': 'local-state',
        'directory': 'ORBIT_recovery',
        'text': raw,
      },
    );
    if (path == null || path.isEmpty) {
      throw StateError('Corrupt local backup export failed');
    }
    return path;
  }
}
