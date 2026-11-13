import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/screens/today_screen.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';

Future<void> _pump(WidgetTester tester, AppearanceSettings settings) async {
  final appState = OrbitAppState();
  await appState.load();
  final style = OrbitStyleManager(MemoryAppearanceRepository(settings));
  await style.load();
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitVisualLabApp(style: style, quality: quality, appState: appState),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final profile in OrbitProfile.values) {
    for (final mode in ThemeMode.values) {
      testWidgets('${profile.name} supports ${mode.name} below MaterialApp', (
        tester,
      ) async {
        if (mode == ThemeMode.system) {
          tester.binding.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark;
          addTearDown(
            tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
          );
        }
        await _pump(
          tester,
          AppearanceSettings(
            profile: profile,
            themeMode: mode,
            quality: OrbitQuality.eco,
            motionEnabled: false,
          ),
        );
        final context = tester.element(find.byType(TodayScreen));
        final environment = OrbitEnvironment.of(context);
        final theme = Theme.of(context);
        final expected = mode == ThemeMode.light
            ? Brightness.light
            : Brightness.dark;

        expect(environment.effectiveBrightness, expected);
        expect(environment.palette.isLight, expected == Brightness.light);
        expect(theme.brightness, expected);
        if (profile == OrbitProfile.flow) {
          expect(
            debugFlowGradientColors(environment.palette).first,
            expected == Brightness.light
                ? const Color(0xFFF2FBFD)
                : const Color(0xFF061B2A),
          );
        }
      });
    }
  }

  testWidgets('System reacts to actual platform brightness changes', (
    tester,
  ) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await _pump(
      tester,
      const AppearanceSettings(
        themeMode: ThemeMode.system,
        quality: OrbitQuality.eco,
        motionEnabled: false,
      ),
    );
    var context = tester.element(find.byType(TodayScreen));
    expect(OrbitEnvironment.of(context).effectiveBrightness, Brightness.dark);

    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.light;
    await tester.pump();
    context = tester.element(find.byType(TodayScreen));
    expect(OrbitEnvironment.of(context).effectiveBrightness, Brightness.light);
    expect(OrbitEnvironment.of(context).palette.isLight, isTrue);
    expect(Theme.of(context).brightness, Brightness.light);
  });

  test('ThemeMode persists through OrbitStyleManager recreation', () async {
    final repository = MemoryAppearanceRepository(
      const AppearanceSettings(themeMode: ThemeMode.light),
    );
    final initial = OrbitStyleManager(repository);
    await initial.load();
    await initial.setThemeMode(ThemeMode.dark);

    final restored = OrbitStyleManager(repository);
    await restored.load();
    expect(restored.settings.themeMode, ThemeMode.dark);
  });
}
