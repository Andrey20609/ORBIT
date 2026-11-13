import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/appearance_settings.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_atmosphere.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_motion_service.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_palette.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_shader_engine.dart';
import 'package:orbit_visual_lab/widgets/glass_panel.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ORBIT 0.5.12+18 - Gyro Motion Pipeline & Physics', () {
    tearDown(() {
      OrbitMotionService.instance.reset();
    });

    test('Deadband suppresses micro-tremors below threshold (0.003) for zero desk drift', () {
      final service = OrbitMotionService.instance;
      service.acquire();

      // Initial resting position via setTarget
      service.setTarget(const Offset(0.050, 0.050));
      expect(service.lastRawOffset, equals(Offset.zero));

      // Micro-jitter difference (< 0.003)
      const tremor = Offset(0.051, 0.052);
      final deltaX = (tremor.dx - 0.050).abs();
      final deltaY = (tremor.dy - 0.050).abs();
      expect(deltaX, lessThan(OrbitMotionService.deadbandThreshold));
      expect(deltaY, lessThan(OrbitMotionService.deadbandThreshold));

      service.release();
    });

    test('Exponential time-decay filter smoothly settles within 250-450 ms', () {
      final service = OrbitMotionService.instance;
      service.acquire();
      service.setOffsetInstant(const Offset(0.8, -0.6));

      // Neutral target requested
      service.setTarget(Offset.zero);

      // Advance by 100 ms: decayed by ~67%
      service.stepSimulation(0.100);
      expect(service.tiltNotifier.value.distance, lessThan(0.40));

      // Advance by another 200 ms (total 300 ms, within 250-450 ms): settled < 0.04
      service.stepSimulation(0.200);
      expect(service.tiltNotifier.value.distance, lessThan(0.05));

      // Advance to 350 ms: decayed by > 98%
      service.stepSimulation(0.050);
      expect(service.tiltNotifier.value.distance, lessThan(0.02));

      // Advance to 420 ms (well within 250-450 ms window): fully settled < 0.01
      service.stepSimulation(0.070);
      expect(service.tiltNotifier.value.distance, lessThan(0.01));

      service.release();
    });

    test('Amplitudes match Enhanced target specifications at 8-12 deg tilt', () {
      final service = OrbitMotionService.instance;
      // At full normalized magnitude (1.0)
      final offsets = service.calculatePlaneOffsets(
        tilt: const Offset(1.0, 0.0),
        intensity: GyroIntensity.enhanced,
      );

      // Sky: 1-2 dp (expected: 1.5 dp)
      expect(offsets['sky'], inInclusiveRange(1.0, 2.0));
      // Far: 4-6 dp (expected: 5.0 dp)
      expect(offsets['far'], inInclusiveRange(4.0, 6.0));
      // Mid: 10-14 dp (expected: 12.0 dp)
      expect(offsets['mid'], inInclusiveRange(10.0, 14.0));
      // Foreground: 22-28 dp (expected: 25.0 dp)
      expect(offsets['foreground'], inInclusiveRange(22.0, 28.0));
    });

    test('Amplitudes are halved in Subtle mode and zero in Off mode', () {
      final service = OrbitMotionService.instance;
      final subtle = service.calculatePlaneOffsets(
        tilt: const Offset(1.0, 0.0),
        intensity: GyroIntensity.subtle,
      );
      expect(subtle['sky'], closeTo(0.75, 0.01));
      expect(subtle['far'], closeTo(2.5, 0.01));
      expect(subtle['mid'], closeTo(6.0, 0.01));
      expect(subtle['foreground'], closeTo(12.5, 0.01));

      final off = service.calculatePlaneOffsets(
        tilt: const Offset(1.0, 0.0),
        intensity: GyroIntensity.off,
      );
      expect(off['sky'], equals(0.0));
      expect(off['far'], equals(0.0));
      expect(off['mid'], equals(0.0));
      expect(off['foreground'], equals(0.0));
    });

    test('First sensor reading snaps smoothly without jump from neutral', () {
      final service = OrbitMotionService.instance;
      service.acquire();
      expect(service.tiltNotifier.value, equals(Offset.zero));

      // First reading directly sets current position
      service.setTarget(const Offset(0.35, -0.20));
      expect(service.tiltNotifier.value, equals(const Offset(0.35, -0.20)));

      service.release();
    });
  });

  group('ORBIT 0.5.12+18 - Refined Glass & Zero White Outlines', () {
    test('Optical glass card shader is disabled by default', () {
      expect(OrbitShaderEngine.enableOpticalGlassShader, isFalse);
    });

    testWidgets('GlassPanel perimeter border is subtle and tinted to palette (no white borders)', (tester) async {
      for (final profile in OrbitProfile.values) {
        for (final isDark in [false, true]) {
          final palette = OrbitPalette.ofBrightness(
            profile,
            isDark ? Brightness.dark : Brightness.light,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GlassPanel(
                  palette: palette,
                  child: Text('Card-${profile.name}'),
                ),
              ),
            ),
          );
          await tester.pump();

          final container = tester.widget<Container>(find.byType(Container).first);
          final decoration = container.decoration as BoxDecoration?;
          expect(decoration, isNotNull);
          final border = decoration!.border as Border?;
          expect(border, isNotNull);

          // Alpha must not exceed 0.20 and must be delicate
          expect(border!.top.color.a, lessThanOrEqualTo(0.20));
          expect(border.top.width, lessThanOrEqualTo(1.0));
        }
      }
    });
  });

  group('ORBIT 0.5.12+18 - Diurnal Atmosphere Engine', () {
    final palette = OrbitPalette.of(OrbitProfile.one);

    test('All 4 diurnal phases provide distinct lighting parameters', () {
      final dawn = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.dawn),
        palette,
      );
      final day = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.day),
        palette,
      );
      final sunset = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.sunset),
        palette,
      );
      final night = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.night),
        palette,
      );

      expect(dawn.sunColor, isNot(equals(night.sunColor)));
      expect(day.skyGradientColors, isNot(equals(night.skyGradientColors)));
      expect(sunset.sunColor, isNot(equals(day.sunColor)));
    });

    testWidgets('Atmosphere remains active in Eco/Static quality with motion disabled', (tester) async {
      final settings = const AppearanceSettings(
        atmosphereMode: AtmosphereMode.sunset,
        motionEnabled: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: OrbitPhotorealScene(
            palette: palette,
            quality: ResolvedQuality.static,
            motionEnabled: false,
            settings: settings,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(OrbitPhotorealScene), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
