import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_app_hub_sheet.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_living_backdrop.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'orbit_test_harness.dart';

void _testWithClock(String description, WidgetTesterCallback callback) {
  testWidgets(
    description,
    (tester) => withClock(
      Clock.fixed(DateTime(2026, 11, 13, 11, 0)),
      () => callback(tester),
    ),
  );
}

Future<void> _loadFont(String family, List<String> assets) async {
  final loader = FontLoader(family);
  for (final asset in assets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

Future<void> _pumpLargeTextApp(WidgetTester tester) async {
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpOrbitApp(
    tester,
    settings: const AppearanceSettings(
      quality: OrbitQuality.eco,
      motionEnabled: false,
      renderer: TodayRenderer.rive,
    ),
    settle: false,
  );
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  await tester.pump(const Duration(milliseconds: 1500));
}

Future<void> _pumpLargeTextHub(WidgetTester tester) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  final style = OrbitStyleManager(MemoryAppearanceRepository());
  await style.load();
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitEnvironment(
      style: style,
      quality: quality,
      appState: OrbitAppState(),
      appearanceSettings: style.settings,
      resolvedQuality: ResolvedQuality.static,
      dataRevision: 0,
      graphicsFallbackReason: null,
      child: MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: OrbitPalette.one.themeData(OrbitPalette.one.accent),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const Scaffold(
          body: OrbitAppHubSheet(
            palette: OrbitPalette.one,
            profile: OrbitProfile.one,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previousComparator = goldenFileComparator;
  goldenFileComparator = _TolerantGoldenFileComparator(
    Uri.parse('test/ui_regression_0527_test.dart'),
    precisionTolerance: 0.30,
  );
  tearDownAll(() => goldenFileComparator = previousComparator);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orbitWallpaperController.reset();
    OrbitMotionService.instance.reset();
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

  await _loadFont('OrbitSans', [
    'assets/fonts/OrbitSans-Regular.ttf',
    'assets/fonts/OrbitSans-Medium.ttf',
    'assets/fonts/OrbitSans-SemiBold.ttf',
  ]);
  await _loadFont('OrbitSerif', [
    'assets/fonts/OrbitSerif-Regular.ttf',
    'assets/fonts/OrbitSerif-Medium.ttf',
  ]);
  const materialIconsRelativePath =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  var flutterRoot = File(Platform.resolvedExecutable).parent;
  while (flutterRoot.path != '/' &&
      !File('${flutterRoot.path}/$materialIconsRelativePath').existsSync()) {
    flutterRoot = flutterRoot.parent;
  }
  final materialIcons = File('${flutterRoot.path}/$materialIconsRelativePath');
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(
      materialIcons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  await iconLoader.load();

  _testWithClock(
    'Today keeps metrics and events readable at 320 dp 200 percent',
    (tester) async {
      await _pumpLargeTextApp(tester);
      await expectLater(
        find.byKey(const Key('orbit-shell')),
        matchesGoldenFile('goldens/large_today_320.png'),
      );

      final eventsLabel = find.text('события');
      await tester.ensureVisible(eventsLabel);
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byKey(const Key('orbit-shell')),
        matchesGoldenFile('goldens/large_today_metrics_320.png'),
      );
      expect(
        tester.getSize(eventsLabel).width,
        greaterThan(70),
        reason: 'events metric must not be squeezed into an ellipsis',
      );
      final eventTitle = find.text('Совещание по ВП');
      await tester.ensureVisible(eventTitle);
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byKey(const Key('orbit-shell')),
        matchesGoldenFile('goldens/large_today_events_320.png'),
      );
      expect(
        tester.getSize(eventTitle).width,
        greaterThan(200),
        reason: 'event title must use the available row width',
      );
      expect(tester.takeException(), isNull);
    },
  );

  _testWithClock('Hub keeps search and Brain readable at 320 dp 200 percent', (
    tester,
  ) async {
    await _pumpLargeTextHub(tester);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/large_hub_320.png'),
    );

    expect(find.text('Сквозной поиск'), findsOneWidget);
    final brain = tester.widget<Text>(find.text('ORBIT Brain'));
    expect((brain.style?.fontSize ?? 16) * 2.0, lessThanOrEqualTo(24.0));
    expect(tester.takeException(), isNull);
  });

  _testWithClock(
    'Settings tiles retain full titles and subtitles at 200 percent',
    (tester) async {
      await _pumpLargeTextApp(tester);
      await orbitGoToTab(tester, 4);
      await tester.ensureVisible(find.text('ORBIT Visual Lab'));
      await tester.pump(const Duration(milliseconds: 200));
      await expectLater(
        find.byKey(const Key('orbit-shell')),
        matchesGoldenFile('goldens/large_settings_320.png'),
      );

      final title = tester.widget<Text>(find.text('ORBIT Visual Lab'));
      final subtitle = tester.widget<Text>(
        find.textContaining('Static · Rive · Filament'),
      );
      expect(title.maxLines, greaterThanOrEqualTo(2));
      expect(subtitle.maxLines, greaterThanOrEqualTo(3));
      expect(tester.takeException(), isNull);
    },
  );
}

final class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    final passed = result.passed || result.diffPercent <= _precisionTolerance;
    if (passed) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
