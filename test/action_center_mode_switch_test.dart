import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/glass_panel.dart';

void main() {
  testWidgets('Action center cards maintain uniform height and layout across all mode switches', (tester) async {
    tester.binding.platformDispatcher.implicitView!.physicalSize = const Size(1080, 2400);
    tester.binding.platformDispatcher.implicitView!.devicePixelRatio = 2.75;

    final appState = OrbitAppState();
    await appState.load();
    final style = OrbitStyleManager(MemoryAppearanceRepository(
      const AppearanceSettings(
        profile: OrbitProfile.one,
        atmosphereMode: AtmosphereMode.automatic,
        quality: OrbitQuality.eco,
        motionEnabled: false,
      ),
    ));
    await style.load();
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);

    await tester.pumpWidget(
      OrbitVisualLabApp(style: style, quality: quality, appState: appState),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    Future<void> inspectActionCenter() async {
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.text('Центр действий'), 200, scrollable: scrollable);
      await tester.pump();

      final quickStripFinder = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_QuickStrip');
      expect(quickStripFinder, findsOneWidget);

      final glassPanels = tester.widgetList<GlassPanel>(find.descendant(of: quickStripFinder, matching: find.byType(GlassPanel))).toList();
      expect(glassPanels.length, 4);

      final cardBoxes = tester.renderObjectList<RenderBox>(find.descendant(
        of: quickStripFinder,
        matching: find.byType(GlassPanel),
      )).toList();

      expect(cardBoxes.length, 4);
      final h0 = cardBoxes[0].size.height;
      for (int i = 1; i < 4; i++) {
        expect(cardBoxes[i].size.height, equals(h0), reason: 'Card $i height should match Card 0 ($h0)');
      }
    }

    await inspectActionCenter();

    // 1. Atmosphere switches
    for (final atmo in [AtmosphereMode.dawn, AtmosphereMode.day, AtmosphereMode.sunset, AtmosphereMode.night]) {
      await style.setAtmosphereMode(atmo);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await inspectActionCenter();
    }

    // 2. Profile switches
    for (final prof in [OrbitProfile.atelier, OrbitProfile.flow, OrbitProfile.zen, OrbitProfile.one]) {
      await style.setProfile(prof);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await inspectActionCenter();
    }

    // 3. Theme switches
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      await style.setThemeMode(theme);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await inspectActionCenter();
    }

    // 4. Quality switches
    for (final q in [OrbitQuality.balanced, OrbitQuality.ultra, OrbitQuality.eco]) {
      await style.setQuality(q);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await inspectActionCenter();
    }

    // 5. Renderer switches
    for (final r in [TodayRenderer.rive, TodayRenderer.filament, TodayRenderer.procedural]) {
      await style.setRenderer(r);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await inspectActionCenter();
    }
  });
}
