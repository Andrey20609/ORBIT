import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/screens/today_screen.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_app_hub_sheet.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_mail_account_sheet.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';

Widget createTestApp(
  Widget child, {
  AtmosphereMode atmosphereMode = AtmosphereMode.automatic,
}) {
  final appState = OrbitAppState(MemoryLocalStateRepository());
  final style = OrbitStyleManager(
    MemoryAppearanceRepository(
      AppearanceSettings(
        profile: OrbitProfile.one,
        atmosphereMode: atmosphereMode,
        quality: OrbitQuality.eco,
        motionEnabled: false,
      ),
    ),
  );
  final quality = OrbitQualityManager();
  final palette = OrbitPalette.ofBrightness(OrbitProfile.one, Brightness.dark);
  return OrbitEnvironment(
    style: style,
    quality: quality,
    appState: appState,
    appearanceSettings: style.settings,
    resolvedQuality: quality.resolve(style.settings),
    dataRevision: appState.dataRevision,
    graphicsFallbackReason: null,
    appearancePersistenceError: null,
    appearanceLoadError: null,
    platformBrightness: Brightness.dark,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: palette.themeData(palette.accent),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Atmosphere Mode & Visual Lab Render Tests', () {
    test('1. All four atmosphere modes generate visually distinct palettes & parameters', () {
      const palette = OrbitPalette.one;

      final dawnAtmosphere = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.dawn),
        palette,
      );
      final dayAtmosphere = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.day),
        palette,
      );
      final sunsetAtmosphere = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.sunset),
        palette,
      );
      final nightAtmosphere = OrbitAtmosphere.fromSettings(
        const AppearanceSettings(atmosphereMode: AtmosphereMode.night),
        palette,
      );

      // Verify time of day classification
      expect(dawnAtmosphere.timeOfDay, OrbitTimeOfDay.dawn);
      expect(dayAtmosphere.timeOfDay, OrbitTimeOfDay.day);
      expect(sunsetAtmosphere.timeOfDay, OrbitTimeOfDay.sunset);
      expect(nightAtmosphere.timeOfDay, OrbitTimeOfDay.night);

      // Verify distinct sun colors
      expect(dawnAtmosphere.sunColor != dayAtmosphere.sunColor, isTrue);
      expect(dayAtmosphere.sunColor != sunsetAtmosphere.sunColor, isTrue);
      expect(sunsetAtmosphere.sunColor != nightAtmosphere.sunColor, isTrue);

      // Verify distinct sky gradients
      expect(dawnAtmosphere.skyGradientColors != dayAtmosphere.skyGradientColors, isTrue);
      expect(dayAtmosphere.skyGradientColors != sunsetAtmosphere.skyGradientColors, isTrue);
      expect(sunsetAtmosphere.skyGradientColors != nightAtmosphere.skyGradientColors, isTrue);

      // Verify night atmosphere has starlight intensity while day does not
      expect(nightAtmosphere.starlightIntensity, greaterThan(0.0));
      expect(dayAtmosphere.starlightIntensity, equals(0.0));
    });

    testWidgets('2. OrbitPhotorealScene applies explicit settings instead of system time', (tester) async {
      const palette = OrbitPalette.one;
      const dawnSettings = AppearanceSettings(atmosphereMode: AtmosphereMode.dawn);

      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            body: OrbitPhotorealScene(
              palette: palette,
              quality: ResolvedQuality.static,
              motionEnabled: false,
              settings: dawnSettings,
            ),
          ),
          atmosphereMode: AtmosphereMode.dawn,
        ),
      );

      await tester.pumpAndSettle();

      final sceneFinder = find.byType(OrbitPhotorealScene);
      expect(sceneFinder, findsOneWidget);
      final sceneWidget = tester.widget<OrbitPhotorealScene>(sceneFinder);
      expect(sceneWidget.settings?.atmosphereMode, AtmosphereMode.dawn);
    });
  });

  group('Mail Account Sheet Responsive Typography & Button Layout Tests', () {
    testWidgets('3. Mail account sheet header & action buttons do not crush title into vertical column', (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showOrbitMailAccountsSheet(
                  context,
                  palette: OrbitPalette.one,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check header row: Title 'Почтовые аккаунты' and Close button exist
      final titleFinder = find.text('Почтовые аккаунты');
      expect(titleFinder, findsOneWidget);

      final titleSize = tester.getSize(titleFinder);
      // Title must have healthy horizontal width (> 100 dp)
      expect(titleSize.width, greaterThan(100.0));

      // Toggle button exists below header
      final toggleBtnFinder = find.byKey(const Key('toggle-add-mail-account-btn'));
      expect(toggleBtnFinder, findsOneWidget);

      // Close button exists
      final closeBtnFinder = find.byKey(const Key('close-mail-accounts-sheet-btn'));
      expect(closeBtnFinder, findsOneWidget);

      // Now tap add account to open verification form
      await tester.tap(toggleBtnFinder);
      await tester.pumpAndSettle();

      // In form view, verify verification buttons exist in vertical column without clipping
      final verifyBtnFinder = find.byKey(const Key('verify-mail-connection-btn'));
      expect(verifyBtnFinder, findsOneWidget);

      final saveBtnFinder = find.byKey(const Key('save-mail-account-btn'));
      expect(saveBtnFinder, findsOneWidget);

      final verifySize = tester.getSize(verifyBtnFinder);
      final saveSize = tester.getSize(saveBtnFinder);

      // Buttons occupy full width of form (> 240 dp on 360dp screen)
      expect(verifySize.width, greaterThan(240.0));
      expect(saveSize.width, greaterThan(240.0));

      // Verify button is above save button (vertical layout)
      final verifyTopLeft = tester.getTopLeft(verifyBtnFinder);
      final saveTopLeft = tester.getTopLeft(saveBtnFinder);
      expect(saveTopLeft.dy, greaterThan(verifyTopLeft.dy));
    });
  });

  group('Messenger Navigation Entry Point Tests', () {
    testWidgets('4. Today screen features messenger tile in ecosystem block', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            body: TodayScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Find expand button 'Все модули' and expand secondary nodes
      final expandFinder = find.byIcon(Icons.keyboard_arrow_down_rounded);
      if (expandFinder.evaluate().isNotEmpty) {
        await tester.tap(expandFinder.first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Check that messenger ecosystem tile is mounted
      final messengerTileFinder = find.byKey(const ValueKey('orbit_eco_messenger'));
      expect(messengerTileFinder, findsOneWidget);
    });

    testWidgets('5. OrbitAppHubSheet includes Messenger service tile', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          const Scaffold(
            body: OrbitAppHubSheet(
              palette: OrbitPalette.one,
              profile: OrbitProfile.one,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Мессенджер'), findsOneWidget);
      expect(find.text('WSS & IMAP мост'), findsOneWidget);
    });
  });
}
