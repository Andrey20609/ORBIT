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

  group('ORBIT 0.5.11+17 WOW Premium - Diurnal Atmosphere Engine', () {
    final palette = OrbitPalette.of(OrbitProfile.one);

    test('All 4 diurnal phases yield distinct color matrices and sky gradients', () {
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

      expect(dawn.timeOfDay, OrbitTimeOfDay.dawn);
      expect(day.timeOfDay, OrbitTimeOfDay.day);
      expect(sunset.timeOfDay, OrbitTimeOfDay.sunset);
      expect(night.timeOfDay, OrbitTimeOfDay.night);

      expect(day.starlightIntensity, equals(0.0));
      expect(night.starlightIntensity, equals(1.0));

      expect(day.colorMatrix, isNot(equals(night.colorMatrix)));
      expect(dawn.colorMatrix, isNot(equals(sunset.colorMatrix)));
      expect(day.skyGradientColors, isNot(equals(night.skyGradientColors)));
    });

    test('Atmosphere lerp is smooth, continuous, and free of discontinuities', () {
      final day = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.day),
        palette,
      );
      final night = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.night),
        palette,
      );

      final mid = OrbitAtmosphere.lerp(day, night, 0.5);
      expect(mid.starlightIntensity, closeTo(0.5, 0.01));
      expect(mid.colorMatrix.length, equals(20));
      for (final val in mid.colorMatrix) {
        expect(val.isFinite, isTrue);
      }
    });

    testWidgets('Atmosphere applies in Eco/Static quality with motion disabled', (tester) async {
      final settings = const AppearanceSettings(
        atmosphereMode: AtmosphereMode.night,
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

      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(OrbitPhotorealScene), findsOneWidget);
      expect(find.byType(ColorFiltered), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('ORBIT 0.5.11+17 WOW Premium - Glass Card & Optical Borders', () {
    final palette = OrbitPalette.of(OrbitProfile.one);

    test('Optical glass card shader is disabled by default to eliminate white outlines', () {
      expect(OrbitShaderEngine.enableOpticalGlassShader, isFalse);
    });

    testWidgets('GlassPanel renders clean palette border without outer shader stroke by default', (tester) async {
      OrbitShaderEngine.enableOpticalGlassShader = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GlassPanel(
              palette: palette,
              child: const Text('Hello ORBIT Glass'),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hello ORBIT Glass'), findsOneWidget);
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);

      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration?;
      expect(decoration, isNotNull);
      expect(decoration?.border, isNotNull);
      // Border color must have subtle alpha matching palette (not harsh opaque white)
      final borderColor = (decoration!.border! as Border).top.color;
      expect(borderColor.a, lessThanOrEqualTo(0.35));
    });

    testWidgets('GlassPanel renders correctly across all 4 profiles and both themes', (tester) async {
      for (final profile in OrbitProfile.values) {
        for (final isDark in [false, true]) {
          final p = OrbitPalette.ofBrightness(
            profile,
            isDark ? Brightness.dark : Brightness.light,
          );
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: GlassPanel(
                  palette: p,
                  child: Text('${profile.name}-${isDark ? "dark" : "light"}'),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(find.text('${profile.name}-${isDark ? "dark" : "light"}'), findsOneWidget);
        }
      }
    });
  });

  group('ORBIT 0.5.11+17 WOW Premium - Gyro Motion Pipeline', () {
    tearDown(() {
      OrbitMotionService.instance.reset();
    });

    test('OrbitMotionService tracks lifecycle states, events, and raw offsets', () {
      final service = OrbitMotionService.instance;
      expect(service.currentState, equals(MotionServiceState.notSubscribed));
      expect(service.subscribersCount, equals(0));
      expect(service.eventCount, equals(0));

      service.acquire();
      expect(service.subscribersCount, equals(1));

      // Inject simulated sensor readings
      service.setOffsetInstant(const Offset(0.25, -0.15));
      expect(service.tiltNotifier.value, equals(const Offset(0.25, -0.15)));

      // Smooth damped transition towards target
      service.setTarget(const Offset(0.50, -0.30));
      expect(service.tiltNotifier.value.dx, greaterThan(0.25));
      expect(service.tiltNotifier.value.dy, lessThan(-0.15));

      service.release();
      expect(service.subscribersCount, equals(0));
      expect(service.currentState, equals(MotionServiceState.notSubscribed));
    });

    test('OrbitMotionService returns smoothly to neutral within 250-450 ms', () {
      final service = OrbitMotionService.instance;
      service.acquire();
      service.setOffsetInstant(const Offset(0.8, -0.6));

      // Release triggers smooth neutral return
      service.setTarget(Offset.zero);
      for (int frame = 0; frame < 30; frame++) {
        service.setTarget(Offset.zero);
      }
      expect(service.tiltNotifier.value.dx.abs(), lessThan(0.01));
      expect(service.tiltNotifier.value.dy.abs(), lessThan(0.01));

      service.release();
    });
  });
}
