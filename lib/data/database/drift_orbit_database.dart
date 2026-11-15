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
  Future<void>? _opening;

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
      snapshotTableName,
      migrationsTableName,
      outboxTableName,
      imapBodyCacheTableName,
    };
    if (!known.contains(table)) {
      throw ArgumentError.value(table, 'table', 'Unknown ORBIT table');
    }
    return table;
  }

  /// Kimi STEP1 remark #3: where/orderBy fragments are checked against a
  /// per-table column allowlist before being embedded into SQL, so dynamic
  /// or hostile input can never inject extra SQL syntax.
  static const Map<String, Set<String>> _tableColumns = {
    imapBodyCacheTableName: {
      'id',
      'account_id',
      'uid_validity',
      'uid',
      'body_text',
      'truncated',
      'full_size',
      'attachments_json',
      'fetched_at',
    },
    outboxTableName: {
      'id',
      'workspace_id',
      'account_id',
      'recipient',
      'subject',
      'body',
      'created_at',
      'status',
      'retry_count',
      'last_error',
      'sent_at',
    },
    OrbitDatabaseSchema.tableWorkspaces: {
      'id',
      'name',
      'type',
      'color_value',
      'is_default',
      'created_at',
    },
    OrbitDatabaseSchema.tableAccounts: {
      'id',
      'workspace_id',
      'email',
      'display_name',
      'provider_type',
      'sync_status',
      'last_sync_at',
    },
    OrbitDatabaseSchema.tableEmails: {
      'id',
      'workspace_id',
      'account_id',
      'folder',
      'sender',
      'recipient',
      'subject',
      'preview',
      'body',
      'timestamp',
      'is_read',
      'is_flagged',
      'has_attachments',
      'source_type',
    },
    OrbitDatabaseSchema.tableEvents: {
      'id',
      'workspace_id',
      'title',
      'description',
      'start_time',
      'end_time',
      'location',
      'is_all_day',
      'category',
      'participants_json',
    },
    OrbitDatabaseSchema.tableTasks: {
      'id',
      'workspace_id',
      'title',
      'project',
      'due_date',
      'is_done',
      'priority',
      'created_at',
    },
    OrbitDatabaseSchema.tableNotes: {
      'id',
      'workspace_id',
      'title',
      'content',
      'tags_json',
      'updated_at',
    },
    OrbitDatabaseSchema.tableContacts: {
      'id',
      'workspace_id',
      'name',
      'email',
      'phone',
      'company',
      'role',
      'avatar_url',
    },
    OrbitDatabaseSchema.tableFiles: {
      'id',
      'workspace_id',
      'file_name',
      'extension',
      'size_bytes',
      'mime_type',
      'local_path',
      'remote_uri',
      'associated_entity_type',
      'associated_entity_id',
      'created_at',
      'updated_at',
    },
    snapshotTableName: {'id', 'payload_json', 'updated_at'},
    migrationsTableName: {'name', 'applied_at'},
  };

  static final RegExp _identifierInText = RegExp(r'[A-Za-z_][A-Za-z0-9_]*');
  static const _sqlKeywords = {
    'AND',
    'OR',
    'NOT',
    'NULL',
    'IN',
    'LIKE',
    'GLOB',
    'BETWEEN',
    'IS',
    'EXISTS',
    'CASE',
    'WHEN',
    'THEN',
    'ELSE',
    'END',
    'ASC',
    'DESC',
    'COLLATE',
    'ESCAPE',
    'TRUE',
    'FALSE',
  };
  static final RegExp _forbiddenFragment = RegExp(r';|--|/\*|\*/');
  static final RegExp _forbiddenWhereKeyword = RegExp(
    r'\b(ATTACH|DETACH|PRAGMA|DROP|CREATE|ALTER|REPLACE|VACUUM|REINDEX|'
    r'UNION|SELECT|INSERT|UPDATE|DELETE|ORDER\s+BY|GROUP\s+BY|LIMIT)\b',
    caseSensitive: false,
  );

  static void _validateWhere(String table, String where) {
    // Strip quoted literals first: their content is data (id 'project-update'
    // contains the word "update"), never an identifier or a keyword.
    final literalPattern = RegExp("'[^']*'|\"[^\"]*\"");
    final withoutLiterals = where.replaceAll(literalPattern, '?');
    if (_forbiddenFragment.hasMatch(withoutLiterals)) {
      throw ArgumentError.value(
        withoutLiterals,
        'where',
        'Forbidden SQL fragment in WHERE clause',
      );
    }
    if (_forbiddenWhereKeyword.hasMatch(withoutLiterals)) {
      throw ArgumentError.value(
        withoutLiterals,
        'where',
        'Forbidden SQL keyword in WHERE clause',
      );
    }
    final columns = _tableColumns[table]!;
    for (final match in _identifierInText.allMatches(withoutLiterals)) {
      final identifier = match.group(0)!;
      if (_sqlKeywords.contains(identifier.toUpperCase())) continue;
      if (!columns.contains(identifier)) {
        throw ArgumentError.value(
          where,
          'where',
          "Unknown column '$identifier' for table '$table'",
        );
      }
    }
  }

  static void _validateOrderBy(String table, String orderBy) {
    final columns = _tableColumns[table]!;
    final segmentPattern = RegExp(
      r'^\s*([A-Za-z_][A-Za-z0-9_]*)(\s+(ASC|DESC))?\s*$',
      caseSensitive: false,
    );
    for (final rawSegment in orderBy.split(',')) {
      final match = segmentPattern.firstMatch(rawSegment);
      if (match == null) {
        throw ArgumentError.value(
          orderBy,
          'orderBy',
          'orderBy must be a comma list of "column [ASC|DESC]"',
        );
      }
      final column = match.group(1)!;
      if (!columns.contains(column)) {
        throw ArgumentError.value(
          orderBy,
          'orderBy',
          "Unknown column '$column' for table '$table'",
        );
      }
    }
  }

  static void _validateLimit(int limit) {
    if (limit < 0) {
      throw ArgumentError.value(limit, 'limit', 'limit must be >= 0');
    }
  }

  @override
  Future<void> open() async {
    if (_isOpen && _core != null) return;
    // Kimi STEP1 remark #2: concurrent open() calls must share one
    // in-flight opening instead of racing competing connections.
    final existing = _opening;
    if (existing != null) {
      return existing;
    }
    final opening = _openInternal();
    _opening = opening;
    try {
      await opening;
    } finally {
      if (identical(_opening, opening)) {
        _opening = null;
      }
    }
  }

  Future<void> _openInternal() async {
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
    if (where != null && where.isNotEmpty) {
      _validateWhere(safeTable, where);
    }
    if (orderBy != null && orderBy.isNotEmpty) {
      _validateOrderBy(safeTable, orderBy);
    }
    if (limit != null) {
      _validateLimit(limit);
    }
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
      _validateWhere(safeTable, where);
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
      _validateWhere(safeTable, where);
      statement.write(' WHERE $where');
      variables.addAll([
        for (final arg in whereArgs ?? const <Object?>[]) Variable(arg),
      ]);
    }
    return core.customUpdate(statement.toString(), variables: variables);
  }

  /// Test/diagnostic helpers over the raw core (bypass the typed layer and
  /// its allowlist — never expose them to production flows).
  Future<void> executeRawForTesting(String statement) async {
    final core = await _requireCore();
    await core.customStatement(statement);
  }

  Future<List<Map<String, Object?>>> selectRawForTesting(String sql) async {
    final core = await _requireCore();
    final rows = await core.customSelect(sql).get();
    return rows.map((row) => Map<String, Object?>.of(row.data)).toList();
  }

  Future<int> updateRawForTesting(String sql, List<Object?> args) async {
    final core = await _requireCore();
    return core.customUpdate(
      sql,
      variables: [for (final arg in args) Variable(arg)],
    );
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

/// STEP2: single-row storage for the full JSON state snapshot that backs
/// DriftLocalStateRepository. One row (id = 1), written atomically.
const String snapshotTableName = 'app_state_snapshots';
const String createSnapshotTable = '''
  CREATE TABLE IF NOT EXISTS app_state_snapshots (
    id INTEGER PRIMARY KEY,
    payload_json TEXT NOT NULL,
    updated_at INTEGER NOT NULL
  );
''';

/// STEP3: Drift-only migration marker table. A row here means the named
/// backfill already ran, even when the target business tables are empty.
const String migrationsTableName = 'app_state_migrations';
const String createMigrationsTable = '''
  CREATE TABLE IF NOT EXISTS app_state_migrations (
    name TEXT PRIMARY KEY,
    applied_at INTEGER NOT NULL
  );
''';

/// MAIL-02B: persistent SMTP outbox (controlled sending). Additive table:
/// created on EVERY open with IF NOT EXISTS, so existing STEP3/STEP4
/// databases upgrade in place without a schema version bump. Status
/// lifecycle is owned by the outbox store (queued/sending/sent/failed);
/// in-flight leftovers after a crash are never re-sent (duplicate guard).
const String outboxTableName = 'smtp_outbox';
const String createSmtpOutboxTable = '''
  CREATE TABLE IF NOT EXISTS smtp_outbox (
    id TEXT PRIMARY KEY,
    workspace_id TEXT NOT NULL,
    account_id TEXT NOT NULL,
    recipient TEXT NOT NULL,
    subject TEXT NOT NULL,
    body TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    status TEXT NOT NULL,
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_error TEXT,
    sent_at INTEGER
  );
''';

/// MAIL-02C: on-demand body cache (read-only IMAP). Additive table, same
/// in-place upgrade pattern. The email id is the MAIL-02A deterministic
/// id (accountId:folder:uidValidity:uid); uidvalidity is stored
/// explicitly so stale cache rows across folder generations are
/// detectable. Attachment PAYLOADS are never stored - only sanitized
/// metadata JSON (fileName/sizeBytes/mimeType).
const String imapBodyCacheTableName = 'imap_body_cache';
const String createImapBodyCacheTable = '''
  CREATE TABLE IF NOT EXISTS imap_body_cache (
    id TEXT PRIMARY KEY,
    account_id TEXT NOT NULL,
    uid_validity INTEGER NOT NULL,
    uid INTEGER NOT NULL,
    body_text TEXT NOT NULL,
    truncated INTEGER NOT NULL DEFAULT 0,
    full_size INTEGER NOT NULL DEFAULT 0,
    attachments_json TEXT NOT NULL DEFAULT '[]',
    fetched_at INTEGER NOT NULL
  );
''';

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
  /// (schema creation + workspace seeding) on this first statement; the
  /// snapshot table is ensured separately so older STEP1 files upgrade
  /// in place without a schema version bump.
  Future<void> doOpen() async {
    await customStatement('PRAGMA foreign_keys = ON');
    await customStatement(createSnapshotTable);
    await customStatement(createMigrationsTable);
    await customStatement(createSmtpOutboxTable);
    await customStatement(createImapBodyCacheTable);
    await _ensureEmailsSourceTypeColumn();
  }

  /// STEP4 additive schema upgrade: STEP3 files lack `emails.source_type`.
  /// The column is added once, guarded by a real `PRAGMA table_info` check —
  /// arbitrary SQLite errors are never masked as "column already exists".
  Future<void> _ensureEmailsSourceTypeColumn() async {
    final columns = await customSelect('PRAGMA table_info(emails)').get();
    final hasSourceType = columns.any(
      (row) => row.data['name'] == 'source_type',
    );
    if (hasSourceType) return;
    await customStatement(
      "ALTER TABLE emails ADD COLUMN source_type TEXT NOT NULL DEFAULT 'user'",
    );
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      for (final statement in <String>[
        createSnapshotTable,
        createMigrationsTable,
        createSmtpOutboxTable,
        createImapBodyCacheTable,
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
