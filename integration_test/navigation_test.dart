import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android navigation and four profile screenshots', (
    tester,
  ) async {
    final style = OrbitStyleManager(SharedPreferencesAppearanceRepository());
    await style.load();
    await style.setQuality(OrbitQuality.eco);
    await style.setMotionEnabled(false);
    await style.setRenderer(TodayRenderer.procedural);
    await style.setLanguage('ru');
    await style.setTextScale(1);
    final appState = OrbitAppState(SharedPreferencesLocalStateRepository());
    await appState.load();
    final quality = OrbitQualityManager();
    await tester.pumpWidget(
      OrbitVisualLabApp(style: style, quality: quality, appState: appState),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    for (final profile in OrbitProfile.values) {
      await tester.tap(find.byKey(const Key('orbit-nav-0')));
      await style.setProfile(profile);
      await tester.pumpAndSettle();
      await _capture(binding, 'android_${profile.name}_today');

      await tester.tap(find.byTooltip('ORBIT Brain'));
      await tester.pumpAndSettle();
      await _capture(binding, 'android_${profile.name}_brain');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('orbit-nav-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('email-weekly-plan')), findsOneWidget);
      await _capture(binding, 'android_${profile.name}_mail_inbox');
      await tester.tap(find.byKey(const Key('email-weekly-plan')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mail-detail-body')), findsOneWidget);
      await _capture(binding, 'android_${profile.name}_mail_detail');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('email-weekly-plan')), findsOneWidget);
      await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
      await tester.pumpAndSettle();
      await _capture(binding, 'android_${profile.name}_mail_compose');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('orbit-nav-2')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('calendar-modes')), findsOneWidget);
      await _capture(binding, 'android_${profile.name}_calendar');

      await tester.tap(find.byKey(const Key('orbit-nav-3')));
      await tester.pumpAndSettle();
      await _capture(binding, 'android_${profile.name}_tasks');
      await tester.tap(find.byKey(const Key('task-report')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('task-detail-title')), findsOneWidget);
      await _capture(binding, 'android_${profile.name}_task_detail');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('orbit-nav-4')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-Интерфейс')), findsOneWidget);
      await _capture(binding, 'android_${profile.name}_settings');
      expect(tester.takeException(), isNull);
    }

    await tester.tap(find.byKey(const Key('orbit-nav-3')));
    await tester.pumpAndSettle();
    if (!appState.tasks.any((task) => task.title == 'ORB05 persistence task')) {
      await tester.tap(find.byKey(const Key('orbit-button-Добавить задачу')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('new-task-title')),
        'ORB05 persistence task',
      );
      await tester.tap(find.byKey(const Key('confirm-add-task')));
      await tester.pumpAndSettle();
    }
    expect(find.text('ORB05 persistence task'), findsWidgets);

    await tester.tap(find.byKey(const Key('orbit-nav-2')));
    await tester.pumpAndSettle();
    if (!appState.events.any(
      (event) => event.title == 'ORB05 persistence event',
    )) {
      await tester.tap(find.byKey(const Key('orbit-button-Новое событие')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('new-event-title')),
        'ORB05 persistence event',
      );
      await tester.tap(find.byKey(const Key('confirm-add-event')));
      await tester.pumpAndSettle();
    }
    expect(find.text('ORB05 persistence event'), findsWidgets);

    await tester.tap(find.byKey(const Key('orbit-nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('draft-to')),
      'persistence@example.demo',
    );
    await tester.enterText(
      find.byKey(const Key('draft-subject')),
      'ORB05 persistence draft',
    );
    await tester.enterText(
      find.byKey(const Key('draft-body')),
      'Process death evidence',
    );
    await tester.tap(find.byKey(const Key('save-draft-button')));
    await tester.pumpAndSettle();
    await appState.flush();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android month grid navigates to and selects leap day', (
    tester,
  ) async {
    final style = OrbitStyleManager(MemoryAppearanceRepository());
    await style.load();
    await style.setQuality(OrbitQuality.eco);
    await style.setMotionEnabled(false);
    await style.setRenderer(TodayRenderer.procedural);
    await style.setLanguage('ru');
    final appState = OrbitAppState();
    await appState.load();
    await tester.pumpWidget(
      OrbitVisualLabApp(
        style: style,
        quality: OrbitQualityManager(),
        appState: appState,
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await tester.tap(find.byKey(const Key('orbit-nav-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-mode-2')));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final monthSteps = (now.year - 2024) * 12 + now.month - 3;
    expect(monthSteps, greaterThanOrEqualTo(0));
    for (var index = 0; index < monthSteps; index++) {
      await tester.tap(find.byKey(const Key('calendar-previous')));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byKey(const Key('month-day-2024-03-31')));
    await tester.tap(find.byKey(const Key('month-day-2024-03-31')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('calendar-previous')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('calendar-previous')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-header-date-2024-02-29')),
      findsOneWidget,
      reason: 'March 31 must clamp to February 29 in the leap year',
    );
    await tester.ensureVisible(find.byKey(const Key('month-day-2024-02-28')));
    await tester.tap(find.byKey(const Key('month-day-2024-02-28')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-header-date-2024-02-28')),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const Key('month-day-2024-02-29')));
    await tester.tap(find.byKey(const Key('month-day-2024-02-29')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-header-date-2024-02-29')),
      findsOneWidget,
    );
    expect(find.text('Здесь пока пусто'), findsOneWidget);
    await _capture(binding, 'android_calendar_leap_year');
    expect(tester.takeException(), isNull);
  });
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  final bytes = await binding.takeScreenshot(name);
  final file = File('${Directory.systemTemp.path}/$name.png');
  await file.writeAsBytes(bytes, flush: true);
  await const MethodChannel('orbit/qa').invokeMethod<void>('saveScreenshot', {
    'name': name,
    'bytes': await file.readAsBytes(),
  });
  debugPrint('[ORBIT device] screenshot=${file.path}');
  await Future<void>.delayed(const Duration(milliseconds: 500));
}
