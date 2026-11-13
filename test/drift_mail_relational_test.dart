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

const _legacyState = <String, Object?>{
  'schemaVersion': 1,
  'draftTo': 'boss@example.com',
  'draftSubject': 'Отчёт',
  'draftBody': 'Черновик',
  'currentMailFolder': 'inbox',
  'trashEmails': ['sent-2'],
  'mailAccounts': [
    {
      'id': 'acc-1',
      'name': 'Рабочая',
      'email': 'work@example.com',
      'providerType': 'gmail',
      'incomingHost': 'imap.gmail.com',
      'incomingPort': 993,
      'useIncomingSsl': true,
      'outgoingHost': 'smtp.gmail.com',
      'outgoingPort': 465,
      'useOutgoingSsl': true,
      'lastVerifiedAtIso': '2026-01-15T10:00:00.000Z',
      'lastLatencyMs': 42,
      'isActive': true,
      'status': 'verified',
      'isDemo': false,
    },
    {
      'id': 'acc-2',
      'name': 'Личная',
      'email': 'home@example.com',
      'providerType': 'yandex',
      'status': 'unverified',
    },
  ],
  'sentEmails': [
    {
      'id': 'sent-1',
      'recipient': 'a@b.demo',
      'subject': 'Важное письмо',
      'body': 'Тело важного письма',
      'sentAtIso': '2026-02-01T09:30:00.000Z',
      'isImportant': true,
    },
    {
      'id': 'sent-2',
      'recipient': 'c@d.demo',
      'subject': 'Удалённое письмо',
      'body': 'Тело',
      'sentAtIso': '2026-02-02T11:00:00.000Z',
      'isImportant': false,
    },
  ],
  'brainChatHistory': [
    {'id': 'brain-1', 'text': 'План готов'},
  ],
};

