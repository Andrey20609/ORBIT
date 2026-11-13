import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_frame_metrics.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile scroll UI, raster and total-span metrics', (
    tester,
  ) async {
    final refreshRate =
        tester.binding.platformDispatcher.views.first.display.refreshRate;
    final results = <String, Object?>{};
    final configurations = <(String, AppearanceSettings)>[
      (
        'layered-balanced',
        const AppearanceSettings(
          profile: OrbitProfile.one,
          quality: OrbitQuality.balanced,
          renderer: TodayRenderer.procedural,
        ),
      ),
      (
        'flow-balanced',
        const AppearanceSettings(
          profile: OrbitProfile.flow,
          quality: OrbitQuality.balanced,
          renderer: TodayRenderer.procedural,
        ),
      ),
      (
        'flow-ultra',
        const AppearanceSettings(
          profile: OrbitProfile.flow,
          quality: OrbitQuality.ultra,
          renderer: TodayRenderer.procedural,
        ),
      ),
      (
        'rive-balanced',
        const AppearanceSettings(
          profile: OrbitProfile.one,
          quality: OrbitQuality.balanced,
          renderer: TodayRenderer.rive,
        ),
      ),
      (
        'filament-balanced',
        const AppearanceSettings(
          profile: OrbitProfile.one,
          quality: OrbitQuality.balanced,
          renderer: TodayRenderer.filament,
        ),
      ),
    ];

    for (final (label, settings) in configurations) {
      final style = OrbitStyleManager(MemoryAppearanceRepository(settings));
      await style.load();
      final appState = OrbitAppState();
      await appState.load();
      final quality = OrbitQualityManager();
      await tester.pumpWidget(
        OrbitVisualLabApp(style: style, quality: quality, appState: appState),
      );
      await tester.pump(const Duration(seconds: 3));

      final metrics = OrbitFrameMetrics();
      void collect(List<FrameTiming> frames) => metrics.addAll(frames);
      SchedulerBinding.instance.addTimingsCallback(collect);
      final scrollable = find.byKey(const Key('today-scroll'));
      for (var pass = 0; pass < 4; pass++) {
        await tester.fling(scrollable, const Offset(0, -700), 2200);
        await tester.pump(const Duration(seconds: 2));
        await tester.fling(scrollable, const Offset(0, 700), 2200);
        await tester.pump(const Duration(seconds: 2));
      }
      SchedulerBinding.instance.removeTimingsCallback(collect);
      results[label] = metrics.snapshot(refreshRateHz: refreshRate);
      debugPrint('[ORBIT perf] $label=${jsonEncode(results[label])}');
      quality.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
    binding.reportData = <String, dynamic>{
      'scrollPerf': results,
      'refreshRateHz': refreshRate,
      'measurement':
          'UI build, raster and totalSpan are separate; no FPS claim',
    };
    debugPrint('[ORBIT perf] summary=${jsonEncode(results)}');
  });
}
