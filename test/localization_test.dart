import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

Future<(OrbitStyleManager, MemoryAppearanceRepository, OrbitAppState)> _pumpApp(
  WidgetTester tester,
  String languageCode,
) async {
  final repository = MemoryAppearanceRepository(
    AppearanceSettings(
      quality: OrbitQuality.eco,
      motionEnabled: false,
      languageCode: languageCode,
    ),
  );
  final style = OrbitStyleManager(repository);
  await style.load();
  final quality = OrbitQualityManager();
  final appState = OrbitAppState();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitVisualLabApp(style: style, quality: quality, appState: appState),
  );
  await tester.pump(const Duration(milliseconds: 80));
  return (style, repository, appState);
}

Future<void> _nav(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('orbit-nav-$index')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expectations = <String, (String, String, String, String, String)>{
    'ru': ('Входящие', 'Календарь', 'Задачи', 'Настройки', 'План на неделю'),
    'en': ('Inbox', 'Calendar', 'Tasks', 'Settings', 'Weekly plan'),
    'de': (
      'Posteingang',
      'Kalender',
      'Aufgaben',
      'Einstellungen',
      'Wochenplan',
    ),
    'fr': (
      'Boîte de réception',
      'Calendrier',
      'Tâches',
      'Réglages',
      'Plan hebdomadaire',
    ),
    'es': (
      'Bandeja de entrada',
      'Calendario',
      'Tareas',
      'Ajustes',
      'Plan semanal',
    ),
  };

  for (final entry in expectations.entries) {
    testWidgets('${entry.key} localizes navigation and demo content', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pumpApp(tester, entry.key);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);

      await _nav(tester, 1);
      expect(find.byKey(Key('page-title-${entry.value.$1}')), findsOneWidget);
      expect(find.text(entry.value.$5), findsOneWidget);
      await _nav(tester, 2);
      expect(find.byKey(Key('page-title-${entry.value.$2}')), findsOneWidget);
      await _nav(tester, 3);
      expect(find.byKey(Key('page-title-${entry.value.$3}')), findsOneWidget);
      await _nav(tester, 4);
      expect(find.byKey(Key('page-title-${entry.value.$4}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Spanish Today fits 320 dp at 200 percent text', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pumpApp(tester, 'es');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language changes persist without losing the compose draft', (
    tester,
  ) async {
    final (style, repository, _) = await _pumpApp(tester, 'en');
    await _nav(tester, 1);
    await tester.tap(find.byKey(const Key('orbit-button-New email')));
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(
      find.byKey(const Key('draft-subject')),
      'Persistent local draft',
    );
    await tester.enterText(
      find.byKey(const Key('draft-body')),
      'No network and no send action',
    );
    await tester.ensureVisible(find.byKey(const Key('save-draft-button')));
    await tester.tap(find.byKey(const Key('save-draft-button')));
    await tester.pump();
    await _nav(tester, 4);

    for (final code in const ['de', 'fr', 'es', 'ru', 'en']) {
      await tester.ensureVisible(find.byIcon(Icons.language_rounded));
      await tester.tap(find.byIcon(Icons.language_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('language-$code')));
      await tester.pumpAndSettle();
      expect(style.settings.languageCode, code);
      expect(repository.value.languageCode, code);
    }

    await _nav(tester, 1);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const Key('draft-subject')),
              matching: find.byType(TextField),
            ),
          )
          .controller
          ?.text,
      'Persistent local draft',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('local task metadata and demo reply use localized strings', (
    tester,
  ) async {
    final (_, _, appState) = await _pumpApp(tester, 'en');
    await _nav(tester, 3);
    await tester.ensureVisible(find.byKey(const Key('add-task-bottom')));
    await tester.tap(find.byKey(const Key('add-task-bottom')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(
      find.byKey(const Key('new-task-title')),
      'Localized local task',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('new-task-title')))
          .controller
          ?.text,
      'Localized local task',
    );
    await tester.tap(find.byKey(const Key('confirm-add-task')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(appState.tasks.first.title, 'Localized local task');
    expect(appState.tasks.first.project, 'local-list');
    expect(appState.tasks.first.due, 'no-due');
    await tester.pumpAndSettle();
    expect(find.text('Localized local task'), findsOneWidget);
    expect(find.text('Local list · No due date'), findsOneWidget);

    await _nav(tester, 1);
    await tester.tap(find.byKey(const Key('email-weekly-plan')));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('reply-button')));
    await tester.tap(find.byKey(const Key('reply-button')));
    await tester.pump();
    await tester.pumpAndSettle();

    String draftValue(Key key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(TextField),
          ),
        )
        .controller!
        .text;
    expect(draftValue(const Key('draft-subject')), 'Re: Weekly plan');
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('draft-body')))
          .controller!
          .text,
      contains('Reply to demo email: Hi! Attached is the updated plan'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('theme selection applies immediately and survives reload', (
    tester,
  ) async {
    final (style, repository, _) = await _pumpApp(tester, 'en');
    await _nav(tester, 4);
    await tester.tap(find.byKey(const Key('settings-Graphics quality')));
    await tester.pump(const Duration(milliseconds: 80));

    for (final mode in const [
      ThemeMode.dark,
      ThemeMode.light,
      ThemeMode.system,
    ]) {
      await tester.ensureVisible(find.byKey(Key('theme-${mode.name}')));
      await tester.tap(find.byKey(Key('theme-${mode.name}')));
      await tester.pump(const Duration(milliseconds: 80));
      expect(style.settings.themeMode, mode);
      expect(repository.value.themeMode, mode);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        mode,
      );
    }

    final restored = OrbitStyleManager(repository);
    await restored.load();
    expect(restored.settings.themeMode, ThemeMode.system);
    expect(tester.takeException(), isNull);
  });
}
