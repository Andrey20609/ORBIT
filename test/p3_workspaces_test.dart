import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/core/module_interfaces.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/models/note_record.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/services/mail/imap_body_cache_store.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/widgets/orbit_workspace_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<OrbitAppState> _stateOnFileSQLite(
  DriftLocalStateRepository repo, [
  OrbitSecretStore? store,
]) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final state = OrbitAppState(repo, store ?? MemoryOrbitSecretStore());
  await state.load();
  return state;
}

Future<DriftLocalStateRepository> _freshRepo(
  Directory tempDir,
  String name,
) async {
  return DriftLocalStateRepository(
    database: DriftOrbitDatabase(
      file: File('${tempDir.path}${Platform.pathSeparator}$name.sqlite'),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('P3-01 workspaces foundation (file SQLite)', () {
    test('[W1] дефолтные пространства и активный по умолчанию, '
        'персистентность между рестартами', () async {
      final tempDir = await Directory.systemTemp.createTemp('p3_w1');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = await _freshRepo(tempDir, 'w1');
      final sharedStore = MemoryOrbitSecretStore();
      final state = await _stateOnFileSQLite(repo, sharedStore);

      // Дефолты засеяны drift'ом; snapshot пуст — берутся дефолты.
      expect(state.workspaces.map((w) => w.id).toList(),
          ['workspace-work', 'workspace-personal', 'workspace-projects']);
      expect(state.activeWorkspaceId, 'workspace-work');

      // Переключение + персистентность: рестарт сохраняет выбор.
      expect(await state.switchWorkspace('workspace-personal'), isTrue);
      await state.flush();
      final reloaded = await _stateOnFileSQLite(repo, sharedStore);
      expect(reloaded.activeWorkspaceId, 'workspace-personal');
      // Дефолтные пространства на месте.
      expect(reloaded.workspaces.length, 3);
    });

    test('[W2] createWorkspace: валидация (пусто/дубль/длина) и успех '
        'с переключением', () async {
      final tempDir = await Directory.systemTemp.createTemp('p3_w2');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = await _freshRepo(tempDir, 'w2');
      final state = await _stateOnFileSQLite(repo);

      // Пустое имя.
      expect(await state.createWorkspace('   '), isNotNull);
      // Дубль (case-insensitive).
      expect(await state.createWorkspace('РАБОТА'), isNotNull);
      // Слишком длинное имя.
      expect(
        await state.createWorkspace('x' * 41),
        isNotNull,
      );
      expect(state.workspaces.length, 3);

      // Успех: создано и переключено.
      expect(await state.createWorkspace('Мой проект'), isNull);
      expect(state.workspaces.length, 4);
      expect(state.activeWorkspaceId,
          state.workspaces.last.id);
      final created = state.workspaces.last;
      expect(created.name, 'Мой проект');
      expect(created.type, 'personal');

      await state.flush();
      final snapshot = await repo.load();
      final wsJson = snapshot['workspaces'] as List<dynamic>;
      expect(wsJson.length, 4);
      expect(snapshot['activeWorkspaceId'], created.id);
    });

    test('[W3] switchWorkspace: несуществующий id отклоняется',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('p3_w3');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = await _freshRepo(tempDir, 'w3');
      final state = await _stateOnFileSQLite(repo);
      expect(await state.switchWorkspace('workspace-ghost'), isFalse);
      expect(state.activeWorkspaceId, 'workspace-work');
    });

    test('[W4] production SQLite: строки workspaces соответствуют '
        'списку (созданное записано в таблицу)', () async {
      final tempDir = await Directory.systemTemp.createTemp('p3_w4');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = await _freshRepo(tempDir, 'w4');
      final state = await _stateOnFileSQLite(repo);
      expect(await state.createWorkspace('SQLite проверка'), isNull);

      final db = await repo.outboxDatabase();
      final rows = await db.query(
        'workspaces',
        orderBy: 'created_at ASC',
      );
      final ids = rows.map((r) => r['id']).toList();
      expect(ids, containsAll(['workspace-work', 'workspace-personal']));
      expect(
        rows.any((r) => r['name'] == 'SQLite проверка'),
        isTrue,
        reason: 'созданное пространство записано в production SQLite',
      );
    });

    test('[W5] изоляция заметок по пространству: A и B не смешиваются, '
        'рестарт сохраняет', () async {
      final tempDir = await Directory.systemTemp.createTemp('p3_w5');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = await _freshRepo(tempDir, 'w5');
      final state = await _stateOnFileSQLite(repo);
      await state.createWorkspace('Заметки B');
      final wsB = state.activeWorkspaceId;
      final db = await repo.outboxDatabase();

      // Заметка в Workspace A (дефолт).
      final engine = OrbitDataEngine(db);
      engine.setActiveWorkspace('workspace-work');
      await engine.saveNote(
        NoteRecord(
          id: 'note-a-1',
          workspaceId: 'workspace-work',
          title: 'Заметка A',
          content: 'Содержимое A',
          updatedAt: DateTime.utc(2026, 11, 15, 10),
        ),
      );

      // Заметка в Workspace B.
      engine.setActiveWorkspace(wsB);
      await engine.saveNote(
        NoteRecord(
          id: 'note-b-1',
          workspaceId: wsB,
          title: 'Заметка B',
          content: 'Содержимое B',
          updatedAt: DateTime.utc(2026, 11, 15, 11),
        ),
      );

      // Фильтрация: активный B -> только заметки B.
      engine.setActiveWorkspace(wsB);
      final notesB = await engine.getNotes(workspaceId: wsB);
      expect(notesB.map((NoteRecord n) => n.id), ['note-b-1']);

      // Возврат в A -> данные A на месте.
      engine.setActiveWorkspace('workspace-work');
      final notesA = await engine.getNotes(workspaceId: 'workspace-work');
      expect(notesA.map((NoteRecord n) => n.id), ['note-a-1']);

      // Рестарт: новый движок над той же БД — обе заметки на месте,
      // фильтрация работает.
      final engine2 = OrbitDataEngine(db);
      engine2.setActiveWorkspace('workspace-work');
      final notesA2 = await engine2.getNotes(workspaceId: 'workspace-work');
      expect(notesA2.map((NoteRecord n) => n.id), ['note-a-1']);
      engine2.setActiveWorkspace(wsB);
      final notesB2 = await engine2.getNotes(workspaceId: wsB);
      expect(notesB2.map((NoteRecord n) => n.id), ['note-b-1']);
    });

    test('[W6] deleteWorkspace: дефолт защищён; активное с fallback; '
        'несуществующее — ошибка', () async {
      final tempDir = await Directory.systemTemp.createTemp('p3_w6');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = await _freshRepo(tempDir, 'w6');
      final state = await _stateOnFileSQLite(repo);

      // Дефолт защищён.
      expect(
        await state.deleteWorkspace('workspace-work'),
        contains('нельзя'),
      );
      expect(state.workspaces.length, 3);

      // Удаление активного не-дефолтного: fallback на дефолт.
      await state.switchWorkspace('workspace-personal');
      expect(
        await state.deleteWorkspace('workspace-personal'),
        isNull,
      );
      expect(state.workspaces.length, 2);
      expect(state.activeWorkspaceId, 'workspace-work');

      // Несуществующее — sanitized ошибка.
      expect(
        await state.deleteWorkspace('workspace-ghost'),
        contains('не найдено'),
      );
    });

    test('[W7] почтовые данные не затрагиваются workspace-операциями',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('p3_w7');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = await _freshRepo(tempDir, 'w7');
      final sharedStore = MemoryOrbitSecretStore();
      final state = await _stateOnFileSQLite(repo, sharedStore);
      await state.createWorkspace('Проверка почты');
      await state.deleteWorkspace('workspace-personal');
      await state.flush();

      // Кэш тела и controlled recipient не затронуты (это не workspace-
      // сущности, но проверяем что workspace-операции не стирают прочее).
      final cache = ImapBodyCacheStore(await repo.outboxDatabase());
      await cache.upsert(
        const CachedEmailBody(
          id: 'acc:inbox:1:1',
          accountId: 'acc',
          uidValidity: 1,
          uid: 1,
          bodyText: 'x',
          truncated: false,
          fullSize: 1,
          attachments: [],
          fetchedAtMs: 0,
          fromCache: true,
        ),
      );
      await state.createWorkspace('Ещё одно');
      final cached = await cache.byId('acc:inbox:1:1');
      expect(cached, isNotNull);
      expect(state.workspaces.length, 4);
    });
  });

  group('P3-01 workspace switcher UI (360x780)', () {
    testWidgets('[W8] узкий экран 360x780: лист пространств, создание '
        'без overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Widget-тест в fake-async зоне: Memory-репо (file SQLite там не
      // завершается); персистентность покрыта [W1]/[W2] в test().
      final state = OrbitAppState(
        MemoryLocalStateRepository(),
        MemoryOrbitSecretStore(),
      );
      await state.load();

      final overflowDetails = <FlutterErrorDetails>[];
      FlutterError.onError = (details) {
        overflowDetails.add(details);
      };
      addTearDown(() {
        FlutterError.onError = null;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.shrink(),
          ),
        ),
      );
      final sheetContext = tester.element(find.byType(MaterialApp));
      unawaited(showWorkspaceSwitcherSheet(sheetContext, state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Поля создания доступны на узком экране.
      expect(
        find.byKey(const Key('workspace-name-field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('workspace-create')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('workspace-name-field')),
        'Тестовое пространство',
      );
      await tester.tap(find.byKey(const Key('workspace-create')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Успешное создание: лист закрылся, пространство активно.
      expect(
        find.byKey(const Key('workspace-name-field')),
        findsNothing,
      );
      expect(state.workspaces.last.name, 'Тестовое пространство');
      expect(
        state.activeWorkspaceId,
        state.workspaces.last.id,
      );
      // Никаких переполнений на 360x780.
      expect(overflowDetails, isEmpty);
    });

    testWidgets('[W9] дефолтное пространство без кнопки удаления',
        (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Memory-репо: см. [W8].
      final state = OrbitAppState(
        MemoryLocalStateRepository(),
        MemoryOrbitSecretStore(),
      );
      await state.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const SizedBox.shrink(),
          ),
        ),
      );
      final sheetContext = tester.element(find.byType(MaterialApp));
      unawaited(showWorkspaceSwitcherSheet(sheetContext, state));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Дефолтное: галочка есть, кнопки удаления нет.
      expect(
        find.byKey(const Key('workspace-delete-workspace-work')),
        findsNothing,
      );
      // Не-дефолтное: кнопка удаления есть.
      await state.createWorkspace('Удаляемое');
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('workspace-delete-workspace-work')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('workspace-delete-workspace-ghost')),
        findsNothing,
      );
      expect(
        find.byKey(
          Key(
            'workspace-delete-${state.workspaces.last.id}',
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
