import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/database/orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_local_state_migrator.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';

const _legacyJson = <String, Object?>{
  'schemaVersion': 1,
  'draftTo': 'test@example.com',
  'draftSubject': 'Legacy Subject',
  'tasks': [
    {
      'id': 'legacy-task-1',
      'title': 'Согласовать бюджет',
      'project': 'Финансы',
      'due': '15 нояб.',
      'done': false,
      'priority': 2,
    },
    {
      'id': 'legacy-task-2',
      'title': 'Обновить сертификаты',
      'project': 'Инфраструктура',
      'due': 'Завтра',
      'done': true,
      'priority': 0,
    },
  ],
  'events': [
    {
      'id': 'legacy-event-1',
      'title': 'Ревью архитектуры',
      'location': 'Конференц-зал 2',
      'start': '2026-11-12T14:00:00.000Z',
      'end': '2026-11-12T15:00:00.000Z',
    },
  ],
};

void main() {
  late Directory tempDir;

  setUpAll(() {
    // Touch the real SQLite FFI once so any host-side loading happens in a
    // controlled place before individual tests run.
    DriftOrbitDatabase().isOpen;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orbit_drift_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DriftOrbitDatabase (real SQLite)', () {
    test(
      '[DATA-02-1] opens, creates schema and runs full CRUD cycle',
      () async {
        final db = DriftOrbitDatabase();
        expect(db.isOpen, isFalse);
        await db.open();
        expect(db.isOpen, isTrue);

        // Every schema table accepts a row: proves they all exist with the
        // documented columns. workspace-work is pre-seeded for the FK.
        for (final (table, row) in const [
          (
            OrbitDatabaseSchema.tableWorkspaces,
            <String, Object?>{
              'id': 'ws-probe',
              'name': 'Probe',
              'type': 'work',
              'color_value': 1,
              'is_default': 0,
              'created_at': 1700000000000,
            },
          ),
          (
            OrbitDatabaseSchema.tableAccounts,
            <String, Object?>{
              'id': 'acc-probe',
              'workspace_id': 'workspace-work',
              'email': 'probe@example.demo',
              'display_name': 'Probe',
              'provider_type': 'demo',
              'sync_status': 'idle',
              'last_sync_at': null,
            },
          ),
          (
            OrbitDatabaseSchema.tableEmails,
            <String, Object?>{
              'id': 'email-probe',
              'workspace_id': 'workspace-work',
              'account_id': null,
              'folder': 'inbox',
              'sender': 'a@b.demo',
              'recipient': 'c@d.demo',
              'subject': 'Probe',
              'preview': 'Probe',
              'body': 'Probe',
              'timestamp': 1700000000000,
              'is_read': 0,
              'is_flagged': 0,
              'has_attachments': 0,
            },
          ),
          (
            OrbitDatabaseSchema.tableEvents,
            <String, Object?>{
              'id': 'event-probe',
              'workspace_id': 'workspace-work',
              'title': 'Probe',
              'description': null,
              'start_time': 1700000000000,
              'end_time': 1700000001000,
              'location': null,
              'is_all_day': 0,
              'category': 'work',
              'participants_json': null,
            },
          ),
          (
            OrbitDatabaseSchema.tableTasks,
            <String, Object?>{
              'id': 'task-probe',
              'workspace_id': 'workspace-work',
              'title': 'Probe',
              'project': null,
              'due_date': null,
              'is_done': 0,
              'priority': 0,
              'created_at': 1700000000000,
            },
          ),
          (
            OrbitDatabaseSchema.tableNotes,
            <String, Object?>{
              'id': 'note-probe',
              'workspace_id': 'workspace-work',
              'title': 'Probe',
              'content': 'Probe',
              'tags_json': null,
              'updated_at': 1700000000000,
            },
          ),
          (
            OrbitDatabaseSchema.tableContacts,
            <String, Object?>{
              'id': 'contact-probe',
              'workspace_id': 'workspace-work',
              'name': 'Probe',
              'email': 'probe@example.demo',
              'phone': null,
              'company': null,
              'role': null,
              'avatar_url': null,
            },
          ),
          (
            OrbitDatabaseSchema.tableFiles,
            <String, Object?>{
              'id': 'file-probe',
              'workspace_id': 'workspace-work',
              'file_name': 'probe.txt',
              'extension': 'txt',
              'size_bytes': 1,
              'mime_type': 'text/plain',
              'local_path': null,
              'remote_uri': null,
              'associated_entity_type': null,
              'associated_entity_id': null,
              'created_at': 1700000000000,
              'updated_at': 1700000000000,
            },
          ),
        ]) {
          final count = await db.insert(table, row);
          expect(count, 1, reason: 'insert into $table failed: table missing?');
          final found = await db.query(
            table,
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          expect(found, hasLength(1), reason: 'row not found in $table');
        }

        // Default workspaces are seeded like MemoryOrbitDatabase does.
        final workspaces = await db.query(
          OrbitDatabaseSchema.tableWorkspaces,
          orderBy: 'created_at ASC',
        );
        expect(workspaces, isNotEmpty);
        expect(workspaces.map((w) => w['id']), contains('workspace-work'));

        // INSERT with replace-on-conflict semantics.
        final inserted = await db.insert(OrbitDatabaseSchema.tableTasks, {
          'id': 'task-crud-1',
          'workspace_id': 'workspace-work',
          'title': 'Проверить CRUD',
          'project': 'QA',
          'due_date': 'завтра',
          'is_done': 0,
          'priority': 3,
          'created_at': 1700000000000,
        });
        expect(inserted, 1);

        // SELECT by bound parameter.
        final rows = await db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'id = ?',
          whereArgs: ['task-crud-1'],
        );
        expect(rows, hasLength(1));
        expect(rows.single['title'], 'Проверить CRUD');
        expect(rows.single['priority'], 3);

        // UPDATE through bound where-args.
        final updated = await db.update(
          OrbitDatabaseSchema.tableTasks,
          {'is_done': 1, 'priority': 5},
          where: 'id = ?',
          whereArgs: ['task-crud-1'],
        );
        expect(updated, 1);
        final afterUpdate = await db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'id = ?',
          whereArgs: ['task-crud-1'],
        );
        expect(afterUpdate.single['is_done'], 1);
        expect(afterUpdate.single['priority'], 5);

        // replaceOnConflict: true replaces the row with the same primary key.
        await db.insert(OrbitDatabaseSchema.tableTasks, {
          'id': 'task-crud-1',
          'workspace_id': 'workspace-work',
          'title': 'Проверить CRUD v2',
          'project': null,
          'due_date': null,
          'is_done': 0,
          'priority': 1,
          'created_at': 1700000001000,
        });
        final afterReplace = await db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'id = ?',
          whereArgs: ['task-crud-1'],
        );
        expect(afterReplace, hasLength(1));
        expect(afterReplace.single['title'], 'Проверить CRUD v2');

        // DELETE through bound where-args.
        final deleted = await db.delete(
          OrbitDatabaseSchema.tableTasks,
          where: 'id = ?',
          whereArgs: ['task-crud-1'],
        );
        expect(deleted, 1);
        expect(
          await db.query(
            OrbitDatabaseSchema.tableTasks,
            where: 'id = ?',
            whereArgs: ['task-crud-1'],
          ),
          isEmpty,
        );

        await db.close();
        expect(db.isOpen, isFalse);
      },
    );

    test(
      '[DATA-02-2] migrates legacy JSON tasks/events with full preservation',
      () async {
        final legacyRepo = MemoryLocalStateRepository(_legacyJson);
        final db = DriftOrbitDatabase();
        final dataEngine = OrbitDataEngine(db);
        await dataEngine.initialize();

        final migrator = OrbitLocalStateMigrator(
          repository: legacyRepo,
          dataEngine: dataEngine,
        );
        final result = await migrator.migrateIfNeeded();

        expect(result.success, isTrue);
        expect(result.tasksMigrated, 2);
        expect(result.eventsMigrated, 1);

        // Read raw rows straight from SQLite and assert every legacy field.
        final taskRows = await db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'workspace_id = ?',
          whereArgs: ['workspace-work'],
          orderBy: 'id ASC',
        );
        expect(taskRows, hasLength(2));

        final task1 = taskRows.firstWhere((r) => r['id'] == 'legacy-task-1');
        expect(task1['title'], 'Согласовать бюджет');
        expect(task1['project'], 'Финансы');
        expect(task1['due_date'], '15 нояб.');
        expect(task1['is_done'], 0);
        expect(task1['priority'], 2);

        final task2 = taskRows.firstWhere((r) => r['id'] == 'legacy-task-2');
        expect(task2['title'], 'Обновить сертификаты');
        expect(task2['project'], 'Инфраструктура');
        expect(task2['due_date'], 'Завтра');
        expect(task2['is_done'], 1);
        expect(task2['priority'], 0);

        final eventRows = await db.query(
          OrbitDatabaseSchema.tableEvents,
          where: 'workspace_id = ?',
          whereArgs: ['workspace-work'],
        );
        expect(eventRows, hasLength(1));
        final event = eventRows.single;
        expect(event['id'], 'legacy-event-1');
        expect(event['title'], 'Ревью архитектуры');
        expect(event['location'], 'Конференц-зал 2');
        // 2026-11-12T14:00:00Z → epoch milliseconds.
        expect(
          event['start_time'],
          DateTime.parse('2026-11-12T14:00:00.000Z').millisecondsSinceEpoch,
        );
        expect(
          event['end_time'],
          DateTime.parse('2026-11-12T15:00:00.000Z').millisecondsSinceEpoch,
        );
        expect(event['workspace_id'], 'workspace-work');

        // Engine-level models also resolve from the Drift database.
        final tasks = await dataEngine.getTasks();
        expect(tasks, hasLength(2));
        final events = await dataEngine.getEvents();
        expect(events, hasLength(1));

        await db.close();
      },
    );

    test(
      '[DATA-02-3] repeated migrateIfNeeded creates no duplicates',
      () async {
        final legacyRepo = MemoryLocalStateRepository(_legacyJson);
        final db = DriftOrbitDatabase();
        final dataEngine = OrbitDataEngine(db);
        await dataEngine.initialize();

        final migrator = OrbitLocalStateMigrator(
          repository: legacyRepo,
          dataEngine: dataEngine,
        );

        final first = await migrator.migrateIfNeeded();
        expect(first.success, isTrue);
        expect(first.tasksMigrated, 2);
        expect(first.eventsMigrated, 1);

        final second = await migrator.migrateIfNeeded();
        expect(second.success, isTrue);
        expect(second.tasksMigrated, 2);
        expect(second.eventsMigrated, 1);

        final tasks = await db.query(OrbitDatabaseSchema.tableTasks);
        expect(tasks, hasLength(2), reason: 'tasks duplicated on re-migration');
        final events = await db.query(OrbitDatabaseSchema.tableEvents);
        expect(
          events,
          hasLength(1),
          reason: 'events duplicated on re-migration',
        );

        await db.close();
      },
    );

    test('[DATA-02-4] transactional error rolls back all changes', () async {
      final db = DriftOrbitDatabase();
      await db.open();

      await db.insert(OrbitDatabaseSchema.tableTasks, {
        'id': 'pre-existing',
        'workspace_id': 'workspace-work',
        'title': 'Существующая задача',
        'project': null,
        'due_date': null,
        'is_done': 0,
        'priority': 0,
        'created_at': 1700000000000,
      });

      var caught = false;
      try {
        await db.transaction((txn) async {
          await txn.insert(OrbitDatabaseSchema.tableTasks, {
            'id': 'inside-tx',
            'workspace_id': 'workspace-work',
            'title': 'Внутри транзакции',
            'project': null,
            'due_date': null,
            'is_done': 0,
            'priority': 1,
            'created_at': 1700000002000,
          });
          await txn.delete(
            OrbitDatabaseSchema.tableTasks,
            where: 'id = ?',
            whereArgs: ['pre-existing'],
          );
          // Artificial failure midway through the transaction.
          throw StateError('artificial migration failure');
        });
      } on StateError {
        caught = true;
      }
      expect(caught, isTrue, reason: 'transaction error must propagate');

      // Both the insert and the delete are rolled back.
      final rows = await db.query(OrbitDatabaseSchema.tableTasks);
      expect(rows.map((r) => r['id']), contains('pre-existing'));
      expect(rows.map((r) => r['id']), isNot(contains('inside-tx')));
      expect(rows, hasLength(1));

      await db.close();
    });

    test(
      '[DATA-02-5] data persists across close and reopen on a file DB',
      () async {
        final dbFile = File('${tempDir.path}${Platform.pathSeparator}orbit.db');
        final db = DriftOrbitDatabase(file: dbFile);
        await db.open();

        final legacyRepo = MemoryLocalStateRepository(_legacyJson);
        final dataEngine = OrbitDataEngine(db);
        await dataEngine.initialize();
        final result = await OrbitLocalStateMigrator(
          repository: legacyRepo,
          dataEngine: dataEngine,
        ).migrateIfNeeded();
        expect(result.success, isTrue);

        await db.close();
        expect(db.isOpen, isFalse);
        expect(dbFile.existsSync(), isTrue, reason: 'SQLite file must exist');

        // Reopen the same file: schema is already there, data must survive.
        final reopened = DriftOrbitDatabase(file: dbFile);
        await reopened.open();
        final tasks = await reopened.query(
          OrbitDatabaseSchema.tableTasks,
          orderBy: 'id ASC',
        );
        expect(
          tasks.map((r) => r['id']),
          unorderedEquals(['legacy-task-1', 'legacy-task-2']),
        );
        final task1 = tasks.firstWhere((r) => r['id'] == 'legacy-task-1');
        expect(task1['title'], 'Согласовать бюджет');
        expect(task1['priority'], 2);
        final events = await reopened.query(OrbitDatabaseSchema.tableEvents);
        expect(events, hasLength(1));

        // Opening twice is a safe no-op.
        await reopened.open();
        expect(reopened.isOpen, isTrue);
        await reopened.close();
      },
    );

    test('[DATA-02-6] empty legacy state migrates without writes', () async {
      final legacyRepo = MemoryLocalStateRepository(<String, Object?>{});
      final db = DriftOrbitDatabase();
      final dataEngine = OrbitDataEngine(db);
      await dataEngine.initialize();

      final migrator = OrbitLocalStateMigrator(
        repository: legacyRepo,
        dataEngine: dataEngine,
      );
      final result = await migrator.migrateIfNeeded();

      expect(result.success, isTrue);
      expect(result.tasksMigrated, 0);
      expect(result.eventsMigrated, 0);
      expect(await db.query(OrbitDatabaseSchema.tableTasks), isEmpty);
      expect(await db.query(OrbitDatabaseSchema.tableEvents), isEmpty);
      // Default workspaces still seeded, schema usable.
      expect(await db.query(OrbitDatabaseSchema.tableWorkspaces), isNotEmpty);

      await db.close();
    });
  });
}
