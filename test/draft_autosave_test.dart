import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

Future<(OrbitAppState, MemoryLocalStateRepository)> _pumpCompose(
  WidgetTester tester, {
  MemoryLocalStateRepository? repository,
}) async {
  final local = repository ?? MemoryLocalStateRepository();
  final appState = OrbitAppState(local);
  await appState.load();
  final style = OrbitStyleManager(
    MemoryAppearanceRepository(
      const AppearanceSettings(quality: OrbitQuality.eco, motionEnabled: false),
    ),
  );
  await style.load();
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitVisualLabApp(style: style, quality: quality, appState: appState),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('orbit-nav-1')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
  await tester.pumpAndSettle();
  return (appState, local);
}

Future<void> _enterDraft(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('draft-to')),
    'autosave@example.demo',
  );
  await tester.enterText(
    find.byKey(const Key('draft-subject')),
    'OR052 autosave subject',
  );
  await tester.enterText(
    find.byKey(const Key('draft-body')),
    'OR052 body without Save',
  );
}

void main() {
  testWidgets('debounced edits and system Back preserve all draft fields', (
    tester,
  ) async {
    final (appState, repository) = await _pumpCompose(tester);
    await _enterDraft(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await appState.flush();

    expect(repository.saveCount, greaterThan(0));
    expect(appState.hasUnsavedDraftChanges, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
    await tester.pumpAndSettle();

    String value(Key key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(TextField),
            matchRoot: true,
          ),
        )
        .controller!
        .text;
    expect(value(const Key('draft-to')), 'autosave@example.demo');
    expect(value(const Key('draft-subject')), 'OR052 autosave subject');
    expect(value(const Key('draft-body')), 'OR052 body without Save');
  });

  testWidgets('lifecycle pause flushes the latest draft before process death', (
    tester,
  ) async {
    final (appState, repository) = await _pumpCompose(tester);
    await _enterDraft(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await appState.flush();

    final restored = OrbitAppState(repository);
    await restored.load();
    expect(restored.draftTo, 'autosave@example.demo');
    expect(restored.draftSubject, 'OR052 autosave subject');
    expect(restored.draftBody, 'OR052 body without Save');
    expect(restored.hasUnsavedDraftChanges, isFalse);
  });

  testWidgets('write failure keeps edits distinct and retry confirms them', (
    tester,
  ) async {
    final repository = MemoryLocalStateRepository()..failNextSave = true;
    final (appState, _) = await _pumpCompose(tester, repository: repository);
    await _enterDraft(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(appState.lastPersistenceError, isA<StateError>());
    expect(appState.hasUnsavedDraftChanges, isTrue);
    expect(appState.draftBody, 'OR052 body without Save');
    expect(appState.lastSavedDraft.body, isEmpty);
    expect(find.byKey(const Key('persistence-retry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('persistence-retry')));
    await tester.pumpAndSettle();
    expect(appState.hasUnsavedDraftChanges, isFalse);
    expect(appState.lastSavedDraft.body, 'OR052 body without Save');
    expect(appState.draftBody, 'OR052 body without Save');
  });
}
