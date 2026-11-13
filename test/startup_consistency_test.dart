import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  test('late appearance load cannot overwrite a newer user edit', () async {
    final repository = DeferredAppearanceRepository();
    final manager = OrbitStyleManager(repository);
    final loading = manager.load();
    await manager.setProfile(OrbitProfile.zen);
    repository.complete(const AppearanceSettings());
    await loading;

    expect(manager.settings.profile, OrbitProfile.zen);
  });

  test('late local-state load cannot overwrite a newer user task', () async {
    final repository = DeferredLocalStateRepository();
    final state = OrbitAppState(repository);
    final loading = state.load();
    state.addTask('Пользовательская задача');
    repository.complete(<String, Object?>{'tasks': <Object?>[]});
    await loading;

    expect(state.tasks.first.title, 'Пользовательская задача');
  });

  testWidgets('appearance save failure is visible and retry succeeds', (
    tester,
  ) async {
    final repository = MemoryAppearanceRepository();
    final style = OrbitStyleManager(repository);
    await style.load();
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);
    await tester.pumpWidget(
      OrbitVisualLabApp(
        style: style,
        quality: quality,
        appState: OrbitAppState(),
      ),
    );
    await tester.pump();
    repository.failNextSave = true;
    await style.setProfile(OrbitProfile.flow);
    await tester.pump();

    expect(find.byKey(const Key('persistence-retry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('persistence-retry')));
    await tester.pump();

    expect(find.byKey(const Key('persistence-retry')), findsNothing);
    expect(style.settings.profile, OrbitProfile.flow);
    expect(style.lastPersistenceError, isNull);
  });
}

final class DeferredAppearanceRepository implements OrbitAppearanceRepository {
  final completer = Completer<AppearanceSettings>();

  void complete(AppearanceSettings value) => completer.complete(value);

  @override
  Future<AppearanceSettings> load() => completer.future;

  @override
  Future<void> save(AppearanceSettings settings) async {}
}

final class DeferredLocalStateRepository implements OrbitLocalStateRepository {
  final completer = Completer<Map<String, Object?>>();

  void complete(Map<String, Object?> value) => completer.complete(value);

  @override
  Future<Map<String, Object?>> load() => completer.future;

  @override
  Future<void> save(Map<String, Object?> state) async {}
}
