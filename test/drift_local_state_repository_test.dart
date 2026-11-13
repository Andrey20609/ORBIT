import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_database.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_corrupt_data.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _legacyState = <String, Object?>{
  'schemaVersion': 1,
  'draftTo': 'boss@example.com',
  'draftSubject': 'Отчёт за неделю',
  'draftBody': 'Черновик письма',
  'readEmails': ['m1', 'm2'],
  'starredEmails': ['m3'],
  'currentMailFolder': 'inbox',
  'mailAccounts': [
    {'id': 'acc-1', 'name': 'Рабочая', 'email': 'work@example.com'},
  ],
  'brainChatHistory': [
    {'id': 'brain-1', 'text': 'План на день готов'},
  ],
  'tasks': [
    {
      'id': 'task-1',
      'title': 'Согласовать бюджет',
      'project': 'Финансы',
      'due': '15 нояб.',
      'done': false,
      'priority': 2,
    },
    {
      'id': 'task-2',
      'title': 'Обновить сертификаты',
      'project': 'Инфраструктура',
      'due': 'Завтра',
      'done': true,
      'priority': 0,
    },
  ],
  'events': [
    {
      'id': 'event-1',
      'time': '14:00',
      'title': 'Ревью архитектуры',
      'meta': 'Команда · Онлайн',
      'color': 0xFF4285F4,
      'date': '2026-11-20T14:00:00.000',
      'endTime': '15:30',
      'description': 'Разбор STEP2',
      'location': 'Конференц-зал 2',
    },
  ],
};

