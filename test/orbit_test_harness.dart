import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

final class OrbitHarness {
  const OrbitHarness({
    required this.style,
    required this.appState,
    required this.quality,
    required this.repository,
  });

  final OrbitStyleManager style;
  final OrbitAppState appState;
  final OrbitQualityManager quality;
  final MemoryAppearanceRepository repository;
}

Future<OrbitHarness> pumpOrbitApp(
  WidgetTester tester, {
  AppearanceSettings settings = const AppearanceSettings(
    quality: OrbitQuality.eco,
    motionEnabled: false,
  ),
  MemoryAppearanceRepository? repository,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = repository ?? MemoryAppearanceRepository(settings);
  final style = OrbitStyleManager(repo);
  await style.load();
  final appState = OrbitAppState(MemoryLocalStateRepository());
  await appState.load();
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);

  await tester.pumpWidget(
    OrbitVisualLabApp(style: style, quality: quality, appState: appState),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return OrbitHarness(
    style: style,
    appState: appState,
    quality: quality,
    repository: repo,
  );
}

Future<void> orbitGoToTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(Key('orbit-nav-$index')));
  await tester.pumpAndSettle();
}

BuildContext orbitShellContext(WidgetTester tester) =>
    tester.element(find.byKey(const Key('orbit-shell')));
