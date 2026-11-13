import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/screens/messenger_screen.dart';
import 'package:orbit_visual_lab/services/messenger/orbit_hybrid_messenger_engine.dart';
import 'package:orbit_visual_lab/theme/orbit_palette.dart';
import 'package:orbit_visual_lab/theme/orbit_profile.dart';

import 'orbit_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Messenger composer stays near the bottom edge', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = OrbitHybridMessengerController(isMockMode: true);
    await tester.pumpWidget(
      MaterialApp(
        home: MessengerScreen(
          palette: OrbitPalette.fromProfile(OrbitProfile.one, isLight: false),
          profile: OrbitProfile.one,
          controller: controller,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('chat-thread-tile-chat_core_team')));
    await tester.pumpAndSettle();

    final inputBottom = tester
        .getBottomLeft(find.byKey(const Key('chat-message-input')))
        .dy;
    expect(844 - inputBottom, lessThanOrEqualTo(24));
    expect(inputBottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Messenger action-center label stays on one line', (
    tester,
  ) async {
    await pumpOrbitApp(tester, settle: false);
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    await tester.pump(const Duration(milliseconds: 200));

    final expand = find.byIcon(Icons.keyboard_arrow_down_rounded);
    if (expand.evaluate().isNotEmpty) {
      await tester.tap(expand.first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.ensureVisible(find.byKey(const Key('orbit_eco_messenger')));

    final label = tester.widget<Text>(find.text('Мессенджер'));
    expect(label.maxLines, 1);
    expect(tester.getSize(find.text('Мессенджер')).height, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Mail and calendar FABs are 24 dp lower', (tester) async {
    await pumpOrbitApp(tester);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    await tester.pump();

    await orbitGoToTab(tester, 1);
    final composeFinder = find.byKey(const Key('compose-fab'));
    final composeBottom = tester.getBottomLeft(composeFinder).dy;
    final composeSafeArea = MediaQuery.paddingOf(
      tester.element(composeFinder),
    ).bottom;
    expect(844 - composeBottom, closeTo(72 + composeSafeArea, 0.01));

    await orbitGoToTab(tester, 2);
    final eventFinder = find.byKey(const Key('add-event-fab'));
    final eventBottom = tester.getBottomLeft(eventFinder).dy;
    final eventSafeArea = MediaQuery.paddingOf(
      tester.element(eventFinder),
    ).bottom;
    expect(844 - eventBottom, closeTo(72 + eventSafeArea, 0.01));
    expect(tester.takeException(), isNull);
  });
}
