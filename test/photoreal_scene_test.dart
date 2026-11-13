import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/appearance_settings.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_palette.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';

void main() {
  for (final profile in OrbitProfile.values) {
    testWidgets('${profile.name} static scene has no running animation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrbitPhotorealScene(
            palette: OrbitPalette.of(profile),
            quality: ResolvedQuality.static,
            motionEnabled: false,
          ),
        ),
      );
      await tester.pump();

      expect(tester.hasRunningAnimations, isFalse);
      expect(
        find.byType(Image),
        profile == OrbitProfile.flow ? findsOneWidget : findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
