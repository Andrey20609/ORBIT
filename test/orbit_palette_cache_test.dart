import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_brightness_palette.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';

import 'orbit_test_harness.dart';

void main() {
  test('resolve returns canonical instances', () {
    OrbitBrightnessPalette.debugClearCache();
    const accent = Color(0xFF9B8CFF);
    final first = OrbitBrightnessPalette.resolve(
      OrbitProfile.one,
      Brightness.dark,
      accent,
    );
    final second = OrbitBrightnessPalette.resolve(
      OrbitProfile.one,
      Brightness.dark,
      accent,
    );
    expect(identical(first, second), isTrue);
    final other = OrbitBrightnessPalette.resolve(
      OrbitProfile.one,
      Brightness.light,
      accent,
    );
    expect(identical(first, other), isFalse);
  });

  test('cache stays bounded', () {
    OrbitBrightnessPalette.debugClearCache();
    for (var index = 0; index < 500; index++) {
      OrbitBrightnessPalette.resolve(
        OrbitProfile.flow,
        Brightness.dark,
        Color(0xFF000000 | index),
      );
    }
    expect(OrbitBrightnessPalette.debugCacheSize, lessThanOrEqualTo(64));
  });

  testWidgets('palette keeps identity across unrelated rebuilds', (
    tester,
  ) async {
    final harness = await pumpOrbitApp(tester);
    final before = OrbitEnvironment.of(orbitShellContext(tester)).palette;
    harness.appState.registerQuickAction();
    await tester.pumpAndSettle();
    final after = OrbitEnvironment.of(orbitShellContext(tester)).palette;
    expect(identical(before, after), isTrue);
  });

  testWidgets('accent change produces a new palette with accent applied', (
    tester,
  ) async {
    final harness = await pumpOrbitApp(
      tester,
      settings: const AppearanceSettings(
        themeMode: ThemeMode.dark,
        quality: OrbitQuality.eco,
        motionEnabled: false,
      ),
    );
    final before = OrbitEnvironment.of(orbitShellContext(tester)).palette;
    await harness.style.setAccentColor(const Color(0xFF33CC99));
    await tester.pumpAndSettle();
    final after = OrbitEnvironment.of(orbitShellContext(tester)).palette;
    expect(identical(before, after), isFalse);
    expect(after.accent, const Color(0xFF33CC99));
  });
}
