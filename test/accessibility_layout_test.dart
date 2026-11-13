import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  final repository = MemoryAppearanceRepository(
    const AppearanceSettings(
      quality: OrbitQuality.eco,
      motionEnabled: false,
      languageCode: 'en',
    ),
  );
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
  await tester.pump(const Duration(milliseconds: 80));
}

Future<void> _check(WidgetTester tester, String surface) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
  final exception = tester.takeException();
  expect(exception, isNull, reason: '$surface: $exception');
  expect(find.byType(ErrorWidget), findsNothing, reason: surface);
}

Future<void> _nav(WidgetTester tester, int index, double scale) async {
  await tester.tap(find.byKey(Key('orbit-nav-$index')));
  await _check(tester, 'navigation $index at ${scale}x');
}

Future<void> _back(WidgetTester tester, String surface) async {
  await tester.binding.handlePopRoute();
  await _check(tester, '$surface back');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final scale in const [1.0, 1.3, 1.5, 2.0]) {
    testWidgets('all surfaces fit text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpApp(tester);
      await _check(tester, 'Today');

      await tester.tap(find.byKey(const Key('quick-actions-fab')));
      await tester.pumpAndSettle();
      await _check(tester, 'Quick actions');
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('quick-actions-fab')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ORBIT Brain').last);
      await tester.tap(find.text('ORBIT Brain').last);
      await tester.pumpAndSettle();
      await _check(tester, 'Brain');
      await tester.ensureVisible(find.text('Plan my day'));
      await tester.tap(find.text('Plan my day'));
      await _check(tester, 'Brain demo response');
      expect(find.byKey(const Key('brain-demo-response')), findsOneWidget);
      await _back(tester, 'Brain');

      await _nav(tester, 1, scale);
      for (var index = 0; index < 3; index++) {
        await tester.tap(find.byKey(Key('mail-filter-$index')));
        await _check(tester, 'Mail filter $index');
      }
      await tester.tap(find.byKey(const Key('mail-filter-0')));
      await tester.tap(find.byKey(const Key('email-weekly-plan')));
      await _check(tester, 'Mail detail');
      await _back(tester, 'Mail detail');
      await tester.tap(find.byKey(const Key('orbit-button-New email')));
      await _check(tester, 'Compose');
      await tester.ensureVisible(find.byKey(const Key('draft-body')));
      await tester.tap(find.byKey(const Key('draft-body')));
      await tester.showKeyboard(find.byKey(const Key('draft-body')));
      await _check(tester, 'Compose keyboard');
      FocusManager.instance.primaryFocus?.unfocus();
      await _check(tester, 'Compose keyboard dismissed');
      await _back(tester, 'Compose');

      await _nav(tester, 2, scale);
      for (var index = 0; index < 4; index++) {
        await tester.tap(find.byKey(Key('calendar-mode-$index')));
        await _check(tester, 'Calendar mode $index');
      }

      await _nav(tester, 3, scale);
      await tester.ensureVisible(find.byKey(const Key('add-task-bottom')));
      await tester.tap(find.byKey(const Key('add-task-bottom')));
      await tester.pumpAndSettle();
      await _check(tester, 'Add task dialog');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await _nav(tester, 4, scale);
      await tester.ensureVisible(find.byKey(const Key('settings-Language')));
      await tester.tap(find.byKey(const Key('settings-Language')));
      await tester.pumpAndSettle();
      await _check(tester, 'Language dialog');
      await _back(tester, 'Language dialog');

      await tester.ensureVisible(
        find.byKey(const Key('settings-Graphics quality')),
      );
      await tester.tap(find.byKey(const Key('settings-Graphics quality')));
      await _check(tester, 'Personalization');
      await tester.ensureVisible(find.byKey(const Key('theme-dark')));
      await tester.tap(find.byKey(const Key('theme-dark')));
      await _check(tester, 'Dark theme');
      await tester.ensureVisible(find.byKey(const Key('density-compact')));
      await tester.tap(find.byKey(const Key('density-compact')));
      await _check(tester, 'Compact density');
      await _back(tester, 'Personalization');

      await tester.ensureVisible(find.byKey(const Key('settings-Interface')));
      await tester.tap(find.byKey(const Key('settings-Interface')));
      await _check(tester, 'Interface gallery');
      await _back(tester, 'Interface gallery');

      await tester.ensureVisible(
        find.byKey(const Key('settings-ORBIT Visual Lab')),
      );
      await tester.tap(find.byKey(const Key('settings-ORBIT Visual Lab')));
      await _check(tester, 'Visual Lab');
      await tester.ensureVisible(find.byKey(const Key('renderer-rive')));
      await tester.tap(find.byKey(const Key('renderer-rive')));
      await _check(tester, 'Visual Lab Rive');
      await tester.ensureVisible(find.byKey(const Key('renderer-filament')));
      await tester.tap(find.byKey(const Key('renderer-filament')));
      await _check(tester, 'Visual Lab Filament fallback');
      await tester.ensureVisible(find.byKey(const Key('renderer-procedural')));
      await tester.tap(find.byKey(const Key('renderer-procedural')));
      await _check(tester, 'Visual Lab Static');
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
