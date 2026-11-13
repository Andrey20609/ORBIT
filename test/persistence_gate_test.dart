import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_corrupt_data.dart';
import 'package:orbit_visual_lab/data/orbit_load_status.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/orbit_bootstrap.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

final validTask = <String, Object?>{
  'id': 'local-task',
  'title': 'Task',
  'project': 'local-list',
  'due': 'no-due',
  'done': false,
  'priority': 1,
};
final validEvent = <String, Object?>{
  'id': 'local-event',
  'time': '10:00',
  'title': 'Event',
  'meta': 'local-list',
  'color': 0xFF9B8CFF,
  'date': '2026-11-08T10:00:00.000',
};
final validState = <String, Object?>{
  'schemaVersion': 1,
  'tasks': [validTask],
  'events': [validEvent],
  'readEmails': ['weekly-plan'],
  'draftTo': 'person@example.demo',
  'draftSubject': 'Subject',
  'draftBody': 'Body',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final entry in <String, Map<String, Object?>>{
    'draftBody number': {...validState, 'draftBody': 42},
    'draftSubject list': {...validState, 'draftSubject': <Object?>[]},
    'readEmails string': {...validState, 'readEmails': 'bad'},
    'tasks object': {...validState, 'tasks': <String, Object?>{}},
    'task priority string': {
      ...validState,
      'tasks': [
        {...validTask, 'priority': 'bad'},
      ],
    },
    'event date invalid': {
      ...validState,
      'events': [
        {...validEvent, 'date': 42},
      ],
    },
    'schema unsupported': {...validState, 'schemaVersion': 99},
  }.entries) {
    test('${entry.key} preserves raw bytes and blocks edit/flush', () async {
      final raw = jsonEncode(entry.value);
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocalStateRepository.storageKey: raw,
      });
      final preferences = await SharedPreferences.getInstance();
      final state = OrbitAppState(
        SharedPreferencesLocalStateRepository(preferences: preferences),
      );
      await state.load();

      expect(state.loadStatus, OrbitLoadStatus.corrupt);
      expect(state.lastLoadError, isA<OrbitCorruptDataException>());
      expect(
        preferences.getString(SharedPreferencesLocalStateRepository.backupKey),
        raw,
      );
      state.addTask('Must not be saved');
      state.updateDraft(body: 'Must not be saved');
      await expectLater(
        state.flush(),
        throwsA(isA<OrbitCorruptDataException>()),
      );
      expect(
        preferences.getString(SharedPreferencesLocalStateRepository.storageKey),
        raw,
      );
    });
  }

  test(
    'repaired payload restores after recovery without losing draft or records',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocalStateRepository.storageKey: '{broken',
      });
      final preferences = await SharedPreferences.getInstance();
      final state = OrbitAppState(
        SharedPreferencesLocalStateRepository(preferences: preferences),
      );
      await state.load();
      expect(state.loadStatus, OrbitLoadStatus.corrupt);
      await state.resetCorruptData();
      await preferences.setString(
        SharedPreferencesLocalStateRepository.storageKey,
        jsonEncode(validState),
      );
      final restored = OrbitAppState(
        SharedPreferencesLocalStateRepository(preferences: preferences),
      );
      await restored.load();

      expect(restored.loadStatus, OrbitLoadStatus.loaded);
      expect(restored.draftTo, 'person@example.demo');
      expect(restored.draftSubject, 'Subject');
      expect(restored.draftBody, 'Body');
      expect(restored.tasks.single.id, 'local-task');
      expect(restored.events.single.id, 'local-event');
    },
  );

  test(
    'empty storage loads once and valid 0.5.3 JSON migrates without loss',
    () async {
      SharedPreferences.setMockInitialValues({});
      final state = OrbitAppState();
      await state.load();
      expect(state.loadStatus, OrbitLoadStatus.loaded);
      state.addTask('Empty is writable');
      await state.flush();
      expect(state.tasks.first.title, 'Empty is writable');

      final repository = MemoryLocalStateRepository(validState);
      final migrated = OrbitAppState(repository);
      await migrated.load();
      expect(migrated.draftBody, 'Body');
      expect(migrated.tasks.single.title, 'Task');
      expect(migrated.events.single.title, 'Event');
    },
  );

  test(
    'backup write failure keeps original storage and blocks saving',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocalStateRepository.storageKey: '{broken',
      });
      final preferences = await SharedPreferences.getInstance();
      final state = OrbitAppState(
        SharedPreferencesLocalStateRepository(
          preferences: preferences,
          backupWriter: (key, value) async => false,
        ),
      );
      await state.load();

      expect(state.lastLoadError, isA<StateError>());
      expect(state.loadStatus, OrbitLoadStatus.transientFailure);
      state.addTask('Must not be saved');
      await expectLater(state.flush(), throwsA(isA<StateError>()));
      expect(
        preferences.getString(SharedPreferencesLocalStateRepository.storageKey),
        '{broken',
      );
    },
  );

  test(
    'transient local read error is fail closed until successful retry',
    () async {
      final repository = _FailingLocalRepository();
      final state = OrbitAppState(repository);
      await state.load();
      expect(state.loadStatus, OrbitLoadStatus.transientFailure);
      state.addTask('Blocked edit');
      state.updateDraft(body: 'Blocked edit');
      await expectLater(state.flush(), throwsA(isA<StateError>()));
      expect(repository.saveCount, 0);

      repository.fail = false;
      await state.load();
      expect(state.loadStatus, OrbitLoadStatus.loaded);
      expect(state.draftBody, 'Body');
      state.updateDraft(body: 'After recovery');
      await state.flush();
      expect(repository.saveCount, 1);
      expect(repository.state['draftBody'], 'After recovery');
    },
  );

  test(
    'transient appearance read error does not apply or save defaults',
    () async {
      final repository = _FailingAppearanceRepository();
      final style = OrbitStyleManager(repository);
      await style.load();
      expect(style.loadStatus, OrbitLoadStatus.transientFailure);
      await style.setProfile(OrbitProfile.zen);
      expect(style.settings.profile, OrbitProfile.zen);
      expect(repository.saveCount, 0);

      repository.fail = false;
      await style.load();
      expect(style.loadStatus, OrbitLoadStatus.loaded);
      expect(style.settings.profile, OrbitProfile.zen);
    },
  );

  testWidgets(
    'five-second load timeout is fail closed and late retry succeeds',
    (tester) async {
      final local = _DeferredLocalRepository();
      final appearance = _DeferredAppearanceRepository();
      final state = OrbitAppState(local);
      final style = OrbitStyleManager(appearance);
      final quality = OrbitQualityManager();
      addTearDown(quality.dispose);
      await tester.pumpWidget(
        OrbitBootstrap(
          startup: Stopwatch()..start(),
          style: style,
          quality: quality,
          appState: state,
          initializeGraphics: false,
          initializeLocales: false,
        ),
      );
      await tester.pump(const Duration(seconds: 6));
      expect(state.loadStatus, OrbitLoadStatus.transientFailure);
      expect(style.loadStatus, OrbitLoadStatus.transientFailure);
      state.addTask('Blocked during timeout');
      expect(local.saveCount, 0);

      local.complete(validState);
      appearance.complete(
        const AppearanceSettings(
          profile: OrbitProfile.zen,
          quality: OrbitQuality.eco,
          motionEnabled: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(state.loadStatus, OrbitLoadStatus.loaded);
      expect(style.loadStatus, OrbitLoadStatus.loaded);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    },
  );

  test('serialized saves keep the newest draft after a save race', () async {
    final repository = MemoryLocalStateRepository();
    final state = OrbitAppState(repository);
    await state.load();
    state.updateDraft(body: 'First pending write');
    state.updateDraft(body: 'Newest confirmed write');
    await state.flush();

    final restored = OrbitAppState(repository);
    await restored.load();
    expect(restored.draftBody, 'Newest confirmed write');
    expect(restored.hasUnsavedDraftChanges, isFalse);
  });
}

final class _FailingLocalRepository implements OrbitLocalStateRepository {
  bool fail = true;
  int saveCount = 0;
  final Map<String, Object?> state =
      jsonDecode(jsonEncode(validState)) as Map<String, Object?>;

  @override
  Future<Map<String, Object?>> load() async {
    if (fail) throw StateError('Simulated local read failure');
    return jsonDecode(jsonEncode(state)) as Map<String, Object?>;
  }

  @override
  Future<void> save(Map<String, Object?> value) async {
    saveCount++;
    state
      ..clear()
      ..addAll(jsonDecode(jsonEncode(value)) as Map<String, Object?>);
  }
}

final class _FailingAppearanceRepository implements OrbitAppearanceRepository {
  bool fail = true;
  int saveCount = 0;
  AppearanceSettings value = const AppearanceSettings(
    profile: OrbitProfile.zen,
  );

  @override
  Future<AppearanceSettings> load() async {
    if (fail) {
      throw PlatformException(
        code: 'io',
        message: 'Simulated appearance read failure',
      );
    }
    return value;
  }

  @override
  Future<void> save(AppearanceSettings settings) async {
    saveCount++;
    value = settings;
  }
}

final class _DeferredLocalRepository implements OrbitLocalStateRepository {
  final completer = Completer<Map<String, Object?>>();
  int saveCount = 0;

  void complete(Map<String, Object?> value) => completer.complete(value);

  @override
  Future<Map<String, Object?>> load() => completer.future;

  @override
  Future<void> save(Map<String, Object?> state) async {
    saveCount++;
  }
}

final class _DeferredAppearanceRepository implements OrbitAppearanceRepository {
  final completer = Completer<AppearanceSettings>();

  void complete(AppearanceSettings value) => completer.complete(value);

  @override
  Future<AppearanceSettings> load() => completer.future;

  @override
  Future<void> save(AppearanceSettings settings) async {}
}
