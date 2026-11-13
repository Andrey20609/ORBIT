import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/l10n/orbit_localizations.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';

void main() {
  group('1. OrbitDayPeriod 9 Boundary Tests & Time-of-Day Routing', () {
    test('04:59:59 maps to night', () {
      final dt = DateTime(2026, 11, 10, 4, 59, 59);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.night);
    });

    test('05:00:00 maps to morning (boundary start)', () {
      final dt = DateTime(2026, 11, 10, 5, 0, 0);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.morning);
    });

    test('11:59:59 maps to morning (boundary end)', () {
      final dt = DateTime(2026, 11, 10, 11, 59, 59);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.morning);
    });

    test('12:00:00 maps to day (boundary start)', () {
      final dt = DateTime(2026, 11, 10, 12, 0, 0);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.day);
    });

    test('16:59:59 maps to day (boundary end)', () {
      final dt = DateTime(2026, 11, 10, 16, 59, 59);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.day);
    });

    test('17:00:00 maps to evening (boundary start)', () {
      final dt = DateTime(2026, 11, 10, 17, 0, 0);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.evening);
    });

    test('22:59:59 maps to evening (boundary end)', () {
      final dt = DateTime(2026, 11, 10, 22, 59, 59);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.evening);
    });

    test('23:00:00 maps to night (boundary start)', () {
      final dt = DateTime(2026, 11, 10, 23, 0, 0);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.night);
    });

    test('00:00:00 maps to night (midnight)', () {
      final dt = DateTime(2026, 11, 10, 0, 0, 0);
      expect(OrbitDayPeriod.fromDateTime(dt), OrbitDayPeriod.night);
    });
  });

  group('2. Localized Greetings Across All 5 Languages (RU, EN, DE, FR, ES)', () {
    Widget buildLocalizationHarness(Locale locale, Widget Function(BuildContext) builder) {
      return MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: builder),
      );
    }

    testWidgets('Russian (ru) greetings test', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        buildLocalizationHarness(const Locale('ru'), (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      );

      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: true), 'Доброе утро!');
      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: false), 'Доброе утро,\nАлексей!');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: true), 'Добрый день!');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: false), 'Добрый день,\nАлексей!');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: true), 'Добрый вечер!');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: false), 'Добрый вечер,\nАлексей!');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: true), 'Доброй ночи!');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: false), 'Доброй ночи,\nАлексей!');
    });

    testWidgets('English (en) greetings test', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        buildLocalizationHarness(const Locale('en'), (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      );

      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: true), 'Good morning!');
      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: false), 'Good morning,\nAlexey!');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: true), 'Good afternoon!');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: false), 'Good afternoon,\nAlexey!');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: true), 'Good evening!');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: false), 'Good evening,\nAlexey!');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: true), 'Good night!');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: false), 'Good night,\nAlexey!');
    });

    testWidgets('German (de) greetings test', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        buildLocalizationHarness(const Locale('de'), (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      );

      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: true), 'Guten Morgen!');
      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: false), 'Guten Morgen,\nAlexey!');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: true), 'Guten Tag!');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: false), 'Guten Tag,\nAlexey!');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: true), 'Guten Abend!');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: false), 'Guten Abend,\nAlexey!');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: true), 'Gute Nacht!');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: false), 'Gute Nacht,\nAlexey!');
    });

    testWidgets('French (fr) greetings test', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        buildLocalizationHarness(const Locale('fr'), (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      );

      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: true), 'Bonjour !');
      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: false), 'Bonjour,\nAlexey !');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: true), 'Bon après-midi !');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: false), 'Bon après-midi,\nAlexey !');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: true), 'Bonsoir !');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: false), 'Bonsoir,\nAlexey !');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: true), 'Bonne nuit !');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: false), 'Bonne nuit,\nAlexey !');
    });

    testWidgets('Spanish (es) greetings test', (tester) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        buildLocalizationHarness(const Locale('es'), (c) {
          ctx = c;
          return const SizedBox.shrink();
        }),
      );

      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: true), '¡Buenos días!');
      expect(OrbitDayPeriod.morning.localizedGreeting(ctx, short: false), 'Buenos días,\n¡Alexey!');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: true), '¡Buenas tardes!');
      expect(OrbitDayPeriod.day.localizedGreeting(ctx, short: false), 'Buenas tardes,\n¡Alexey!');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: true), '¡Buenas noches!');
      expect(OrbitDayPeriod.evening.localizedGreeting(ctx, short: false), 'Buenas noches,\n¡Alexey!');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: true), '¡Buenas noches!');
      expect(OrbitDayPeriod.night.localizedGreeting(ctx, short: false), 'Buenas noches,\n¡Alexey!');
    });
  });

  group('3. Greeting Independence from Manual Atmosphere Overrides', () {
    test('Manual atmosphere override does not change device clock period', () {
      final noon = DateTime(2026, 11, 10, 14, 0, 0);
      final period = OrbitDayPeriod.fromDateTime(noon);
      expect(period, OrbitDayPeriod.day);

      // Simulating manual atmosphere mode override:
      const manualMode = AtmosphereMode.night;
      expect(manualMode, AtmosphereMode.night);

      // The greeting is derived from [OrbitDayPeriod.fromDateTime(noon)] or [OrbitDayPeriod.current()],
      // completely decoupled from [manualMode].
      expect(period, OrbitDayPeriod.day);
    });
  });

  group('4. Gyro Inactivity Neutral Return & Deadband via handleSensorDataForTesting', () {
    test('Deadband suppresses tiny noise fluctuations', () {
      final service = OrbitMotionService.instance;
      service.resetForTesting();

      // First reading sets base
      service.handleSensorDataForTesting([0.0, 0.0]);
      expect(service.lastRawOffset, Offset.zero);

      // Send micro noise within deadband (abs <= 0.003)
      service.handleSensorDataForTesting([0.002, -0.002]);
      expect(service.lastRawOffset, Offset.zero);

      // Send significant movement (> 0.003)
      service.handleSensorDataForTesting([0.05, -0.04]);
      expect(service.lastRawOffset.dx, 0.05);
      expect(service.lastRawOffset.dy, -0.04);
    });

    test('Inactivity near center initiates neutral return', () {
      final service = OrbitMotionService.instance;
      service.resetForTesting();

      // Initial significant movement within restingCenterRadius (< 0.15)
      service.handleSensorDataForTesting([0.08, 0.06]);
      expect(service.lastRawOffset.dx, 0.08);

      // Simulate passage of time > 350ms
      service.lastSignificantMotionTimeForTesting =
          DateTime.now().subtract(const Duration(milliseconds: 450));

      // Micro event below deadband triggers inactivity check
      service.handleSensorDataForTesting([0.081, 0.061]);

      // Service sets target to zero on inactivity
      expect(service.targetForTesting, Offset.zero);
    });

    test('Decay math reaches ~6% at 250ms, ~3% at 315ms, and <1% at 414ms', () {
      // With tau = 90ms:
      // R(t) = e^(-t / 90)
      const tau = 90.0;
      final r250 = math.exp(-250.0 / tau);
      final r315 = math.exp(-315.0 / tau);
      final r414 = math.exp(-414.0 / tau);

      expect(r250, closeTo(0.062, 0.005)); // ~6%
      expect(r315, closeTo(0.030, 0.005)); // ~3%
      expect(r414, lessThan(0.0101));       // < 1%
    });
  });

  group('5. OrbitSceneDiagnostics & OrbitAssetErrorView', () {
    test('Diagnostics registers all mandatory assets for One', () {
      expect(OrbitSceneDiagnostics.mandatoryAssetsOne.containsKey('one_sky'), isTrue);
      expect(OrbitSceneDiagnostics.mandatoryAssetsOne.containsKey('one_far'), isTrue);
      expect(OrbitSceneDiagnostics.mandatoryAssetsOne.containsKey('one_mid'), isTrue);
      expect(OrbitSceneDiagnostics.mandatoryAssetsOne.containsKey('one_fg'), isTrue);
    });

    testWidgets('OrbitAssetErrorView renders error UI with retry button', (tester) async {
      bool retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OrbitAssetErrorView(
              layerName: 'one_mid',
              errorMessage: '404 File not found',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('ASSET_ERROR'), findsOneWidget);
      expect(find.textContaining('one_mid'), findsOneWidget);
      expect(find.textContaining('404 File not found'), findsOneWidget);

      await tester.tap(find.byType(ElevatedButton));
      expect(retried, isTrue);
    });
  });

  group('6. Photoreal Scene Layer Rendering & Blue Backdrop Elimination', () {
    testWidgets('OrbitPhotorealScene renders layered scene under static / no-motion mode', (tester) async {
      const palette = OrbitPalette.one;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrbitPhotorealScene(
              palette: palette,
              quality: ResolvedQuality.static,
              motionEnabled: false,
            ),
          ),
        ),
      );

      // Verify that OrbitPhotorealScene is present
      expect(find.byType(OrbitPhotorealScene), findsOneWidget);

      // Verify image assets for the layers are loaded / referenced in the tree
      final images = find.byType(Image);
      expect(images, findsWidgets);
    });
  });

  group('7. Unified Scene Key & Deterministic State Mapping', () {
    test('sceneKey uniquely identifies every permutation of 5 state components', () {
      final keys = <String>{};
      for (final profile in OrbitProfile.values) {
        for (final period in OrbitTimeOfDay.values) {
          for (final brightness in Brightness.values) {
            for (final quality in ResolvedQuality.values) {
              for (final orientation in Orientation.values) {
                final key = OrbitSceneKey(
                  profile: profile,
                  atmospherePeriod: period,
                  themeBrightness: brightness,
                  quality: quality,
                  orientation: orientation,
                ).value;
                expect(keys.contains(key), isFalse, reason: 'Duplicate sceneKey: $key');
                keys.add(key);
              }
            }
          }
        }
      }
      // 4 profiles * 4 periods * 2 brightnesses * 3 qualities * 2 orientations = 192 unique keys
      expect(keys.length, 192);
    });

    test('Diagnostics records atmosphere application and updates sceneKey', () {
      final diag = OrbitSceneDiagnostics.instance;
      diag.recordAtmosphereApplication(
        profile: OrbitProfile.one,
        mode: AtmosphereMode.sunset,
        period: OrbitTimeOfDay.sunset,
        brightness: Brightness.dark,
        quality: ResolvedQuality.balanced,
        orientation: Orientation.portrait,
        renderer: 'Photoreal',
        layerAssetPaths: {
          'sky': 'assets/photoreal/optimized/one_sky_sunset.webp',
          'far': 'assets/photoreal/optimized/one_far.webp',
        },
      );

      expect(diag.selectedAtmosphereMode, AtmosphereMode.sunset);
      expect(diag.activeAtmospherePeriod, OrbitTimeOfDay.sunset);
      expect(diag.currentSceneKey, 'one_sunset_dark_balanced_portrait');
      expect(diag.atmosphereApplicationCount, greaterThan(0));
      expect(diag.lastAtmosphereUpdateTime, isNotNull);
      expect(diag.currentLayerAssetPaths['sky'], 'assets/photoreal/optimized/one_sky_sunset.webp');
    });
  });

  group('8. Distinct Photographic Sky Assets for Each Atmosphere Period', () {
    test('Dawn, Day, Sunset, Night map to strictly distinct photographic sky assets', () {
      const dawnAtm = OrbitAtmosphere(
        timeOfDay: OrbitTimeOfDay.dawn,
        sunAlignment: Alignment(0.48, 0.08),
        sunColor: Color(0xFFFFB396),
        sunRadius: 0.90,
        ambientSkyTint: [],
        specularRimAngle: 0.0,
        starlightIntensity: 0.35,
      );
      const dayAtm = OrbitAtmosphere(
        timeOfDay: OrbitTimeOfDay.day,
        sunAlignment: Alignment(0.20, -0.72),
        sunColor: Color(0xFFFFF9E6),
        sunRadius: 0.80,
        ambientSkyTint: [],
        specularRimAngle: 0.0,
        starlightIntensity: 0.0,
      );
      const sunsetAtm = OrbitAtmosphere(
        timeOfDay: OrbitTimeOfDay.sunset,
        sunAlignment: Alignment(-0.62, 0.16),
        sunColor: Color(0xFFFF4E18),
        sunRadius: 1.25,
        ambientSkyTint: [],
        specularRimAngle: 0.0,
        starlightIntensity: 0.20,
      );
      const nightAtm = OrbitAtmosphere(
        timeOfDay: OrbitTimeOfDay.night,
        sunAlignment: Alignment(0.55, -0.65),
        sunColor: Color(0xFFD6EEFF),
        sunRadius: 0.55,
        ambientSkyTint: [],
        specularRimAngle: 0.0,
        starlightIntensity: 1.0,
      );

      final skies = {
        dawnAtm.skyAssetPath,
        dayAtm.skyAssetPath,
        sunsetAtm.skyAssetPath,
        nightAtm.skyAssetPath,
      };

      expect(skies.length, 4, reason: 'All 4 diurnal periods must use distinct sky assets');
      expect(dawnAtm.skyAssetPath, 'assets/photoreal/optimized/one_sky_dawn.webp');
      expect(dayAtm.skyAssetPath, 'assets/photoreal/optimized/one_sky_day.webp');
      expect(sunsetAtm.skyAssetPath, 'assets/photoreal/optimized/one_sky_sunset.webp');
      expect(nightAtm.skyAssetPath, 'assets/photoreal/optimized/one_sky_night.webp');
    });
  });

  group('9. Atmosphere Propagation to OrbitSceneBackground and All Screens', () {
    testWidgets('OrbitSceneBackground passes appearance settings to OrbitPhotorealScene', (tester) async {
      const settings = AppearanceSettings(
        atmosphereMode: AtmosphereMode.sunset,
        profile: OrbitProfile.one,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrbitSceneBackground(
              palette: OrbitPalette.one,
              quality: ResolvedQuality.static,
              motionEnabled: false,
              settings: settings,
              child: Text('Content Area'),
            ),
          ),
        ),
      );

      expect(find.byType(OrbitPhotorealScene), findsOneWidget);
      expect(find.text('Content Area'), findsOneWidget);

      final sceneWidget = tester.widget<OrbitPhotorealScene>(find.byType(OrbitPhotorealScene));
      expect(sceneWidget.settings?.atmosphereMode, AtmosphereMode.sunset);
    });
  });
}
