import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/database/orbit_database.dart';
import 'package:orbit_visual_lab/data/demo_data.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/models/email_record.dart';
import 'package:orbit_visual_lab/data/orbit_corrupt_data.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/state/draft_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _baseState = <String, Object?>{
  'schemaVersion': 1,
  'draftTo': 'x@y.demo',
  'draftSubject': 'S',
  'draftBody': 'B',
  'currentMailFolder': 'inbox',
  'readEmails': ['weekly-plan'],
  'starredEmails': ['design-review'],
  'unstarredEmails': <String>[],
  'trashEmails': <String>[],
  'deletedEmails': <String>[],
  'spamEmails': <String>[],
  'archiveEmails': ['project-update'],
  'outboxEmails': <String>[],
  'permanentlyDeletedEmails': <String>[],
  'mailAccounts': [
    {
      'id': 'acc-1',
      'name': 'Основная',
      'email': 'me@example.com',
      'providerType': 'gmail',
      'status': 'verified',
      'isActive': true,
    },
  ],
  'sentEmails': [
    {
      'id': 'sent-1',
      'recipient': 'r@dest.demo',
      'subject': 'Sent subject',
      'body': 'Sent body',
      'sentAtIso': '2026-03-01T08:00:00.000Z',
      'isImportant': false,
    },
  ],
};

