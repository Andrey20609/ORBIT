import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

Future<(OrbitStyleManager, MemoryAppearanceRepository, OrbitQualityManager)>
_pumpApp(WidgetTester tester, {MemoryAppearanceRepository? repository}) async {
  final repo =
      repository ??
      MemoryAppearanceRepository(
        const AppearanceSettings(
          quality: OrbitQuality.eco,
          motionEnabled: false,
        ),
      );
  final style = OrbitStyleManager(repo);
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
  await tester.pump(const Duration(milliseconds: 80));
  return (style, repo, quality);
}

Future<void> _nav(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('orbit-nav-$index')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('main route, mail open/back and bottom navigation', (
    tester,
  ) async {
    await _pumpApp(tester);
    expect(find.byKey(const Key('today-greeting')), findsOneWidget);

    await _nav(tester, 1);
    expect(find.text('Входящие'), findsOneWidget);
    await tester.tap(find.byKey(const Key('email-weekly-plan')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('mail-detail-body')), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('email-weekly-plan')), findsOneWidget);

    await _nav(tester, 2);
    expect(find.byKey(const Key('page-title-Календарь')), findsOneWidget);
    await _nav(tester, 3);
    expect(find.byKey(const Key('page-title-Задачи')), findsOneWidget);
    await _nav(tester, 4);
    expect(find.byKey(const Key('page-title-Настройки')), findsOneWidget);
    await _nav(tester, 0);
    expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all four profiles apply without losing the compose draft', (
    tester,
  ) async {
    final (style, repo, _) = await _pumpApp(tester);
    await _nav(tester, 1);
    await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(
      find.byKey(const Key('draft-subject')),
      'Черновик сохраняется',
    );
    await tester.enterText(
      find.byKey(const Key('draft-body')),
      'Текст не должен исчезнуть',
    );
    await tester.ensureVisible(find.byKey(const Key('save-draft-button')));
    await tester.tap(find.byKey(const Key('save-draft-button')));
    await tester.pump();

    await _nav(tester, 4);
    await tester.tap(find.byKey(const Key('settings-Интерфейс')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('interface-gallery')), findsOneWidget);

    for (final profile in OrbitProfile.values) {
      await tester.ensureVisible(find.byKey(Key('profile-${profile.name}')));
      await tester.tap(find.byKey(Key('profile-${profile.name}')));
      await tester.pump(const Duration(milliseconds: 80));
      expect(style.settings.profile, profile);
      expect(repo.value.profile, profile);
    }

    await _nav(tester, 1);
    expect(find.byKey(const Key('draft-subject')), findsOneWidget);
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
      'Черновик сохраняется',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('draft-body')))
          .controller
          ?.text,
      'Текст не должен исчезнуть',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('task creation and progress use local state', (tester) async {
    await _pumpApp(tester);
    await _nav(tester, 3);
    await tester.ensureVisible(find.byKey(const Key('add-task-bottom')));
    await tester.tap(find.byKey(const Key('add-task-bottom')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.enterText(
      find.byKey(const Key('new-task-title')),
      'Проверить Visual Engine',
    );
    await tester.tap(find.byKey(const Key('confirm-add-task')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pumpAndSettle();
    expect(find.text('Проверить Visual Engine'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('task-progress')),
    );
    expect(progress.value, lessThan(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('quality, renderer and lifecycle switches do not throw', (
    tester,
  ) async {
    final (style, repo, quality) = await _pumpApp(tester);
    await _nav(tester, 4);
    await tester.tap(find.byKey(const Key('settings-ORBIT Visual Lab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    await tester.tap(find.byKey(const Key('renderer-filament')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(style.settings.renderer, TodayRenderer.filament);
    expect(repo.value.renderer, TodayRenderer.filament);
    expect(find.text('Fallback: Static'), findsOneWidget);
    expect(find.text('Actual: FILAMENT'), findsNothing);
    await tester.tap(find.byKey(const Key('renderer-rive')));
    await tester.pump(const Duration(milliseconds: 80));
    expect(style.settings.renderer, TodayRenderer.rive);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(quality.appResumed, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(quality.appResumed, isTrue);

    await tester.ensureVisible(find.byKey(const Key('open-today-lab')));
    await tester.tap(find.byKey(const Key('open-today-lab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick actions open and Brain uses explicit demo response', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byKey(const Key('quick-actions-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('quick-actions-sheet')), findsOneWidget);
    await tester.ensureVisible(find.text('ORBIT Brain').last);
    await tester.tap(find.text('ORBIT Brain').last);
    await tester.pumpAndSettle();
    expect(find.text('Чем помочь сегодня?'), findsOneWidget);
    await tester.tap(find.text('Сформировать план дня'));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.byKey(const Key('brain-demo-response')), findsOneWidget);
    expect(find.textContaining('не отправлялся'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
