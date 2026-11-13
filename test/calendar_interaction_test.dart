import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

Future<void> _pumpCalendar(WidgetTester tester) async {
  final appState = OrbitAppState();
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
  await tester.tap(find.byKey(const Key('orbit-nav-2')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('week day tap updates the selected date and visible events', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 1, 15, 12)), () async {
      await _pumpCalendar(tester);
      await tester.tap(find.byKey(const Key('week-day-2026-01-17')));
      await tester.pumpAndSettle();

      expect(find.text('Подготовить отчёт'), findsOneWidget);
      expect(find.text('Совещание по ВП'), findsNothing);
      expect(find.text('Аудит СПД Тэнда'), findsNothing);
    });
  });

  testWidgets('month tap shows a real empty state instead of stale events', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 1, 15, 12)), () async {
      await _pumpCalendar(tester);
      await tester.tap(find.byKey(const Key('calendar-mode-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar-next')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('month-day-2026-02-14')));
      await tester.tap(find.byKey(const Key('month-day-2026-02-14')));
      await tester.pumpAndSettle();

      expect(find.text('Здесь пока пусто'), findsOneWidget);
    });
  });

  testWidgets('short month and leap day are clamped in both directions', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2024, 1, 31, 12)), () async {
      await _pumpCalendar(tester);
      await tester.tap(find.byKey(const Key('calendar-mode-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar-next')));
      await tester.pumpAndSettle();
      expect(find.text('29 февраля 2024'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-next')));
      await tester.pumpAndSettle();
      expect(find.text('29 марта 2024'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-previous')));
      await tester.pumpAndSettle();
      expect(find.text('29 февраля 2024'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-previous')));
      await tester.pumpAndSettle();
      expect(find.text('29 января 2024'), findsOneWidget);
    });
  });

  testWidgets('December and January cross the year without losing the month', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2025, 12, 31, 12)), () async {
      await _pumpCalendar(tester);
      await tester.tap(find.byKey(const Key('calendar-mode-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('calendar-next')));
      await tester.pumpAndSettle();
      expect(find.text('31 января 2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-previous')));
      await tester.pumpAndSettle();
      expect(find.text('31 декабря 2025'), findsOneWidget);
      await tester.tap(find.byKey(const Key('calendar-previous')));
      await tester.pumpAndSettle();
      expect(find.text('30 ноября 2025'), findsOneWidget);
    });
  });
}