DriftLocalStateRepository _repo(Map<String, Object?> legacy,
    {DriftOrbitDatabase? db}) {
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

/// Simulates a STEP2-era database: state saved by the STEP2 code, which
/// wrote snapshot/tasks/events but never the mail projection or marker.
Future<DriftOrbitDatabase> _createStep2StyleDatabase(Directory dir) async {
  final dbFile = File('${dir.path}${Platform.pathSeparator}step2.db');
  final db = DriftOrbitDatabase(file: dbFile);
  final repo = _repo(_legacyState, db: db);
  final state = await repo.load();
  await repo.save(state);
  // Rewind STEP3 artifacts as if this file was written by 0.5.32+38.
  await db.delete(migrationsTableName);
  await db.delete(OrbitDatabaseSchema.tableAccounts);
  await db.delete(OrbitDatabaseSchema.tableEmails);
  return db;
}


/// STEP4: counts restricted to the user-owned sent/trash projection.
Future<int> _userEmailRows(DriftOrbitDatabase db) async {
  final rows = await db.query(
    OrbitDatabaseSchema.tableEmails,
    where: 'source_type = ?',
    whereArgs: ['user'],
  );
  return rows.length;
}

/// STEP4: marker rows filtered by name.
Future<int> _markerRows(DriftOrbitDatabase db, String name) async {
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
    tempDir = await Directory.systemTemp.createTemp('orbit_step3_test');
  });

  tearDown(() async {
    if (!tempDir.existsSync()) return;
    try {
      await tempDir.delete(recursive: true);
    } on FileSystemException {
      // A still-open database handle on a failed test keeps the file busy;
      // leaving the temp dir behind is harmless (system temp, never the
      // repository).
    }
  });

  group('DriftLocalStateRepository STEP3 (mail relational)', () {
    test('[STEP3-1] STEP2 upgrade: first load backfills accounts/emails and '
        'stamps the marker atomically', () async {
      final db = await _createStep2StyleDatabase(tempDir);

      // Precondition: STEP2-style file has no marker and empty mail tables.
      expect(await db.query(migrationsTableName), isEmpty);
      expect(await db.query(OrbitDatabaseSchema.tableAccounts), isEmpty);
      expect(await db.query(OrbitDatabaseSchema.tableEmails), isEmpty);

      final repo = _repo(<String, Object?>{}, db: db);
      final state = await repo.load();

      // Marker stamped.
      final markers = await db.query(migrationsTableName);
      final names = markers.map((m) => m['name']).toSet();
      expect(
        names,
        containsAll(<String>[
          DriftLocalStateRepository.mailMigrationMarker,
          DriftLocalStateRepository.demoInboxMigrationMarker,
        ]),
      );
      for (final marker in markers) {
        expect((marker['applied_at'] as num).toInt(), greaterThan(0));
      }

      // Relational projection filled.
      final accountRows = await db.query(OrbitDatabaseSchema.tableAccounts);
      expect(accountRows, hasLength(2));
      final acc1 = accountRows.firstWhere((r) => r['id'] == 'acc-1');
      expect(acc1['email'], 'work@example.com');
      expect(acc1['display_name'], 'Рабочая');
      expect(acc1['provider_type'], 'gmail');
      expect(acc1['sync_status'], 'verified');
      expect(
        acc1['last_sync_at'],
        DateTime.parse('2026-01-15T10:00:00.000Z').millisecondsSinceEpoch,
      );
      final acc2 = accountRows.firstWhere((r) => r['id'] == 'acc-2');
      expect(acc2['last_sync_at'], isNull);

      final emailRows = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'source_type = ?',
        whereArgs: ['user'],
        orderBy: 'id ASC',
      );
      expect(emailRows, hasLength(2));
      // STEP4 demo projection exists alongside and never mixes in.
      final demoRows = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'source_type = ?',
        whereArgs: ['demo'],
      );
      expect(demoRows, hasLength(5));
      final sent1 = emailRows.firstWhere((r) => r['id'] == 'sent-1');
      expect(sent1['folder'], 'sent');
      expect(sent1['sender'], 'work@example.com'); // active account email
      expect(sent1['account_id'], 'acc-1'); // active account id
      expect(sent1['recipient'], 'a@b.demo');
      expect(sent1['body'], sent1['preview']);
      expect(sent1['timestamp'],
          DateTime.parse('2026-02-01T09:30:00.000Z').millisecondsSinceEpoch);
      expect(sent1['is_read'], 1);
      expect(sent1['is_flagged'], 1);
      expect(sent1['has_attachments'], 0);
      final sent2 = emailRows.firstWhere((r) => r['id'] == 'sent-2');
      expect(sent2['folder'], 'trash'); // id listed in trashEmails

      // Merged state keeps JSON-only decorations loss-free.
      final accounts = (state['mailAccounts'] as List)
          .cast<Map<String, Object?>>();
      final acc1State = accounts.firstWhere((a) => a['id'] == 'acc-1');
      expect(acc1State['incomingHost'], 'imap.gmail.com');
      expect(acc1State['incomingPort'], 993);
      expect(acc1State['useIncomingSsl'], true);
      expect(acc1State['outgoingHost'], 'smtp.gmail.com');
      expect(acc1State['lastLatencyMs'], 42);
      expect(acc1State['isActive'], true);
      expect(acc1State['isDemo'], false);
      expect(acc1State['lastVerifiedAtIso'], '2026-01-15T10:00:00.000Z');
      expect((state['sentEmails'] as List), hasLength(2));
      expect((state['brainChatHistory'] as List), hasLength(1));
      expect(state['draftTo'], 'boss@example.com');

      await db.close();
    });

    test('[STEP3-2] repeated load/save keep one marker and no duplicates',
        () async {
      final db = await _createStep2StyleDatabase(tempDir);
      final repo = _repo(<String, Object?>{}, db: db);

      final first = await repo.load();
      final second = await repo.load();
      expect((second['mailAccounts'] as List).length, 2);
      expect((second['sentEmails'] as List).length, 2);
      expect(await _markerRows(db, 'mail_relational_v1'), 1);
      expect(await _markerRows(db, 'demo_inbox_relational_v1'), 1);

      await repo.save(first);
      await repo.save(second);
      expect(await _markerRows(db, 'mail_relational_v1'), 1);
      expect(await _markerRows(db, 'demo_inbox_relational_v1'), 1);
      expect(await db.query(OrbitDatabaseSchema.tableAccounts), hasLength(2));
      expect(await _userEmailRows(db), 2);

      await db.close();
    });

    test('[STEP3-3] round trip: account host/port/SSL/status/isActive, sent '
        'isImportant/Trash and draft survive close/reopen', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}rt.db');
      final db1 = DriftOrbitDatabase(file: dbFile);
      final repo1 = _repo(_legacyState, db: db1);
      final state = await repo1.load();

      final accounts = (state['mailAccounts'] as List)
          .cast<Map<String, Object?>>();
      accounts.firstWhere((a) => a['id'] == 'acc-1')['incomingHost'] =
          'imap.changed.com';
      accounts.firstWhere((a) => a['id'] == 'acc-1')['incomingPort'] = 999;
      accounts.firstWhere((a) => a['id'] == 'acc-1')['useIncomingSsl'] = false;
      accounts.firstWhere((a) => a['id'] == 'acc-1')['status'] = 'error';
      accounts.firstWhere((a) => a['id'] == 'acc-2')['isActive'] = true;
      accounts.firstWhere((a) => a['id'] == 'acc-1')['isActive'] = false;

      final sent = (state['sentEmails'] as List).cast<Map<String, Object?>>();
      sent.firstWhere((e) => e['id'] == 'sent-1')['isImportant'] = false;
      // sent-2 leaves trash (folder flips back to 'sent').
      (state['trashEmails'] as List).remove('sent-2');
      state['draftBody'] = 'Обновлённый черновик';

      await repo1.save(state);
      await db1.close();

      final db2 = DriftOrbitDatabase(file: dbFile);
      final repo2 = _repo(_legacyState, db: db2);
      final reloaded = await repo2.load();

      final acc2 = (reloaded['mailAccounts'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((a) => a['id'] == 'acc-1');
      expect(acc2['incomingHost'], 'imap.changed.com');
      expect(acc2['incomingPort'], 999);
      expect(acc2['useIncomingSsl'], false);
      expect(acc2['status'], 'error');
      // acc-2 became the active account in the snapshot; survives.
      expect(
        (reloaded['mailAccounts'] as List)
            .cast<Map<String, Object?>>()
            .firstWhere((a) => a['id'] == 'acc-2')['isActive'],
        true,
      );

      final sent1 = (reloaded['sentEmails'] as List)
          .cast<Map<String, Object?>>()
          .firstWhere((e) => e['id'] == 'sent-1');
      expect(sent1['isImportant'], false);
      // sent-2 is no longer in trash — folder set and relational agree.
      expect(reloaded['trashEmails'], isNot(contains('sent-2')));
      final sent2Row = await db2.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'id = ?',
        whereArgs: ['sent-2'],
      );
      expect(sent2Row.single['folder'], 'sent');
      expect(reloaded['draftBody'], 'Обновлённый черновик');

      await db2.close();
    });

    test('[STEP3-4] rollback: failure inside the mail projection reverts '
        'snapshot, tasks/events, mail rows and the marker', () async {
      final db = DriftOrbitDatabase();
      final repo = _repo(_legacyState, db: db);
      final loaded = await repo.load();
      expect(await _markerRows(db, 'mail_relational_v1'), 1);
      expect(await _markerRows(db, 'demo_inbox_relational_v1'), 1);

      final mutated = <String, Object?>{...loaded}
        ..['draftSubject'] = 'Не должен сохраниться'
        ..['mailAccounts'] = [
          ...(loaded['mailAccounts'] as List),
          <String, Object?>{
            'id': 'acc-new',
            'name': 'Новая',
            'email': 'new@example.com',
          },
        ];
      repo.failNextSaveMidTransaction = true;
      await expectLater(repo.save(mutated), throwsStateError);

      // Everything rolled back: no new account, no new draft, one marker.
      final after = await repo.load();
      expect(after['draftSubject'], 'Отчёт');
      expect((after['mailAccounts'] as List), hasLength(2));
      expect(await _markerRows(db, 'mail_relational_v1'), 1);
      expect(await db.query(OrbitDatabaseSchema.tableAccounts), hasLength(2));
      expect(await _userEmailRows(db), 2);

      // A failure inside the mail projection stage also rolls everything
      // back, including accounts already written in that transaction.
      final broken = <String, Object?>{...loaded}
        ..['mailAccounts'] = [
          <String, Object?>{
            'id': 'acc-bad-date',
            'name': 'Плохая дата',
            'email': 'bad@example.com',
            'lastVerifiedAtIso': 'not-a-date',
          },
        ];
      await expectLater(repo.save(broken), throwsFormatException);

      final after2 = await repo.load();
      expect((after2['mailAccounts'] as List), hasLength(2));
      expect(
        (after2['mailAccounts'] as List)
            .cast<Map<String, Object?>>()
            .map((a) => a['id']),
        isNot(contains('acc-bad-date')),
      );
      expect(await db.query(OrbitDatabaseSchema.tableAccounts), hasLength(2));
      expect(await _markerRows(db, 'mail_relational_v1'), 1);
      expect(await _markerRows(db, 'demo_inbox_relational_v1'), 1);

      await db.close();
    });

    test('[STEP3-5] empty mail lists stay empty and never re-run backfill',
        () async {
      final db = DriftOrbitDatabase();
      final repo = _repo(<String, Object?>{
        'schemaVersion': 1,
        'mailAccounts': <Object?>[],
        'sentEmails': <Object?>[],
      }, db: db);
      final state = await repo.load();
      expect((state['mailAccounts'] as List), isEmpty);
      expect((state['sentEmails'] as List), isEmpty);
      expect(await _markerRows(db, 'mail_relational_v1'), 1);
      expect(await db.query(OrbitDatabaseSchema.tableAccounts), isEmpty);
      // STEP4: DEMO projection exists for a non-empty snapshot (empty mail
      // lists are a valid mail state, not an empty state).
      expect(await _userEmailRows(db), 0);
      final demoRows = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'source_type = ?',
        whereArgs: ['demo'],
      );
      expect(demoRows, hasLength(5));

      // Repeat: no re-migration, still empty, markers stay single.
      await repo.load();
      await repo.save(state);
      expect(await _markerRows(db, 'mail_relational_v1'), 1);
      expect(await _markerRows(db, 'demo_inbox_relational_v1'), 1);
      expect(await db.query(OrbitDatabaseSchema.tableAccounts), isEmpty);

      // Genuinely empty state stays {}.
      SharedPreferences.setMockInitialValues({});
      final emptyDb = DriftOrbitDatabase();
      final emptyRepo = DriftLocalStateRepository(
        database: emptyDb,
        legacyRepository: SharedPreferencesLocalStateRepository(),
      );
      expect(await emptyRepo.load(), isEmpty);
      await emptyDb.close();

      await db.close();
    });

    test('[STEP3-6] deleted account/sent entries do not resurrect', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}del.db');
      final db1 = DriftOrbitDatabase(file: dbFile);
      final repo1 = _repo(_legacyState, db: db1);
      final state = await repo1.load();

      state['mailAccounts'] = (state['mailAccounts'] as List)
          .where((a) => (a! as Map<String, Object?>)['id'] != 'acc-2')
          .toList();
      state['sentEmails'] = (state['sentEmails'] as List)
          .where((e) => (e! as Map<String, Object?>)['id'] != 'sent-1')
          .toList();
      await repo1.save(state);
      await db1.close();

      final db2 = DriftOrbitDatabase(file: dbFile);
      final repo2 = _repo(_legacyState, db: db2);
      final reloaded = await repo2.load();
      final accountIds = (reloaded['mailAccounts'] as List)
          .cast<Map<String, Object?>>()
          .map((a) => a['id']);
      expect(accountIds, ['acc-1']);
      final sentIds = (reloaded['sentEmails'] as List)
          .cast<Map<String, Object?>>()
          .map((e) => e['id']);
      expect(sentIds, ['sent-2']);
      expect(await db2.query(OrbitDatabaseSchema.tableAccounts), hasLength(1));
      expect(await _userEmailRows(db2), 1);
      await db2.close();
    });

    test('[STEP3-7] scoped deletion keeps foreign email folders intact',
        () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}scope.db');
      final db = DriftOrbitDatabase(file: dbFile);
      // A foreign inbox row written by a future importer / OrbitDataEngine.
      final engine = OrbitDataEngine(db);
      await engine.initialize();
      await engine.saveEmail(EmailRecord(
        id: 'inbox-foreign',
        workspaceId: 'workspace-work',
        accountId: null,
        folder: 'inbox',
        sender: 'news@world.demo',
        recipient: 'me@example.com',
        subject: 'Входящее',
        preview: 'Превью',
        body: 'Полное тело',
        timestamp: DateTime.utc(2026, 3, 1),
        isRead: false,
        isFlagged: false,
        hasAttachments: false,
      ));

      final repo = _repo(_legacyState, db: db);
      final state = await repo.load();
      // Save with sent-2 removed from the state: scoped sync must delete
      // only the projection row, not the foreign inbox email.
      state['sentEmails'] = (state['sentEmails'] as List)
          .where((e) => (e! as Map<String, Object?>)['id'] != 'sent-2')
          .toList();
      await repo.save(state);

      expect(await _userEmailRows(db), 2);
      final foreign = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'id = ?',
        whereArgs: ['inbox-foreign'],
      );
      expect(foreign, hasLength(1));
      expect(foreign.single['folder'], 'inbox');

      await db.close();
    });

    test('[STEP3-8] corrupt snapshot: explicit error, no partial rows, '
        'backup kept, reset clears Drift only', () async {
      final corruptJson =
          '{"schemaVersion": 1, "mailAccounts": [{"id": 1, "name": "x", '
          '"email": "y"}]}';
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocalStateRepository.storageKey: corruptJson,
      });
      final db = DriftOrbitDatabase();
      final repo = DriftLocalStateRepository(
        database: db,
        legacyRepository: SharedPreferencesLocalStateRepository(),
      );

      await expectLater(repo.load(), throwsA(isA<OrbitCorruptDataException>()));
      // No partial rows, no marker.
      expect(await db.query(snapshotTableName), isEmpty);
      expect(await db.query(migrationsTableName), isEmpty);
      expect(await db.query(OrbitDatabaseSchema.tableAccounts), isEmpty);
      expect(await db.query(OrbitDatabaseSchema.tableEmails), isEmpty);

      // The legacy repository keeps the corrupt raw in its backup slot by
      // design (nothing is lost); reset clears Drift only.
      await repo.resetCorruptData();
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SharedPreferencesLocalStateRepository.storageKey),
        corruptJson,
      );
      expect(
        prefs.getString(SharedPreferencesLocalStateRepository.backupKey),
        corruptJson,
      );
      await db.close();
    });

    test('[STEP3-9] relational-only rows surface in legacy lists; '
        'migrations-table allowlist rejects unsafe fragments', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}ro.db');
      final db = DriftOrbitDatabase(file: dbFile);
      final repo = _repo(_legacyState, db: db);
      final state = await repo.load();
      expect((state['sentEmails'] as List), hasLength(2));

      // Write a relational-only sent email straight through the engine.
      final engine = OrbitDataEngine(db);
      await engine.initialize();
      await engine.saveEmail(EmailRecord(
        id: 'sent-direct',
        workspaceId: 'workspace-work',
        accountId: 'acc-1',
        folder: 'sent',
        sender: 'work@example.com',
        recipient: 'direct@dest.demo',
        subject: 'Напрямую',
        preview: 'Превью',
        body: 'Напрямую через engine',
        timestamp: DateTime.utc(2026, 4, 1, 12, 30),
        isRead: true,
        isFlagged: true,
        hasAttachments: false,
      ));

      final reloaded = await repo.load();
      final sent = (reloaded['sentEmails'] as List)
          .cast<Map<String, Object?>>();
      expect(sent, hasLength(3));
      final direct = sent.firstWhere((e) => e['id'] == 'sent-direct');
      expect(direct['recipient'], 'direct@dest.demo');
      expect(direct['subject'], 'Напрямую');
      expect(direct['body'], 'Напрямую через engine');
      expect(direct['isImportant'], true);
      // Deterministic ISO-8601 derived from the timestamp.
      expect(
        direct['sentAtIso'],
        DateTime.fromMillisecondsSinceEpoch(
          DateTime.utc(2026, 4, 1, 12, 30).millisecondsSinceEpoch,
        ).toIso8601String(),
      );

      // The marker table itself is allowlisted: unsafe fragments refused.
      expect(
        () => db.query(
          migrationsTableName,
          where: 'name = ?; DROP TABLE app_state_migrations',
          whereArgs: [DriftLocalStateRepository.mailMigrationMarker],
        ),
        throwsArgumentError,
      );
      expect(
        () => db.query(
          migrationsTableName,
          where: 'payload_json = ?',
          whereArgs: ['x'],
        ),
        throwsArgumentError,
      );

      await db.close();
    });

    test('[STEP3-10] existing app flow: sendEmail, trash/restore, account '
        'and draft via real SQLite without network', () async {
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

      // Local sendEmail (DEMO scenario, no network).
      final sentEntry = appState.sendEmail(
        const DraftState(
          to: 'dest@demo.com',
          subject: 'STEP3 письмо',
          body: 'Тело письма',
        ),
      );
      await appState.flush();
      expect(sentEntry.recipient, 'dest@demo.com');

      // Trash and restore round-trips through the relational folder.
      appState.moveToFolder(sentEntry.id, OrbitMailFolder.trash);
      await appState.flush();
      var row = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'id = ?',
        whereArgs: [sentEntry.id],
      );
      expect(row.single['folder'], 'trash');
      appState.restoreFromTrash(sentEntry.id);
      await appState.flush();
      row = await db.query(
        OrbitDatabaseSchema.tableEmails,
        where: 'id = ?',
        whereArgs: [sentEntry.id],
      );
      expect(row.single['folder'], 'sent');

      // Account add/remove flows through the accounts projection.
      appState.addMailAccount(
        OrbitMailAccount(
          id: 'acc-flow',
          name: 'Flow',
          email: 'flow@example.com',
          status: OrbitMailAccountStatus.verified,
        ),
      );
      await appState.flush();
      final accRows = await db.query(
        OrbitDatabaseSchema.tableAccounts,
        where: 'id = ?',
        whereArgs: ['acc-flow'],
      );
      expect(accRows, hasLength(1));
      appState.removeMailAccount('acc-flow');
      await appState.flush();
      expect(
        await db.query(
          OrbitDatabaseSchema.tableAccounts,
          where: 'id = ?',
          whereArgs: ['acc-flow'],
        ),
        isEmpty,
      );

      await db.close();
    });

    test('[STEP3-11] concurrent migration creates one marker, no '
        'duplicates and no competing connections', () async {
      final dbFile = File('${tempDir.path}${Platform.pathSeparator}conc.db');
      final db = DriftOrbitDatabase(file: dbFile);
      final repo = _repo(_legacyState, db: db);

      final states = await Future.wait([
        repo.load(),
        repo.load(),
        repo.load(),
        repo.load(),
      ]);
      for (final state in states) {
        expect((state['mailAccounts'] as List).length, 2);
        expect((state['sentEmails'] as List).length, 2);
      }
      expect(await _markerRows(db, 'mail_relational_v1'), 1);
      expect(await _markerRows(db, 'demo_inbox_relational_v1'), 1);
      expect(await db.query(OrbitDatabaseSchema.tableAccounts), hasLength(2));
      expect(await _userEmailRows(db), 2);
      await db.close();
    });
  });
}
