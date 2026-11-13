import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/appearance_settings.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_palette.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';

double _luminance(Color color) {
  double channel(double value) => value <= 0.04045
      ? value / 12.92
      : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrast(Color foreground, Color background) {
  final first = _luminance(foreground);
  final second = _luminance(background);
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    test('Flow ${brightness.name} foreground and control contrast', () {
      final palette = OrbitPalette.ofBrightness(OrbitProfile.flow, brightness);
      for (final background in debugFlowGradientColors(palette)) {
        expect(
          _contrast(palette.textPrimary, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(palette.textSecondary, background),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrast(palette.accent, background), greaterThanOrEqualTo(3));
        expect(
          _contrast(palette.accentSecondary, background),
          greaterThanOrEqualTo(3),
        );
      }
    });

    testWidgets('Flow ${brightness.name} rendered scene pixels', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 5, 9, 41)), () async {
        tester.view.physicalSize = const Size(411, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final palette = OrbitPalette.ofBrightness(OrbitProfile.flow, brightness);
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: const Key('flow-scene-test'),
              child: OrbitPhotorealScene(
                palette: palette,
                quality: ResolvedQuality.static,
                motionEnabled: false,
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 250)),
        );
        await tester.pump();
        await expectLater(
          find.byKey(const Key('flow-scene-test')),
          matchesGoldenFile('goldens/flow_scene_${brightness.name}.png'),
        );
      });
    });
  }
}