DriftLocalStateRepository _repoWithLegacy(
  Map<String, Object?> legacy, {
  DriftOrbitDatabase? db,
}) {
  final initial = <String, Object>{
    if (legacy.isNotEmpty)
      SharedPreferencesLocalStateRepository.storageKey: jsonEncode(legacy),
  };
  SharedPreferences.setMockInitialValues(initial);
  return DriftLocalStateRepository(
    database: db,
    legacyRepository: SharedPreferencesLocalStateRepository(),
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orbit_step2_test');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DriftLocalStateRepository (real SQLite)', () {
    test('[STEP2-1] full legacy migration preserves every field and fills '
        'relational tables', () async {
      final db = DriftOrbitDatabase();
      final repo = _repoWithLegacy(_legacyState, db: db);

      final state = await repo.load();

      // Non-normalized fields survive through the snapshot verbatim.
      expect(state['draftTo'], 'boss@example.com');
      expect(state['draftSubject'], 'Отчёт за неделю');
      expect(state['draftBody'], 'Черновик письма');
      expect(state['readEmails'], ['m1', 'm2']);
      expect(state['starredEmails'], ['m3']);
      expect(state['currentMailFolder'], 'inbox');
      expect((state['mailAccounts'] as List).length, 1);
      expect((state['brainChatHistory'] as List).length, 1);

      // Tasks/events come back as legacy-shaped maps driven by the
      // relational tables.
      final tasks = (state['tasks'] as List).cast<Map<String, Object?>>();
      expect(tasks, hasLength(2));
      final task1 = tasks.firstWhere((t) => t['id'] == 'task-1');
      expect(task1['title'], 'Согласовать бюджет');
      expect(task1['project'], 'Финансы');
      expect(task1['due'], '15 нояб.');
      expect(task1['done'], false);
      expect(task1['priority'], 2);
      final task2 = tasks.firstWhere((t) => t['id'] == 'task-2');
      expect(task2['done'], true);

      final events = (state['events'] as List).cast<Map<String, Object?>>();
      expect(events, hasLength(1));
      final event = events.single;
      expect(event['id'], 'event-1');
      expect(event['title'], 'Ревью архитектуры');
      // Decorations stay loss-free from the snapshot:
      expect(event['color'], 0xFF4285F4);
      expect(event['meta'], 'Команда · Онлайн');
      expect(event['location'], 'Конференц-зал 2');
      expect(event['description'], 'Разбор STEP2');
      // Relational-derived date refreshes from start_time:
      expect(event['date'], '2026-11-20T14:00:00.000');
      expect(event['endTime'], '15:30');

      // Relational tables really contain the projection rows.
      final taskRows = await db.query(OrbitDatabaseSchema.tableTasks);
      expect(taskRows, hasLength(2));
      final eventRows = await db.query(OrbitDatabaseSchema.tableEvents);
      expect(eventRows, hasLength(1));
      expect(eventRows.single['start_time'], greaterThan(0));
      expect(
        eventRows.single['end_time'],
        greaterThan(eventRows.single['start_time'] as int),
      );

      // Legacy SharedPreferences backup is still intact.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SharedPreferencesLocalStateRepository.storageKey),
        jsonEncode(_legacyState),
      );

      await db.close();
    });

    test('[STEP2-2] repeated load and repeated save create no duplicates',
        () async {
      final db = DriftOrbitDatabase();
      final repo = _repoWithLegacy(_legacyState, db: db);

      final first = await repo.load();
      final second = await repo.load();
      expect((second['tasks'] as List).length, 2);
      expect((second['events'] as List).length, 1);

      final snapshotPayloads = await db.query(snapshotTableName);
      expect(snapshotPayloads, hasLength(1));

      // Save the same state twice: relational rows stay deduplicated.
      await repo.save(first);
      await repo.save(first);
      expect(await db.query(OrbitDatabaseSchema.tableTasks), hasLength(2));
      expect(await db.query(OrbitDatabaseSchema.tableEvents), hasLength(1));

      final snapshots = await db.query(snapshotTableName);
      expect(snapshots, hasLength(1));
      expect(
        (snapshots.single['updated_at'] as num).toInt(),
        greaterThan(0),
      );

      await db.close();
    });

    test('[STEP2-3] round trip: edited state survives close and reopen of '
        'the file database', () async {
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}state.db',
      );
      final firstDb = DriftOrbitDatabase(file: dbFile);
      final repo = _repoWithLegacy(_legacyState, db: firstDb);
      final loaded = await repo.load();

      // Mutate: edit one task, add another, drop one event, change draft.
      final tasks = (loaded['tasks'] as List).cast<Map<String, Object?>>();
      tasks.firstWhere((t) => t['id'] == 'task-1')['done'] = true;
      tasks.add(<String, Object?>{
        'id': 'task-3',
        'title': 'Новая задача',
        'project': 'QA',
        'due': 'Пт',
        'done': false,
        'priority': 1,
      });
      final events = (loaded['events'] as List).where(
        (e) => (e! as Map<String, Object?>)['id'] != 'event-1',
      ).toList();
      final mutated = <String, Object?>{...loaded}
        ..['tasks'] = tasks
        ..['events'] = events
        ..['draftSubject'] = 'Обновлённая тема';

      await repo.save(mutated);
      await firstDb.close();

      final secondDb = DriftOrbitDatabase(file: dbFile);
      final repo2 = _repoWithLegacy(_legacyState, db: secondDb);
      // The legacy repository would return the OLD JSON, but the snapshot in
      // SQLite exists, so migration is skipped and Drift state wins.
      final reloaded = await repo2.load();

      expect(reloaded['draftSubject'], 'Обновлённая тема');
      final tasks2 = (reloaded['tasks'] as List).cast<Map<String, Object?>>();
      expect(tasks2, hasLength(3));
      expect(
        tasks2.firstWhere((t) => t['id'] == 'task-1')['done'],
        true,
      );
      expect(
        tasks2.firstWhere((t) => t['id'] == 'task-3')['title'],
        'Новая задача',
      );
      final events2 = reloaded['events'] as List;
      expect(events2, isEmpty);

      // Relational sync removed the dropped event row.
      final eventRows = await secondDb.query(OrbitDatabaseSchema.tableEvents);
      expect(eventRows, isEmpty);
      final taskRows = await secondDb.query(OrbitDatabaseSchema.tableTasks);
      expect(taskRows, hasLength(3));

      await secondDb.close();
    });

    test('[STEP2-4] failed save rolls back snapshot and relational rows',
        () async {
      final db = DriftOrbitDatabase();
      final repo = _repoWithLegacy(_legacyState, db: db);
      final loaded = await repo.load();

      final mutated = <String, Object?>{...loaded}
        ..['draftSubject'] = 'Не должен сохраниться'
        ..['tasks'] = [
          ...(loaded['tasks'] as List),
          <String, Object?>{
            'id': 'task-roll',
            'title': 'Откат',
            'project': null,
            'due': null,
            'done': false,
            'priority': 0,
          },
        ];

      repo.failNextSaveMidTransaction = true;
      await expectLater(repo.save(mutated), throwsStateError);

      // Previous state remains readable and intact.
      final after = await repo.load();
      expect(after['draftSubject'], 'Отчёт за неделю');
      expect((after['tasks'] as List), hasLength(2));
      expect(
        (after['tasks'] as List)
            .cast<Map<String, Object?>>()
            .map((t) => t['id']),
        isNot(contains('task-roll')),
      );

      // The snapshot row keeps the previous payload, not the failed one.
      final snapshots = await db.query(snapshotTableName);
      expect(snapshots, hasLength(1));
      final payload =
          jsonDecode(snapshots.single['payload_json']! as String)
              as Map<String, Object?>;
      expect(payload['draftSubject'], 'Отчёт за неделю');

      await db.close();
    });

    test('[STEP2-5] empty legacy JSON returns an empty state', () async {
      final db = DriftOrbitDatabase();
      final repo = _repoWithLegacy(<String, Object?>{}, db: db);

      final state = await repo.load();
      expect(state, isEmpty);

      // Migration marker was written, so the next load skips the legacy
      // read entirely (important: does not re-migrate on every load).
      final snapshots = await db.query(snapshotTableName);
      expect(snapshots, hasLength(1));

      final again = await repo.load();
      expect(again, isEmpty);

      await db.close();
    });

    test('[STEP2-6] corrupt handling: explicit error, legacy backup kept, '
        'reset clears Drift but not SharedPreferences', () async {
      final corruptJson = '{"schemaVersion": 1, "tasks": "not-a-list"}';
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocalStateRepository.storageKey: corruptJson,
        SharedPreferencesLocalStateRepository.backupKey: 'old-backup-raw',
      });
      final db = DriftOrbitDatabase();
      final repo = DriftLocalStateRepository(
        database: db,
        legacyRepository: SharedPreferencesLocalStateRepository(),
      );

      // The legacy layer raises the explicit corrupt-data exception; the
      // persistence error boundary surfaces it to the user. Nothing is
      // silently swallowed into an empty state.
      await expectLater(repo.load(), throwsA(isA<OrbitCorruptDataException>()));

      // Nothing was written into Drift during the failed migration.
      expect(await db.query(snapshotTableName), isEmpty);

      // The corrupt raw payload is preserved in SharedPreferences backup
      // (the legacy repository rewrites the backup slot with the raw it
      // saw — existing semantics, nothing is lost).
      final prefs = await SharedPreferences.getInstance();
      final backupAfterLoad = prefs.getString(
        SharedPreferencesLocalStateRepository.backupKey,
      );
      expect(backupAfterLoad, corruptJson);

      // reset clears the Drift state; the SharedPreferences backup stays.
      await repo.resetCorruptData();
      expect(await db.query(snapshotTableName), isEmpty);
      expect(
        prefs.getString(SharedPreferencesLocalStateRepository.backupKey),
        corruptJson,
      );
      expect(
        prefs.getString(SharedPreferencesLocalStateRepository.storageKey),
        corruptJson,
      );

      await db.close();
    });

    test('[STEP2-7] concurrent open() shares a single connection', () async {
      final dbFile = File(
        '${tempDir.path}${Platform.pathSeparator}concurrent.db',
      );
      final db = DriftOrbitDatabase(file: dbFile);

      final results = await Future.wait([
        db.open(),
        db.open(),
        db.open(),
        db.open(),
      ]);
      expect(results, hasLength(4));
      expect(db.isOpen, isTrue);

      // All writes through the shared connection work and no lock error
      // appeared while opening concurrently.
      final repo = DriftLocalStateRepository(
        database: db,
        legacyRepository: SharedPreferencesLocalStateRepository(),
      );
      SharedPreferences.setMockInitialValues({});
      final state = await repo.load();
      expect(state, isEmpty);

      await db.close();
    });

    test('[STEP2-8] unsafe where/orderBy/limit fragments are rejected',
        () async {
      final db = DriftOrbitDatabase();
      await db.open();

      // where: statement chaining and stacked queries are refused.
      expect(
        () => db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'id = ?; DROP TABLE tasks',
          whereArgs: ['x'],
        ),
        throwsArgumentError,
      );
      // where: unknown column is refused (allowlist by table).
      expect(
        () => db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'password = ?',
          whereArgs: ['x'],
        ),
        throwsArgumentError,
      );
      // where: forbidden keyword is refused.
      expect(
        () => db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'id = ? UNION SELECT payload_json FROM app_state_snapshots',
          whereArgs: ['x'],
        ),
        throwsArgumentError,
      );
      // where: comment splice is refused.
      expect(
        () => db.query(
          OrbitDatabaseSchema.tableTasks,
          where: 'id = ? --',
          whereArgs: ['x'],
        ),
        throwsArgumentError,
      );
      // orderBy: non-column expression is refused.
      expect(
        () => db.query(
          OrbitDatabaseSchema.tableTasks,
          orderBy: 'id) ATTACH DATABASE ? AS x',
        ),
        throwsArgumentError,
      );
      expect(
        () => db.query(
          OrbitDatabaseSchema.tableTasks,
          orderBy: 'title; DROP TABLE tasks',
        ),
        throwsArgumentError,
      );
      // orderBy: unknown column is refused.
      expect(
        () => db.query(
          OrbitDatabaseSchema.tableTasks,
          orderBy: 'secret DESC',
        ),
        throwsArgumentError,
      );
      // limit: negative is refused.
      expect(
        () => db.query(OrbitDatabaseSchema.tableTasks, limit: -1),
        throwsArgumentError,
      );

      // And the table itself still exists after all the rejected calls —
      // nothing leaked through.
      final rows = await db.query(
        OrbitDatabaseSchema.tableTasks,
        where: 'workspace_id = ?',
        whereArgs: ['workspace-work'],
        orderBy: 'created_at DESC',
        limit: 5,
      );
      expect(rows, isEmpty);

      await db.close();
    });

    test('[STEP2-9] OrbitAppState flow works on top of the Drift repository',
        () async {
      SharedPreferences.setMockInitialValues({});
      final db = DriftOrbitDatabase();
      final appState = OrbitAppState(
        DriftLocalStateRepository(
          database: db,
          legacyRepository: SharedPreferencesLocalStateRepository(),
        ),
      );
      await appState.load();

      // Default demo data is present.
      expect(appState.tasks, isNotEmpty);
      expect(appState.events, isNotEmpty);

      // Task mutation round-trips through the real SQLite repository.
      final task = appState.tasks.first;
      appState.toggleTask(task.id);
      await appState.flush();
      final rows = await db.query(
        OrbitDatabaseSchema.tableTasks,
        where: 'id = ?',
        whereArgs: [task.id],
      );
      expect(rows.single['is_done'], task.done ? 0 : 1);

      // Draft mutation round-trips through the snapshot payload.
      appState.updateDraft(
        to: 'kim@example.com',
        subject: 'STEP2 review',
        body: 'Готово',
      );
      await appState.flush();
      final snapshot = await db.query(snapshotTableName);
      final payload =
          jsonDecode(snapshot.single['payload_json']! as String)
              as Map<String, Object?>;
      expect(payload['draftSubject'], 'STEP2 review');

      await db.close();
    });
  });
}
