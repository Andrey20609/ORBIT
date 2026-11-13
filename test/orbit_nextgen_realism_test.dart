import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Visual Engine 2.1: Solar Atmosphere & Diurnal Engine', () {
    final palette = OrbitPalette.of(OrbitProfile.atelier);

    test('Dawn (07:00) computes sunrise arc and warm sunrise tint', () {
      final dawnTime = DateTime(2026, 11, 10, 7, 0); // 07:00
      final atmo = OrbitAtmosphere.fromDateTime(dawnTime, palette);

      expect(atmo.timeOfDay, OrbitTimeOfDay.dawn);
      expect(atmo.sunAlignment.x, greaterThan(0)); // Rising in the East
      expect(atmo.sunColor, isNot(equals(palette.sun))); // Lerped sunrise tint
      expect(atmo.ambientSkyTint, isNotEmpty);
      expect(atmo.sunRadius, greaterThanOrEqualTo(0.85));
    });

    test('Solar Noon (12:30) computes high zenith arc and pure day lighting', () {
      final noonTime = DateTime(2026, 11, 10, 12, 30); // 12:30
      final atmo = OrbitAtmosphere.fromDateTime(noonTime, palette);

      expect(atmo.timeOfDay, OrbitTimeOfDay.day);
      expect(atmo.sunAlignment.y, lessThan(-0.5)); // High in the sky
      expect(atmo.sunColor, equals(palette.sun));
      expect(atmo.starlightIntensity, equals(0.0));
    });

    test('Sunset / Golden Hour (18:30) computes amber-crimson horizon glow', () {
      final sunsetTime = DateTime(2026, 11, 10, 18, 30); // 18:30
      final atmo = OrbitAtmosphere.fromDateTime(sunsetTime, palette);

      expect(atmo.timeOfDay, OrbitTimeOfDay.sunset);
      expect(atmo.sunAlignment.x, lessThan(0)); // Setting in the West
      expect(atmo.ambientSkyTint, isNotEmpty);
      expect(atmo.sunRadius, greaterThan(1.0)); // Atmospheric magnification on horizon
    });

    test('Deep Night (23:45) computes silvery moonlight and starry sky', () {
      final nightTime = DateTime(2026, 11, 10, 23, 45); // 23:45
      final atmo = OrbitAtmosphere.fromDateTime(nightTime, palette);

      expect(atmo.timeOfDay, OrbitTimeOfDay.night);
      expect(atmo.starlightIntensity, equals(1.0));
      expect(atmo.sunColor, const Color(0xFFCBE3FF)); // Silvery moonlight
    });

    test('OrbitAtmosphere.lerp smoothly interpolates between diurnal states', () {
      final dawn = OrbitAtmosphere.fromDateTime(DateTime(2026, 1, 1, 7, 0), palette);
      final noon = OrbitAtmosphere.fromDateTime(DateTime(2026, 1, 1, 12, 0), palette);

      final mid = OrbitAtmosphere.lerp(dawn, noon, 0.5);
      expect(mid.sunAlignment.x, closeTo((dawn.sunAlignment.x + noon.sunAlignment.x) / 2, 0.01));
      expect(mid.sunAlignment.y, closeTo((dawn.sunAlignment.y + noon.sunAlignment.y) / 2, 0.01));
      expect(mid.sunRadius, closeTo((dawn.sunRadius + noon.sunRadius) / 2, 0.01));
    });
  });

  group('Visual Engine 2.1: Physical Gyro & Subscription Lifecycle', () {
    final service = OrbitMotionService.instance;

    setUp(() {
      service.reset();
    });

    test('motion damping smoothly interpolates sudden tilt changes', () {
      expect(service.tiltNotifier.value, Offset.zero);

      // Initial reading snaps to prevent jumps
      service.setTarget(const Offset(0.2, 0.2));
      expect(service.tiltNotifier.value, const Offset(0.2, 0.2));

      // Subsequent reading applies low-pass damping
      service.setTarget(const Offset(1.0, 1.0));
      final secondStep = service.tiltNotifier.value;
      expect(secondStep.dx, greaterThan(0.2));
      expect(secondStep.dx, lessThan(0.4));
    });

    test('setOffsetInstant overrides smoothing for immediate test verification', () {
      service.setOffsetInstant(const Offset(0.42, -0.75));
      expect(service.tiltNotifier.value, const Offset(0.42, -0.75));
    });

    test('subscriber reference counting manages start and stop cleanly', () {
      expect(service.subscribersCount, 0);

      service.acquire(); // Scene 1 mounts
      expect(service.subscribersCount, 1);

      service.acquire(); // Scene 2 mounts (e.g. Visual Lab preview)
      expect(service.subscribersCount, 2);

      service.release(); // Scene 2 disposes
      expect(service.subscribersCount, 1); // Stream remains active for Scene 1

      service.release(); // Scene 1 disposes
      expect(service.subscribersCount, 0); // Stream safely stops
    });

    test('app lifecycle pause and resume respects subscriber count', () {
      service.acquire();
      expect(service.subscribersCount, 1);

      service.setAppLifecycle(resumed: false); // App minimized
      expect(service.subscribersCount, 1);

      service.setAppLifecycle(resumed: true); // App resumed
      expect(service.subscribersCount, 1);

      service.release();
      expect(service.subscribersCount, 0);
    });
  });
}
