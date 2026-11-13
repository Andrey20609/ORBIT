import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/visual_engine/appearance_settings.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_motion_service.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_palette.dart';
import 'package:orbit_visual_lab/widgets/orbit_living_backdrop.dart';
import 'package:orbit_visual_lab/widgets/orbit_spatial_surfaces.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final palette = OrbitPalette.of(OrbitProfile.one);

  Widget buildTestHarness(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disableAnimations),
        child: Scaffold(
          body: child,
        ),
      ),
    );
  }

  group('OrbitLivingWallpaperController', () {
    test('updates preset, effect, and tilt correctly', () async {
      final controller = OrbitLivingWallpaperController();
      expect(controller.hasCustomWallpaper, isFalse);
      expect(controller.effect, OrbitAtmosphereEffect.auroraRays);

      await controller.setPresetAsset('assets/photoreal/optimized/one_sky_dawn.webp');
      expect(controller.assetPath, 'assets/photoreal/optimized/one_sky_dawn.webp');
      expect(controller.isLivingActive, isTrue);

      controller.setEffect(OrbitAtmosphereEffect.cyberCaustics);
      expect(controller.effect, OrbitAtmosphereEffect.cyberCaustics);

      controller.setSensorTilt(const Offset(0.3, -0.2));
      controller.updateTilt(const Offset(0.2, -0.1));
      expect(controller.gyroTilt.dx, closeTo(0.5, 0.01));
      expect(controller.gyroTilt.dy, closeTo(-0.3, 0.01));

      // Custom bytes
      final fakeBytes = Uint8List(16);
      await controller.setCustomBytes(fakeBytes);
      expect(controller.hasCustomWallpaper, isTrue);
      expect(controller.customBytes, fakeBytes);

      controller.reset();
      expect(controller.hasCustomWallpaper, isFalse);
      expect(controller.isLivingActive, isFalse);
      expect(controller.gyroTilt, Offset.zero);
    });

    test('validates custom file path strictly', () async {
      final controller = OrbitLivingWallpaperController();
      
      // Empty path throws FormatException
      expect(
        () => controller.setCustomFile(''),
        throwsA(isA<FormatException>()),
      );

      // Non-existent path throws FileSystemException
      expect(
        () => controller.setCustomFile('/non_existent_orbit_test_path_12345.png'),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('persists and restores state correctly via SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final controller = OrbitLivingWallpaperController();

      await controller.setPresetAsset('assets/photoreal/optimized/one_sky_sunset.webp');
      controller.setEffect(OrbitAtmosphereEffect.starlight);
      controller.setMotionIntensity(1.6);

      await controller.saveToPreferences(prefs);

      // Create new instance and load
      final restored = OrbitLivingWallpaperController();
      await restored.loadFromPreferences(prefs);

      expect(restored.isLivingActive, isTrue);
      expect(restored.assetPath, 'assets/photoreal/optimized/one_sky_sunset.webp');
      expect(restored.effect, OrbitAtmosphereEffect.starlight);
      expect(restored.motionIntensity, closeTo(1.6, 0.01));
    });
  });

  group('OrbitLivingBackdrop & Studio Sheet Widgets', () {
    testWidgets('renders OrbitLivingBackdrop with child', (tester) async {
      final controller = OrbitLivingWallpaperController();

      await tester.pumpWidget(
        buildTestHarness(
          OrbitLivingBackdrop(
            controller: controller,
            palette: palette,
            child: const Text('Backdrop Content'),
          ),
        ),
      );

      expect(find.text('Backdrop Content'), findsOneWidget);
    });

    testWidgets('OrbitMotionService updates gyroTilt in OrbitLivingBackdrop', (tester) async {
      final controller = OrbitLivingWallpaperController();
      final initialSubscribers = OrbitMotionService.instance.subscribersCount;

      await tester.pumpWidget(
        buildTestHarness(
          OrbitLivingBackdrop(
            controller: controller,
            palette: palette,
            child: const Text('Sensor Content'),
          ),
        ),
      );

      // Verify subscriber was acquired
      expect(OrbitMotionService.instance.subscribersCount, initialSubscribers + 1);

      // Emit sensor tilt event
      OrbitMotionService.instance.tiltNotifier.value = const Offset(0.42, -0.68);
      await tester.pump();

      expect(controller.gyroTilt.dx, closeTo(0.42, 0.01));
      expect(controller.gyroTilt.dy, closeTo(-0.68, 0.01));

      // Unmount and verify subscriber was released
      await tester.pumpWidget(buildTestHarness(const SizedBox.shrink()));
      expect(OrbitMotionService.instance.subscribersCount, initialSubscribers);
    });

    testWidgets('disables motion and atmosphere when disableAnimations is true', (tester) async {
      final controller = OrbitLivingWallpaperController();
      await controller.setPresetAsset('assets/photoreal/optimized/one_sky_dawn.webp');

      await tester.pumpWidget(
        buildTestHarness(
          OrbitLivingBackdrop(
            controller: controller,
            palette: palette,
            child: const Text('Eco Content'),
          ),
          disableAnimations: true,
        ),
      );

      expect(find.text('Eco Content'), findsOneWidget);
      // When animations are disabled, atmosphere painter is suppressed
      final atmospherePainterFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter.runtimeType.toString().contains('LivingAtmosphere'),
      );
      expect(atmospherePainterFinder, findsNothing);
    });

    testWidgets('OrbitLivingAiOrb renders smoothly', (tester) async {
      await tester.pumpWidget(
        buildTestHarness(
          OrbitLivingAiOrb(
            palette: palette,
            size: 40,
          ),
        ),
      );

      expect(find.byType(OrbitLivingAiOrb), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('showOrbitWallpaperStudioSheet opens and interacts with presets', (tester) async {
      final controller = OrbitLivingWallpaperController();

      await tester.pumpWidget(
        buildTestHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showOrbitWallpaperStudioSheet(
                ctx,
                palette: palette,
                profile: OrbitProfile.one,
                controller: controller,
              ),
              child: const Text('Open Studio'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Studio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Живой 2.5D-фон экосистемы'), findsOneWidget);
      expect(find.text('АТМОСФЕРНЫЕ СЦЕНЫ ORBIT'), findsOneWidget);
      expect(find.text('Рассвет One'), findsOneWidget);
      expect(find.text('Золотой Закат'), findsOneWidget);
      expect(find.byKey(const Key('wallpaper-custom-aurora')), findsOneWidget);
      expect(find.byKey(const Key('custom-wallpaper-path-input')), findsOneWidget);

      // Tap preset
      await tester.tap(find.text('Золотой Закат'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.assetPath, 'assets/photoreal/optimized/one_sky_sunset.webp');

      // Select effect
      await tester.ensureVisible(find.text('Звездная глубина и туман'));
      await tester.pump();
      await tester.tap(find.text('Звездная глубина и туман'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.effect, OrbitAtmosphereEffect.starlight);

      // Tap procedural custom wallpaper
      await tester.ensureVisible(find.text('Северное сияние'));
      await tester.pump();
      await tester.tap(find.text('Северное сияние'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.hasCustomWallpaper, isTrue);

      // Try entering invalid custom file path
      await tester.ensureVisible(find.byKey(const Key('custom-wallpaper-path-input')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('custom-wallpaper-path-input')),
        '/invalid_orbit_wallpaper_path_test.jpg',
      );
      await tester.ensureVisible(find.byKey(const Key('apply-custom-wallpaper-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('apply-custom-wallpaper-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Файл не найден или недоступен для чтения'), findsOneWidget);

      // Drain spatial island timer
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('showOrbitWallpaperStudioSheet can be dismissed via close button', (tester) async {
      final controller = OrbitLivingWallpaperController();

      await tester.pumpWidget(
        buildTestHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showOrbitWallpaperStudioSheet(
                ctx,
                palette: palette,
                profile: OrbitProfile.one,
                controller: controller,
              ),
              child: const Text('Open Studio'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Studio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Живой 2.5D-фон экосистемы'), findsOneWidget);
      expect(find.byKey(const Key('close-wallpaper-studio-button')), findsOneWidget);

      // Tap close button in header
      await tester.tap(find.byKey(const Key('close-wallpaper-studio-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Sheet is closed
      expect(find.text('Живой 2.5D-фон экосистемы'), findsNothing);
    });

    testWidgets('showOrbitWallpaperStudioSheet dismisses on downward swipe on grabber header', (tester) async {
      final controller = OrbitLivingWallpaperController();

      await tester.pumpWidget(
        buildTestHarness(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showOrbitWallpaperStudioSheet(
                ctx,
                palette: palette,
                profile: OrbitProfile.one,
                controller: controller,
              ),
              child: const Text('Open Studio'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Studio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Живой 2.5D-фон экосистемы'), findsOneWidget);

      // Drag downward with velocity on the header area
      await tester.fling(find.text('Живой 2.5D-фон экосистемы'), const Offset(0, 300), 800);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Sheet is closed
      expect(find.text('Живой 2.5D-фон экосистемы'), findsNothing);
    });

    testWidgets('OrbitLivingBackdrop updates wallpaperKey and AnimatedSwitcher renders', (tester) async {
      final controller = OrbitLivingWallpaperController();
      await controller.setPresetAsset('assets/photoreal/optimized/one_sky_dawn.webp');

      await tester.pumpWidget(
        buildTestHarness(
          OrbitLivingBackdrop(
            controller: controller,
            palette: palette,
            child: const Text('Wallpaper Content'),
          ),
        ),
      );

      expect(find.text('Wallpaper Content'), findsOneWidget);
      expect(controller.wallpaperKey, contains('one_sky_dawn'));

      // Switch to sunset
      await controller.setPresetAsset('assets/photoreal/optimized/one_sky_sunset.webp');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(controller.wallpaperKey, contains('one_sky_sunset'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Wallpaper Content'), findsOneWidget);
    });

    testWidgets('showOrbitSpatialIsland renders and auto-dismisses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScaffoldMessenger(
            child: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => showOrbitSpatialIsland(
                    ctx,
                    palette: palette,
                    title: 'Тестовое уведомление',
                    actionLabel: 'OK',
                    onAction: () {},
                    duration: const Duration(milliseconds: 500),
                  ),
                  child: const Text('Show Island'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Island'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Тестовое уведомление'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);

      // Wait for auto-dismiss
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Тестовое уведомление'), findsNothing);
    });
  });
}
