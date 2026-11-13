import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';

void main() {
  test('aspects compare immutable data and appearance snapshots', () async {
    final appState = OrbitAppState();
    await appState.load();
    final style = OrbitStyleManager(MemoryAppearanceRepository());
    await style.load();
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);
    final previous = OrbitEnvironment(
      style: style,
      quality: quality,
      appState: appState,
      appearanceSettings: style.settings,
      resolvedQuality: quality.resolve(style.settings),
      dataRevision: 0,
      graphicsFallbackReason: null,
      child: const SizedBox.shrink(),
    );
    appState.addTask('aspect-local-task');
    final current = OrbitEnvironment(
      style: style,
      quality: quality,
      appState: appState,
      appearanceSettings: style.settings,
      resolvedQuality: quality.resolve(style.settings),
      dataRevision: appState.dataRevision,
      graphicsFallbackReason: null,
      child: const SizedBox.shrink(),
    );
    expect(
      current.updateShouldNotifyDependent(previous, {
        OrbitEnvironment.dataAspect,
      }),
      isTrue,
    );
    expect(
      current.updateShouldNotifyDependent(previous, {
        OrbitEnvironment.appearanceAspect,
      }),
      isFalse,
    );
    expect(
      current.updateShouldNotifyDependent(previous, {
        OrbitEnvironment.qualityAspect,
      }),
      isFalse,
    );
  });

  testWidgets('local task edit does not rebuild the Today scene', (
    tester,
  ) async {
    final appState = OrbitAppState();
    await appState.load();
    final style = OrbitStyleManager(
      MemoryAppearanceRepository(
        const AppearanceSettings(
          quality: OrbitQuality.eco,
          motionEnabled: false,
          themeMode: ThemeMode.dark,
        ),
      ),
    );
    await style.load();
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);
    await tester.pumpWidget(
      OrbitVisualLabApp(style: style, quality: quality, appState: appState),
    );
    await tester.pumpAndSettle();
    OrbitPhotorealScene.debugBuildCount = 0;

    appState.addTask('scene-must-not-rebuild');
    await tester.pump();
    expect(OrbitPhotorealScene.debugBuildCount, 0);

    await style.setThemeMode(ThemeMode.light);
    await tester.pump();
    expect(OrbitPhotorealScene.debugBuildCount, greaterThan(0));
  });
}
