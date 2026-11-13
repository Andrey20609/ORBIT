import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import '../models/workspace_record.dart';
import 'orbit_database.dart';

/// Real SQLite (Drift) implementation of [OrbitDatabase].
///
/// Keeps the existing raw SQL schema from [OrbitDatabaseSchema] unchanged and
/// speaks the same typed `Map<String, Object?>` row language as
/// [MemoryOrbitDatabase], so [OrbitDataEngine] and the local-state migrator
/// work against both implementations without modifications.
///
/// The underlying Drift database is created lazily; repeated [open] calls are
/// no-ops. Transactions are executed by Drift and genuinely roll back on
/// errors. All row values and where-arguments are bound as SQL parameters;
/// table names are validated against the known schema tables.
final class DriftOrbitDatabase implements OrbitDatabase {
  DriftOrbitDatabase({this.file});

  /// Target SQLite file. `null` keeps the database in memory (useful for
  /// tests); production usage passes a real file for persistence.
  final File? file;

  bool _isOpen = false;
  _OrbitDriftCore? _core;

  @override
  bool get isOpen => _isOpen;

  Future<_OrbitDriftCore> _requireCore() async {
    if (!_isOpen || _core == null) {
      await open();
    }
    return _core!;
  }

  static String _validateTable(String table) {
    const known = {
      OrbitDatabaseSchema.tableWorkspaces,
      OrbitDatabaseSchema.tableAccounts,
      OrbitDatabaseSchema.tableEmails,
      OrbitDatabaseSchema.tableEvents,
      OrbitDatabaseSchema.tableTasks,
      OrbitDatabaseSchema.tableNotes,
      OrbitDatabaseSchema.tableContacts,
      OrbitDatabaseSchema.tableFiles,
    };
    if (!known.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Unknown ORBIT table');
    }
    return table;
  }

  @override
  Future<void> open() async {
    if (_isOpen && _core != null) return;
    final executor = file == null
        ? NativeDatabase.memory()
        : NativeDatabase(file!);
    final core = _OrbitDriftCore(executor);
    await core.doOpen();
    _core = core;
    _isOpen = true;
  }

  @override
  Future<void> close() async {
    final core = _core;
    if (core != null) {
      await core.close();
    }
    _core = null;
    _isOpen = false;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final core = await _requireCore();
    final safeTable = _validateTable(table);
    final buffer = StringBuffer('SELECT * FROM $safeTable');
    if (where != null && where.isNotEmpty) {
      buffer.write(' WHERE $where');
    }
    if (orderBy != null && orderBy.isNotEmpty) {
      buffer.write(' ORDER BY $orderBy');
    }
    if (limit != null) {
      buffer.write(' LIMIT $limit');
    }
    final rows = await core
        .customSelect(
          buffer.toString(),
          variables: [
            for (final arg in whereArgs ?? const <Object?>[]) Variable(arg),
          ],
        )
        .get();
    return rows
        .map((row) => Map<String, Object?>.of(row.data))
        .toList(growable: false);
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = true,
  }) async {
    final core = await _requireCore();
    final safeTable = _validateTable(table);
    if (values.isEmpty) {
      await core.customStatement(
        'INSERT${replaceOnConflict ? ' OR REPLACE' : ''} INTO $safeTable DEFAULT VALUES',
      );
      return 1;
    }
    final columns = values.keys.toList();
    final placeholders = List.filled(columns.length, '?').join(', ');
    // customUpdate returns the affected-row count (customInsert would
    // return the last-insert rowid, which breaks the OrbitDatabase
    // contract of returning affected rows).
    final result = await core.customUpdate(
      'INSERT${replaceOnConflict ? ' OR REPLACE' : ''} INTO $safeTable'
      ' (${columns.join(', ')}) VALUES ($placeholders)',
      variables: [for (final column in columns) Variable(values[column])],
    );
    return result;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final core = await _requireCore();
    final safeTable = _validateTable(table);
    if (values.isEmpty) return 0;
    final assignments = values.keys.map((c) => '$c = ?').join(', ');
    final statement = StringBuffer('UPDATE $safeTable SET $assignments');
    final variables = <Variable>[
      for (final column in values.keys) Variable(values[column]),
    ];
    if (where != null && where.isNotEmpty) {
      statement.write(' WHERE $where');
      variables.addAll([
        for (final arg in whereArgs ?? const <Object?>[]) Variable(arg),
      ]);
    }
    final result = await core.customUpdate(
      statement.toString(),
      variables: variables,
    );
    return result;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final core = await _requireCore();
    final safeTable = _validateTable(table);
    final statement = StringBuffer('DELETE FROM $safeTable');
    final variables = <Variable>[];
    if (where != null && where.isNotEmpty) {
      statement.write(' WHERE $where');
      variables.addAll([
        for (final arg in whereArgs ?? const <Object?>[]) Variable(arg),
      ]);
    }
    return core.customUpdate(statement.toString(), variables: variables);
  }

  @override
  Future<T> transaction<T>(Future<T> Function(OrbitDatabase txn) action) async {
    final core = await _requireCore();
    // Drift routes every query executed inside the zone into the transaction;
    // an error rethrown by [action] makes Drift roll the transaction back.
    return core.transaction<T>(() async {
      final result = await action(this);
      return result;
    });
  }
}

/// Thin [GeneratedDatabase] shell that owns the connection, creates the
/// existing ORBIT SQL schema verbatim and seeds default workspaces the same
/// way [MemoryOrbitDatabase] does.
final class _OrbitDriftCore extends GeneratedDatabase {
  _OrbitDriftCore(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => const [];

  bool _seeded = false;

  /// Forces the lazy connection open. Drift runs the migration strategy
  /// (schema creation + workspace seeding) on this first statement.
  Future<void> doOpen() async {
    await customStatement('PRAGMA foreign_keys = ON');
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      for (final statement in <String>[
        OrbitDatabaseSchema.createWorkspaces,
        OrbitDatabaseSchema.createAccounts,
        OrbitDatabaseSchema.createEmails,
        OrbitDatabaseSchema.createEvents,
        OrbitDatabaseSchema.createTasks,
        OrbitDatabaseSchema.createNotes,
        OrbitDatabaseSchema.createContacts,
        OrbitDatabaseSchema.createFiles,
      ]) {
        await customStatement(statement);
      }
      await _seedDefaultWorkspaces();
    },
  );

  Future<void> _seedDefaultWorkspaces() async {
    if (_seeded) return;
    _seeded = true;
    for (final workspace in WorkspaceRecord.defaultWorkspaces) {
      final map = workspace.toMap();
      final columns = map.keys.toList();
      final placeholders = List.filled(columns.length, '?').join(', ');
      await customInsert(
        'INSERT OR REPLACE INTO ${OrbitDatabaseSchema.tableWorkspaces}'
        ' (${columns.join(', ')}) VALUES ($placeholders)',
        variables: [for (final column in columns) Variable(map[column])],
      );
    }
  }
}