DriftLocalStateRepository _repo(
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

Future<int> _userEmailRows(DriftOrbitDatabase db) async {
  final rows = await db.query(
    OrbitDatabaseSchema.tableEmails,
    where: 'source_type = ?',
    whereArgs: ['user'],
  );
  return rows.length;
}

Future<int> _demoEmailRows(DriftOrbitDatabase db) async {
  final rows = await db.query(
    OrbitDatabaseSchema.tableEmails,
    where: 'source_type = ?',
    whereArgs: ['demo'],
  );
  return rows.length;
}

Future<int> _markers(DriftOrbitDatabase db, String name) async {
  final rows = await db.query(
    migrationsTableName,
    where: 'name = ?',
    whereArgs: [name],
  );
  return rows.length;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('orbit_step4_test');
  });

  tearDown(() async {
    if (!tempDir.existsSync()) return;
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // A failed test can leave an open DB handle; system temp is harmless.
    }
  });

  group('DriftLocalStateRepository STEP4 (DEMO mail relational)', () {
    test('[STEP4-1] STEP3 schema upgrade adds source_type once, keeps '
        'existing rows user', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}up.db');
      // Build a STEP3-era file by removing the column the way the old
      // version had it: create a fresh DB, then rebuild the table without
      // source_type via direct SQL through a second core is overkill —
      // instead simulate by saving state with the current code, dropping
      // and re-adding the column with a NOT NULL DEFAULT 'user'.
      final db = DriftOrbitDatabase(file: dbFile);
      final repo = _repo(_baseState, db: db);
      final state = await repo.load();
      await repo.save(state);
      // Undo STEP4 artifacts to emulate a STEP3 file.
      await db.delete(
        OrbitDatabaseSchema.tableEmails,
        where: 'source_type = ?',
        whereArgs: ['demo'],
      );
      await db.delete(
        migrationsTableName,
        where: 'name = ?',
        whereArgs: [DriftLocalStateRepository.demoInboxMigrationMarker],
      );
      // Copy rows aside, drop table, recreate without the column, restore.
      final rows = await db.query(OrbitDatabaseSchema.tableEmails);
      await db.executeRawForTesting('DROP TABLE emails');
      await db.executeRawForTesting('''
        CREATE TABLE emails (
          id TEXT PRIMARY KEY,
          workspace_id TEXT NOT NULL,
          account_id TEXT,
          folder TEXT NOT NULL,
          sender TEXT NOT NULL,
          recipient TEXT NOT NULL,
          subject TEXT NOT NULL,
          preview TEXT NOT NULL,
          body TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          is_read INTEGER NOT NULL,
          is_flagged INTEGER NOT NULL,
          has_attachments INTEGER NOT NULL,
          FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
        );
      ''');
      for (final row in rows) {
        final map = <String, Object?>{...row}..remove('source_type');
        final columns = map.keys.toList();
        await db.updateRawForTesting(
          'INSERT INTO emails (${columns.join(', ')}) '
          'VALUES (${List.filled(columns.length, '?').join(', ')})',
          [for (final c in columns) map[c]],
        );
      }
      await db.close();

      // Reopen: the additive upgrade must add the column exactly once and
      // existing rows stay 'user' with untouched data.
      final reopened = DriftOrbitDatabase(file: dbFile);
      await reopened.open();
      expect(await _markers(reopened, 'mail_relational_v1'), 1);

      final rowsAfter = await reopened.query(
        OrbitDatabaseSchema.tableEmails,
        orderBy: 'id ASC',
      );
      expect(rowsAfter, hasLength(1));
      expect(rowsAfter.single['id'], 'sent-1');
      expect(rowsAfter.single['source_type'], 'user');
      expect(rowsAfter.single['subject'], 'Sent subject');

      // Second open does not attempt the ALTER again (no error, no dup).
      await reopened.close();
      final again = DriftOrbitDatabase(file: dbFile);
      await again.open();
      final columns = await again.selectRawForTesting('PRAGMA table_info(emails)');
      final sourceTypeColumns = columns
          .where((r) => r['name'] == 'source_type')
          .length;
      expect(sourceTypeColumns, 1);
      await again.close();
    });

    test('[STEP4-2] DEMO backfill creates five rows with §7 defaults and '
        'overrides, one marker', () async {
      final db = DriftOrbitDatabase();
      final repo = _repo(_baseState, db: db);
      await repo.load();

      final demoRows = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'source_type = ?',
        whereArgs: ['demo'],
        orderBy: 'id ASC',
      );
      expect(demoRows, hasLength(5));
      final ids = demoRows.map((r) => r['id']).toSet();
      expect(
        ids,
        {'weekly-plan', 'design-review', 'project-update', 'research-notes',
         'focus-notes'},
      );

      // weekly-plan: readEmails=['weekly-plan'] → is_read=1; builtin
      // starred=true with no unstarred override → is_flagged=1.
      final weekly = demoRows.firstWhere((r) => r['id'] == 'weekly-plan');
      expect(weekly['folder'], 'inbox');
      expect(weekly['is_read'], 1);
      expect(weekly['is_flagged'], 1);
      // research-notes is builtin-unstarred → is_flagged=0.
      final research = demoRows.firstWhere((r) => r['id'] == 'research-notes');
      expect(research['is_flagged'], 0);
      // design-review: starredEmails → is_flagged=1; inbox.
      final design = demoRows.firstWhere((r) => r['id'] == 'design-review');
      expect(design['is_flagged'], 1);
      expect(design['folder'], 'inbox');
      // project-update: archiveEmails → archive; timestamp deterministically 0.
      final project = demoRows.firstWhere((r) => r['id'] == 'project-update');
      expect(project['folder'], 'archive');
      expect(project['timestamp'], 0);
      // All demo rows carry source_type='demo' and workspace scoping.
      for (final row in demoRows) {
        expect(row['source_type'], 'demo');
        expect(row['workspace_id'], 'workspace-work');
        expect(row['account_id'], 'acc-1');
      }

      expect(await _markers(db, 'demo_inbox_relational_v1'), 1);
      expect(await _markers(db, 'mail_relational_v1'), 1);

      await db.close();
    });

    test('[STEP4-3] idempotency: repeated open/load/save do not duplicate '
        'rows or re-run ALTER/backfill', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}idem.db');
      final db1 = DriftOrbitDatabase(file: dbFile);
      final repo1 = _repo(_baseState, db: db1);
      final state = await repo1.load();
      await repo1.save(state);
      await db1.close();

      final db2 = DriftOrbitDatabase(file: dbFile);
      final repo2 = _repo(_baseState, db: db2);
      await repo2.load();
      await repo2.save(state);
      await repo2.load();

      expect(await _demoEmailRows(db2), 5);
      expect(await _userEmailRows(db2), 1);
      expect(await _markers(db2, 'demo_inbox_relational_v1'), 1);
      expect(await _markers(db2, 'mail_relational_v1'), 1);
      final cols = await db2.selectRawForTesting('PRAGMA table_info(emails)');
      expect(
        cols.where((r) => r['name'] == 'source_type').length,
        1,
      );
      await db2.close();
    });

    test('[STEP4-4] round trip: markRead/star/unstar/folder moves/draft '
        'survive close/reopen', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}rt.db');
      final db1 = DriftOrbitDatabase(file: dbFile);
      final repo1 = _repo(_baseState, db: db1);
      final state = await repo1.load();

      // research-notes: unread by default (not in readEmails) → mark read.
      // research-notes is builtin-read; keeping it in readEmails is legal.
      state['readEmails'] = [...(state['readEmails'] as List), 'research-notes'];
      // weekly-plan: builtin starred=true → unstar is recorded via the
      // unstarredEmails marker set.
      state['unstarredEmails'] = ['weekly-plan'];
      // design-review: builtin unstarred → user star goes to starredEmails.
      state['starredEmails'] = [
        ...(state['starredEmails'] as List),
        'design-review',
      ];
      // focus-notes: archive it.
      state['archiveEmails'] = [
        ...(state['archiveEmails'] as List),
        'focus-notes',
      ];
      state['draftBody'] = 'RT draft';

      await repo1.save(state);
      await db1.close();

      final db2 = DriftOrbitDatabase(file: dbFile);
      final repo2 = _repo(_baseState, db: db2);
      final reloaded = await repo2.load();

      final research = await db2.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = ? AND source_type = 'demo'",
        whereArgs: ['research-notes'],
      );
      expect(research.single['is_read'], 1);

      final weekly = await db2.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = ? AND source_type = 'demo'",
        whereArgs: ['weekly-plan'],
      );
      // weekly-plan unstarred → flag cleared.
      expect(weekly.single['is_flagged'], 0);
      expect(reloaded['unstarredEmails'], contains('weekly-plan'));

      final design = await db2.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = ? AND source_type = 'demo'",
        whereArgs: ['design-review'],
      );
      // design-review user-starred → flag set, set mirrors it.
      expect(design.single['is_flagged'], 1);
      expect(reloaded['starredEmails'], contains('design-review'));

      final focus = await db2.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = ? AND source_type = 'demo'",
        whereArgs: ['focus-notes'],
      );
      expect(focus.single['folder'], 'archive');

      expect(reloaded['draftBody'], 'RT draft');
      // Per the restore contract, readEmails carries only builtin-unread
      // demo mails whose relational is_read=1 (weekly-plan here).
      expect(reloaded['readEmails'], contains('weekly-plan'));
      await db2.close();
    });

    test('[STEP4-5] permanent tombstone: folder=permanently_deleted, hidden, '
        'never resurrects after restart', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}tomb.db');
      final db1 = DriftOrbitDatabase(file: dbFile);
      final repo1 = _repo(_baseState, db: db1);
      final state = await repo1.load();

      state['permanentlyDeletedEmails'] = ['weekly-plan'];
      state['trashEmails'] = (state['trashEmails'] as List)
          .where((id) => id != 'weekly-plan')
          .toList();
      await repo1.save(state);
      await db1.close();

      final db2 = DriftOrbitDatabase(file: dbFile);
      final repo2 = _repo(_baseState, db: db2);
      final reloaded = await repo2.load();

      final weekly = await db2.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = ? AND source_type = 'demo'",
        whereArgs: ['weekly-plan'],
      );
      expect(weekly.single['folder'], 'permanently_deleted');
      expect(
        reloaded['permanentlyDeletedEmails'],
        contains('weekly-plan'),
      );
      // Repeated load keeps the tombstone.
      final again = await repo2.load();
      expect(again['permanentlyDeletedEmails'], contains('weekly-plan'));
      await db2.close();
    });

    test('[STEP4-6] ownership regression: DEMO trash never lands in '
        'sentEmails and neither projection deletes the other', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}own.db');
      final db = DriftOrbitDatabase(file: dbFile);
      final repo = _repo(_baseState, db: db);
      final state = await repo.load();

      // Put a DEMO mail into trash.
      state['trashEmails'] = [...(state['trashEmails'] as List), 'weekly-plan'];
      await repo.save(state);
      final reloaded = await repo.load();

      // DEMO trash must NOT appear in sentEmails.
      final sentIds = (reloaded['sentEmails'] as List)
          .cast<Map<String, Object?>>()
          .map((e) => e['id']);
      expect(sentIds, isNot(contains('weekly-plan')));
      // DEMO trash row still exists after a user-sent save cycle.
      final weekly = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = ? AND source_type = 'demo'",
        whereArgs: ['weekly-plan'],
      );
      expect(weekly.single['folder'], 'trash');
      // And the user sent row survives a DEMO-including save.
      expect(await _userEmailRows(db), 1);
      final userSent = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'sent-1'",
      );
      expect(userSent, hasLength(1));
      await db.close();
    });

    test('[STEP4-7] full rollback: mail-stage error reverts snapshot, '
        'tasks/events, accounts, user/demo mail and both markers', () async {
      final db = DriftOrbitDatabase();
      final repo = _repo(_baseState, db: db);
      final loaded = await repo.load();
      expect(await _markers(db, 'mail_relational_v1'), 1);
      expect(await _markers(db, 'demo_inbox_relational_v1'), 1);

      final mutated = <String, Object?>{...loaded}
        ..['draftSubject'] = 'rollback probe'
        ..['tasks'] = [
          <String, Object?>{
            'id': 'task-rb',
            'title': 'RB',
            'project': null,
            'due': null,
            'done': false,
            'priority': 0,
          },
        ];
      repo.failNextSaveMidTransaction = true;
      await expectLater(repo.save(mutated), throwsStateError);

      final after = await repo.load();
      expect(after['draftSubject'], 'S');
      expect(await db.query(OrbitDatabaseSchema.tableTasks), isEmpty);
      expect(await _markers(db, 'mail_relational_v1'), 1);
      expect(await _markers(db, 'demo_inbox_relational_v1'), 1);
      expect(await _demoEmailRows(db), 5);
      expect(await _userEmailRows(db), 1);
      await db.close();
    });

    test('[STEP4-8] genuinely empty snapshot: no DEMO rows, one marker, {} '
        'returned', () async {
      final db = DriftOrbitDatabase();
      final repo = _repo(<String, Object?>{}, db: db);
      final state = await repo.load();
      expect(state, isEmpty);
      expect(await _demoEmailRows(db), 0);
      expect(await _markers(db, 'demo_inbox_relational_v1'), 1);
      // Second load: no backfill, still {}.
      expect(await repo.load(), isEmpty);
      expect(await _demoEmailRows(db), 0);
      expect(await _markers(db, 'demo_inbox_relational_v1'), 1);
      await db.close();
    });

    test('[STEP4-9] corrupt snapshot: explicit error, no partial DEMO rows '
        'or marker, backup kept, reset clears Drift only', () async {
      final corruptJson =
          '{"schemaVersion": 1, "readEmails": "not-a-list"}';
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocalStateRepository.storageKey: corruptJson,
      });
      final db = DriftOrbitDatabase();
      final repo = DriftLocalStateRepository(
        database: db,
        legacyRepository: SharedPreferencesLocalStateRepository(),
      );
      await expectLater(repo.load(), throwsA(isA<OrbitCorruptDataException>()));
      expect(await db.query(OrbitDatabaseSchema.tableEmails), isEmpty);
      expect(await db.query(migrationsTableName), isEmpty);

      await repo.resetCorruptData();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SharedPreferencesLocalStateRepository.storageKey),
        corruptJson,
      );
      expect(await db.query(migrationsTableName), isEmpty);
      await db.close();
    });

    test('[STEP4-10] relational authority: DEMO read/folder changes reflect '
        'in legacy sets; unknown non-demo ids are preserved', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}auth.db');
      final db = DriftOrbitDatabase(file: dbFile);
      final repo = _repo(_baseState, db: db);
      final state = await repo.load();

      // Unknown ids in every set must survive the load round trip.
      state['readEmails'] = [...(state['readEmails'] as List), 'future-mail'];
      state['starredEmails'] = [
        ...(state['starredEmails'] as List),
        'future-star',
      ];
      state['permanentlyDeletedEmails'] = [
        ...(state['permanentlyDeletedEmails'] as List),
        'future-dead',
      ];
      await repo.save(state);
      final first = await repo.load();
      expect(first['readEmails'], contains('future-mail'));
      expect(first['starredEmails'], contains('future-star'));
      expect(first['permanentlyDeletedEmails'], contains('future-dead'));

      // Direct relational change: design-review (builtin unread, inbox)
      // becomes read + archived via the relational columns only.
      await db.update(
        OrbitDatabaseSchema.tableEmails,
        {'is_read': 1, 'folder': 'archive'},
        where: "id = ? AND source_type = 'demo'",
        whereArgs: ['design-review'],
      );
      final reloaded = await repo.load();
      // design-review was unread-by-default and NOT in readEmails of this
      // state; the relational is_read=1 must surface it in readEmails.
      expect(reloaded['readEmails'], contains('design-review'));
      expect(reloaded['archiveEmails'], contains('design-review'));
      // Unknown ids still present.
      expect(reloaded['readEmails'], contains('future-mail'));
      expect(reloaded['permanentlyDeletedEmails'], contains('future-dead'));
      await db.close();
    });

    test('[STEP4-11] existing app flow: markRead, toggleStarred, '
        'moveToFolder, restore, Empty Trash, sendEmail and drafts via real '
        'SQLite', () async {
      SharedPreferences.setMockInitialValues({});
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}flow.db');
      final db = DriftOrbitDatabase(file: dbFile);
      final appState = OrbitAppState(
        DriftLocalStateRepository(
          database: db,
          legacyRepository: SharedPreferencesLocalStateRepository(),
        ),
      );
      await appState.load();

      // research-notes is unread by default; markRead flips it.
      appState.markRead('research-notes');
      await appState.flush();
      final demoRow = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'research-notes' AND source_type = 'demo'",
      );
      expect(demoRow.single['is_read'], 1);

      // Star / unstar cycle on focus-notes.
      appState.toggleStarred('focus-notes', false);
      await appState.flush();
      final starredRow = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'focus-notes' AND source_type = 'demo'",
      );
      final starredValue = (starredRow.single['is_flagged'] as num).toInt();
      appState.toggleStarred('focus-notes', false);
      await appState.flush();
      final unstarredRow = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'focus-notes' AND source_type = 'demo'",
      );
      expect(
        (unstarredRow.single['is_flagged'] as num).toInt(),
        isNot(starredValue),
      );

      // moveToFolder design-review → trash → restore → archive.
      appState.moveToFolder('design-review', OrbitMailFolder.trash);
      await appState.flush();
      var row = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'design-review' AND source_type = 'demo'",
      );
      expect(row.single['folder'], 'trash');
      appState.restoreFromTrash('design-review');
      await appState.flush();
      row = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'design-review' AND source_type = 'demo'",
      );
      expect(row.single['folder'], 'inbox');

      // Local sendEmail → user projection row.
      final sent = appState.sendEmail(
        const DraftState(
          to: 'step4@demo.com',
          subject: 'STEP4 sent',
          body: 'Body',
        ),
      );
      await appState.flush();
      final sentRow = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'id = ? AND source_type = ?',
        whereArgs: [sent.id, 'user'],
      );
      expect(sentRow, hasLength(1));
      expect(sentRow.single['folder'], 'sent');

      // Empty Trash on a demo trashed mail → tombstone.
      appState.moveToFolder('project-update', OrbitMailFolder.trash);
      await appState.flush();
      appState.emptyTrash();
      await appState.flush();
      final tomb = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'project-update' AND source_type = 'demo'",
      );
      expect(tomb.single['folder'], 'permanently_deleted');

      // Draft round trip.
      appState.updateDraft(to: 'd@e.demo', subject: 'STEP4 draft', body: 'B');
      await appState.flush();
      final snapshot = await db.query(
        snapshotTableName,
        where: 'id = ?',
        whereArgs: [DriftLocalStateRepository.snapshotRowId],
      );
      final payload =
          jsonDecode(snapshot.single['payload_json']! as String)
              as Map<String, Object?>;
      expect(payload['draftSubject'], 'STEP4 draft');

      await db.close();
    });

    test('[STEP4-12] DataEngine read model: inbox sees DEMO rows, sent '
        'queries exclude DEMO, EmailRecord.fromMap works with the new '
        'column', () async {
      final db = DriftOrbitDatabase();
      final repo = _repo(_baseState, db: db);
      await repo.load();
      final engine = OrbitDataEngine(db);
      await engine.initialize();

      final inbox = await engine.getEmails(folder: 'inbox');
      expect(
        inbox.map((e) => e.id),
        containsAll(['weekly-plan', 'design-review']),
      );
      final sentEngine = await engine.getEmails(folder: 'sent');
      expect(
        sentEngine.map((e) => e.id),
        isNot(contains(anyOf('weekly-plan', 'design-review'))),
      );
      // EmailRecord.fromMap tolerates the extra column (toMap has none).
      final record = EmailRecord.fromMap({
        'id': 'x',
        'workspace_id': 'workspace-work',
        'folder': 'inbox',
        'sender': 's',
        'recipient': 'r',
        'subject': 'subj',
        'preview': 'p',
        'body': 'b',
        'timestamp': 1,
        'is_read': 1,
        'is_flagged': 0,
        'has_attachments': 0,
        'source_type': 'demo',
      });
      expect(record.id, 'x');
      await db.close();
    });

    test('[STEP4-13] concurrent migration: parallel loads keep single '
        'marker and no duplicates', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}conc.db');
      final db = DriftOrbitDatabase(file: dbFile);
      final repo = _repo(_baseState, db: db);
      final states = await Future.wait([
        repo.load(),
        repo.load(),
        repo.load(),
      ]);
      for (final state in states) {
        expect((state['mailAccounts'] as List).length, 1);
      }
      expect(await _markers(db, 'demo_inbox_relational_v1'), 1);
      expect(await _markers(db, 'mail_relational_v1'), 1);
      expect(await _demoEmailRows(db), 5);
      expect(await _userEmailRows(db), 1);
      await db.close();
    });

    test('[STEP4-14] source conflict: same id with different source_type '
        'fails explicitly and rolls back, foreign row survives', () async {
      final db = DriftOrbitDatabase();
      final repo = _repo(_baseState, db: db);
      await repo.load();

      // State that would write a user 'weekly-plan' row while a demo row
      // with that id already exists.
      final conflict = <String, Object?>{
        ..._baseState,
        'sentEmails': [
          {
            'id': 'weekly-plan',
            'recipient': 'r@x.demo',
            'subject': 'Hijack',
            'body': 'Hijack body',
            'sentAtIso': '2026-05-01T00:00:00.000Z',
            'isImportant': false,
          },
        ],
      };
      await expectLater(repo.save(conflict), throwsFormatException);

      // The demo row survives untouched; no user row was created.
      final weekly = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'weekly-plan' AND source_type = 'demo'",
      );
      expect(weekly, hasLength(1));
      expect(await _userEmailRows(db), 1);
      final userWeekly = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: "id = 'weekly-plan' AND source_type = 'user'",
      );
      expect(userWeekly, isEmpty);
      expect(await _markers(db, 'mail_relational_v1'), 1);
      expect(await _markers(db, 'demo_inbox_relational_v1'), 1);
      await db.close();
    });
  });
}
