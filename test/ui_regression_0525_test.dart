import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/screens/brain_screen.dart';
import 'package:orbit_visual_lab/screens/quick_actions_screen.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_app_hub_sheet.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_living_backdrop.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) {
  final style = OrbitStyleManager(MemoryAppearanceRepository());
  final quality = OrbitQualityManager();
  final appState = OrbitAppState();
  final palette = OrbitPalette.of(OrbitProfile.one);
  return OrbitEnvironment(
    style: style,
    quality: quality,
    appState: appState,
    appearanceSettings: style.settings,
    resolvedQuality: ResolvedQuality.static,
    dataRevision: 0,
    graphicsFallbackReason: null,
    child: MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: palette.themeData(palette.accent),
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    orbitWallpaperController.reset();
  });

  tearDown(() {
    orbitWallpaperController.reset();
  });

  testWidgets(
    'files tile keeps readable horizontal title instead of vertical letters',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(
          const OrbitAppHubSheet(
            palette: OrbitPalette.one,
            profile: OrbitProfile.one,
          ),
        ),
      );

      final title = find.text('Файлы и Документы');
      expect(title, findsOneWidget);
      expect(tester.getSize(title).width, greaterThan(50));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('quick action labels allow two lines instead of truncation', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const QuickActionsScreen()));

    final title = tester.widget<Text>(find.text('Новое письмо'));
    final subtitle = tester.widget<Text>(find.text('Локальный черновик'));
    expect(title.maxLines, 2);
    expect(subtitle.maxLines, 2);
  });

  testWidgets('Brain does not expose raw markdown markers', (tester) async {
    await tester.pumpWidget(_app(const BrainScreen()));
    await tester.pumpAndSettle();

    final rawMarkers = tester
        .widgetList<Text>(find.byType(Text))
        .where((widget) => widget.data?.contains('**') ?? false)
        .toList();
    expect(rawMarkers, isEmpty);
    expect(
      find.textContaining('ORBIT Brain (Gemini 2.0 Prototype)'),
      findsOneWidget,
    );
  });

  testWidgets('wallpaper body scroll does not dismiss sheet accidentally', (
    tester,
  ) async {
    final controller = OrbitLivingWallpaperController();
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showOrbitWallpaperStudioSheet(
              context,
              palette: OrbitPalette.one,
              profile: OrbitProfile.one,
              controller: controller,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Живой 2.5D-фон экосистемы'), findsOneWidget);

    await tester.fling(
      find.text('АТМОСФЕРНЫЕ СЦЕНЫ ORBIT'),
      const Offset(0, 300),
      800,
    );
    await tester.pumpAndSettle();
    expect(find.text('Живой 2.5D-фон экосистемы'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-wallpaper-studio-button')));
    await tester.pumpAndSettle();
    expect(find.text('Живой 2.5D-фон экосистемы'), findsNothing);
  });

  testWidgets('static scene uses overscan to prevent exposed right edge', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const OrbitPhotorealScene(
          palette: OrbitPalette.one,
          quality: ResolvedQuality.static,
          motionEnabled: true,
        ),
      ),
    );

    final scales = tester
        .widgetList<Transform>(find.byType(Transform))
        .map((widget) => widget.transform[0])
        .toList();
    expect(scales.any((scale) => scale >= 1.12), isTrue);
  });
}
