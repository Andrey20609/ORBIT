import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_living_backdrop.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dawnAsset = 'assets/photoreal/optimized/one_sky_dawn.webp';
  const dayAsset = 'assets/photoreal/optimized/one_sky_day.webp';
  const sunsetAsset = 'assets/photoreal/optimized/one_sky_sunset.webp';
  const nightAsset = 'assets/photoreal/optimized/one_sky_night.webp';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orbitWallpaperController.reset();
  });

  tearDown(() {
    orbitWallpaperController.reset();
  });

  test('preset clears procedural source instead of leaving stale wallpaper', () async {
    final controller = orbitWallpaperController;
    controller.setProceduralTheme('Северное сияние');
    await controller.setCustomBytes(
      Uint8List.fromList(<int>[1, 2, 3]),
      preserveProceduralTheme: true,
    );

    await controller.setPresetAsset(dayAsset);

    expect(controller.proceduralTheme, isNull);
    expect(controller.hasCustomWallpaper, isFalse);
    expect(controller.assetPath, dayAsset);
    expect(controller.isLivingActive, isTrue);
  });

  test('atmosphere sync preserves custom image and persists selected mode', () async {
    final controller = orbitWallpaperController;
    final bytes = Uint8List.fromList(<int>[4, 5, 6, 7]);
    await controller.setCustomBytes(bytes);

    await controller.syncWithAtmosphereMode(AtmosphereMode.day);

    expect(controller.customBytes, same(bytes));
    expect(controller.hasCustomWallpaper, isTrue);
    expect(controller.atmosphereMode, AtmosphereMode.day);

    final restored = OrbitLivingWallpaperController();
    restored.applyJson(controller.toJson());
    expect(restored.atmosphereMode, AtmosphereMode.day);
  });

  test('sync does not activate living wallpaper that user never enabled', () async {
    final controller = orbitWallpaperController;

    await controller.syncWithAtmosphereMode(AtmosphereMode.day);

    expect(controller.isLivingActive, isFalse);
    expect(controller.hasCustomWallpaper, isFalse);
  });

  test('automatic atmosphere follows dawn, day, sunset and night', () async {
    final controller = orbitWallpaperController;
    await controller.setPresetAsset(nightAsset);

    await withClock(Clock.fixed(DateTime(2026, 1, 1, 7)), () async {
      await controller.syncWithAtmosphereMode(AtmosphereMode.automatic);
      expect(controller.assetPath, dawnAsset);
    });
    await withClock(Clock.fixed(DateTime(2026, 1, 1, 12)), () async {
      await controller.syncWithAtmosphereMode(AtmosphereMode.automatic);
      expect(controller.assetPath, dayAsset);
    });
    await withClock(Clock.fixed(DateTime(2026, 1, 1, 18, 45)), () async {
      await controller.syncWithAtmosphereMode(AtmosphereMode.automatic);
      expect(controller.assetPath, sunsetAsset);
    });
    await withClock(Clock.fixed(DateTime(2026, 1, 1, 23, 30)), () async {
      await controller.syncWithAtmosphereMode(AtmosphereMode.automatic);
      expect(controller.assetPath, nightAsset);
    });
  });

  testWidgets('custom wallpaper receives atmosphere color processing', (tester) async {
    final controller = orbitWallpaperController;
    await controller.setCustomBytes(Uint8List(16));

    await tester.pumpWidget(
      MaterialApp(
        home: OrbitLivingBackdrop(
          controller: controller,
          palette: OrbitPalette.of(OrbitProfile.one),
          child: const Text('content'),
        ),
      ),
    );

    expect(find.byType(ColorFiltered), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('application listener switches built-in wallpaper on setting change', (tester) async {
    await orbitWallpaperController.setPresetAsset(dawnAsset);
    final style = OrbitStyleManager(MemoryAppearanceRepository());
    await style.load();
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);

    await tester.pumpWidget(
      OrbitVisualLabApp(
        style: style,
        quality: quality,
        appState: OrbitAppState(),
      ),
    );
    await tester.pump();

    await style.setAtmosphereMode(AtmosphereMode.night);
    await tester.pump();

    expect(orbitWallpaperController.assetPath, nightAsset);
    expect(orbitWallpaperController.atmosphereMode, AtmosphereMode.night);
  });
}
