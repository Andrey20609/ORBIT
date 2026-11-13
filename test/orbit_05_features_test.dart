import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/screens/settings_screens.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

Future<(OrbitStyleManager, OrbitAppState)> _pump(WidgetTester tester) async {
  final repository = MemoryAppearanceRepository(
    const AppearanceSettings(quality: OrbitQuality.eco, motionEnabled: false),
  );
  final style = OrbitStyleManager(repository);
  await style.load();
  final appState = OrbitAppState(MemoryLocalStateRepository());
  await appState.load();
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitVisualLabApp(style: style, quality: quality, appState: appState),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return (style, appState);
}

Future<void> _nav(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('orbit-nav-$index')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('event creation and date switching work in the calendar', (
    tester,
  ) async {
    final (_, appState) = await _pump(tester);
    await _nav(tester, 2);
    await tester.tap(find.byKey(const Key('calendar-next')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('orbit-button-Новое событие')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('new-event-title')),
      'Проверить ORBIT 0.5',
    );
    await tester.tap(find.byKey(const Key('confirm-add-event')));
    await tester.pumpAndSettle();

    expect(appState.events.last.title, 'Проверить ORBIT 0.5');
    expect(find.text('Проверить ORBIT 0.5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task card opens and changes priority and status', (
    tester,
  ) async {
    final (_, appState) = await _pump(tester);
    await _nav(tester, 3);
    await tester.tap(find.byKey(const Key('task-report')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-detail-title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-priority-1')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('toggle-task-status')));
    await tester.tap(find.byKey(const Key('toggle-task-status')));
    await tester.pump();

    expect(appState.taskById('report')?.priority, 1);
    expect(appState.taskById('report')?.done, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-report')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('text scale applies and persists', (tester) async {
    final (style, _) = await _pump(tester);
    await _nav(tester, 4);
    await tester.tap(find.byKey(const Key('settings-Качество графики')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('text-scale-2')));
    await tester.tap(find.byKey(const Key('text-scale-2')));
    await tester.pump();

    expect(style.settings.textScale, 1.3);
    expect(
      MediaQuery.textScalerOf(
        tester.element(find.byType(PersonalizationScreen)),
      ).scale(1),
      1.3,
    );
    expect(tester.takeException(), isNull);
  });
}
