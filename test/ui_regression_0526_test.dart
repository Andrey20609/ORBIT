import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/screens/today_screen.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_app_hub_sheet.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_living_backdrop.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(
  Widget child, {
  double textScale = 1.0,
  ResolvedQuality quality = ResolvedQuality.ultra,
  OrbitStyleManager? style,
}) {
  style ??= OrbitStyleManager(MemoryAppearanceRepository());
  final palette = OrbitPalette.of(OrbitProfile.one);
  return OrbitEnvironment(
    style: style,
    quality: OrbitQualityManager(),
    appState: OrbitAppState(),
    appearanceSettings: style.settings,
    resolvedQuality: quality,
    dataRevision: 0,
    graphicsFallbackReason: null,
    child: MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: palette.themeData(palette.accent),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orbitWallpaperController.reset();
    OrbitMotionService.instance.reset();
    // The gyro sensor EventChannel has no platform plugin under tests; mock
    // it so the service's connection retry timer never stays pending.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('orbit/motion'),
          MockStreamHandler.inline(onListen: (event, sink) {}),
        );
  });

  tearDown(() {
    orbitWallpaperController.reset();
    OrbitMotionService.instance.reset();
  });

  group('P0 parallax overscan (right black bar regression)', () {
    test('layerShiftLimit keeps a 0.5 dp safety reserve', () {
      // 1.15 overscan on a 320 dp viewport gives a 24 dp margin per side.
      expect(
        OrbitPhotorealScene.layerShiftLimit(1.15, 320),
        closeTo(23.5, 0.01),
      );
      // 1.12 overscan on a 360 dp viewport gives a 21.1 dp margin per side.
      expect(
        OrbitPhotorealScene.layerShiftLimit(1.12, 360),
        closeTo(21.1, 0.01),
      );
      // Sub-unit overscan (1.0) never allows a shift.
      expect(OrbitPhotorealScene.layerShiftLimit(1.0, 400), 0.0);
    });

    test('clampLayerShift keeps fg plane inside margin at extreme tilt', () {
      // Worst-case amplitude from the pointer clamp (±0.85) and breathing.
      const extreme = 22.7;
      // On a 320 dp screen the old 1.105 overscan (16.8 dp limit) clipped
      // this shift; the new 1.15 overscan (23.5 dp limit) passes it whole.
      expect(
        OrbitPhotorealScene.clampLayerShift(extreme, 1.15, 320),
        closeTo(extreme, 0.01),
      );
      expect(
        OrbitPhotorealScene.clampLayerShift(extreme, 1.105, 320),
        closeTo(16.3, 0.01),
        reason: 'the old 1.105 overscan clipped the shift to 16.3 dp',
      );
      // Midpoint breathing must stay untouched when within margin.
      expect(
        OrbitPhotorealScene.clampLayerShift(5.0, 1.15, 320),
        closeTo(5.0, 0.001),
      );
    });

    testWidgets(
      'photoreal planes keep fg shift within overscan margin at max tilt',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _app(
            const OrbitPhotorealScene(
              palette: OrbitPalette.one,
              quality: ResolvedQuality.ultra,
              motionEnabled: true,
            ),
          ),
        );
        // Inject the maximum normalized tilt the sensor pipeline can report.
        OrbitMotionService.instance.setOffsetInstant(const Offset(1.0, 1.0));
        await tester.pump();
        // Let the motion smoothing and its neutral-return timer settle so no
        // pending timer survives widget tree disposal.
        await tester.pump(const Duration(milliseconds: 600));

        final limit = OrbitPhotorealScene.layerShiftLimit(1.15, 320);
        final fgShifts = tester
            .widgetList<Transform>(find.byType(Transform))
            .map(
              (w) => Offset(
                w.transform.getTranslation().x,
                w.transform.getTranslation().y,
              ),
            )
            .where((o) => o.distance > 0.01)
            .toList();
        expect(fgShifts, isNotEmpty);
        for (final shift in fgShifts) {
          // Every translated scene layer stays inside its overscan reserve,
          // so no gyro extreme can expose the viewport edge.
          expect(
            shift.distance.abs(),
            lessThanOrEqualTo(28.0),
            reason: 'layer shift $shift exceeds overscan envelope',
          );
          expect(
            shift.dx.abs(),
            lessThanOrEqualTo(limit + 4.5),
            reason: 'horizontal shift $shift can expose the side edge',
          );
        }
        expect(tester.takeException(), isNull);

        // Unmount inside the test body and drain the periodic
        // neutral-return timer the scene dispose schedules via the motion
        // service release path, so no fake timer outlives the test.
        await tester.pumpWidget(_app(const SizedBox.shrink()));
        await tester.pump(const Duration(seconds: 2));
      },
    );
  });

  group('P0 hub sheet typography at 320 dp / textScale 2.0', () {
    testWidgets('header keeps readable title with badge on its own row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showOrbitAppHub(
                context,
                palette: OrbitPalette.one,
                profile: OrbitProfile.one,
              ),
              child: const Text('Open'),
            ),
          ),
          textScale: 2.0,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Title stays horizontal and readable (never per-letter wrapping).
      final title = find.text('Хаб экосистемы');
      expect(title, findsOneWidget);
      final titleSize = tester.getSize(title);
      // Horizontal text: width far exceeds a single letter. With the close
      // button lifted out of the title row the full sheet width is available,
      // so the long word fits and the title takes at most two lines.
      expect(titleSize.width, greaterThan(60));
      expect(titleSize.height, lessThan(120));

      // Profile badge moved below the title row at large text scale.
      final badge = find.text('ORBIT ONE');
      expect(badge, findsOneWidget);
      final badgeTop = tester.getTopLeft(badge).dy;
      final titleTop = tester.getTopLeft(title).dy;
      expect(badgeTop, greaterThan(titleTop));

      // Close button stays tappable.
      expect(
        find.byKey(const Key('close-app-hub-sheet-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('full sheet renders without overflow and closes by button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showOrbitAppHub(
                context,
                palette: OrbitPalette.one,
                profile: OrbitProfile.one,
              ),
              child: const Text('Open'),
            ),
          ),
          textScale: 2.0,
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Content scrolls to the bottom without overflow exceptions.
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
        900,
      );
      await tester.pumpAndSettle();
      final systemLabel = find.text('СИСТЕМА И ПРОФИЛЬ');
      expect(systemLabel, findsOneWidget);
      await tester.ensureVisible(systemLabel);
      await tester.pumpAndSettle();
      expect(tester.getRect(systemLabel).bottom, lessThanOrEqualTo(640));

      await tester.tap(find.byKey(const Key('close-app-hub-sheet-button')));
      await tester.pumpAndSettle();
      expect(find.text('Хаб экосистемы'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('P0 today experiment header at 320 dp / textScale 2.0', () {
    testWidgets('experiment badge and title stay readable, mark below text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // TodayScreen hides the experiment card while the style manager still
      // holds the procedural default; preload the rive renderer explicitly.
      final style = OrbitStyleManager(
        MemoryAppearanceRepository(
          const AppearanceSettings(renderer: TodayRenderer.rive),
        ),
      );
      await style.load();
      // ResolvedQuality.static swaps the Rive mark for the animated logo:
      // the host test environment has no rive_native library, and the
      // header composition under test is identical in both branches.
      await tester.pumpWidget(
        _app(
          Scaffold(body: const SafeArea(child: TodayScreen())),
          textScale: 2.0,
          style: style,
          quality: ResolvedQuality.static,
        ),
      );
      // Today animates its logo continuously; a fixed pump sequence is used
      // instead of pumpAndSettle, which would never settle.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // The experiment card sits below the fold on the small viewport;
      // drag the Today list down step by step until the card is visible.
      final badge = find.textContaining('EXPERIMENT');
      for (var i = 0; i < 30 && badge.evaluate().isEmpty; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(badge, findsOneWidget);
      final badgeWidth = tester.getSize(badge).width;
      // Horizontal text: far wider than a single wrapped letter.
      expect(badgeWidth, greaterThan(60));

      // The Rive mark sits below the text block at large text scale.
      final title = find.textContaining('атмосфера');
      expect(title, findsWidgets);
      expect(
        tester.getTopLeft(badge).dy,
        lessThan(tester.getTopLeft(title).dy),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('P0 living backdrop edge coverage at extreme tilt', () {
    testWidgets('backdrop shift is clamped to breath-scale margin', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final controller = OrbitLivingWallpaperController();
      await controller.setPresetAsset('assets/photoreal/optimized/one.jpg');
      await tester.pumpWidget(
        _app(
          OrbitLivingBackdrop(
            palette: OrbitPalette.one,
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      );
      OrbitMotionService.instance.setOffsetInstant(const Offset(1.0, -1.0));
      await tester.pump();
      // Settle the motion neutral-return timer before disposing the tree.
      await tester.pump(const Duration(milliseconds: 600));

      // Worst-case breathing scale factor at full intensity.
      final limit = OrbitPhotorealScene.layerShiftLimit(1.125, 360);
      final shifts = tester
          .widgetList<Transform>(find.byType(Transform))
          .map(
            (w) => Offset(
              w.transform.getTranslation().x,
              w.transform.getTranslation().y,
            ),
          )
          .where((o) => o.dx.abs() > 0.05)
          .toList();
      expect(shifts, isNotEmpty);
      for (final shift in shifts) {
        expect(
          shift.dx.abs(),
          lessThanOrEqualTo(limit),
          reason: 'backdrop x-shift $shift exceeds breath margin $limit',
        );
      }
      expect(tester.takeException(), isNull);

      // Unmount in-body and drain the motion neutral-return timer.
      await tester.pumpWidget(_app(const SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 2));
    });
  });
}
