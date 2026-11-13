import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_navigation.dart';

import 'orbit_test_harness.dart';

Future<OrbitAppState> _pumpApp(WidgetTester tester) async {
  final appState = OrbitAppState(MemoryLocalStateRepository());
  await appState.load();
  final style = OrbitStyleManager(
    MemoryAppearanceRepository(
      const AppearanceSettings(quality: OrbitQuality.eco, motionEnabled: false),
    ),
  );
  await style.load();
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitVisualLabApp(style: style, quality: quality, appState: appState),
  );
  await tester.pumpAndSettle();
  return appState;
}

String _draftText(WidgetTester tester, Key key) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(key),
        matching: find.byType(TextField),
        matchRoot: true,
      ),
    )
    .controller!
    .text;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bottom dock is opaque above scrolling content', (tester) async {
    await _pumpApp(tester);
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(OrbitBottomNavigation),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color!.a, 1.0);
    expect(find.byType(OrbitBottomNavigation), findsOneWidget);
  });

  testWidgets('delete draft clears persisted state without autosave revival', (
    tester,
  ) async {
    final appState = await _pumpApp(tester);
    await orbitGoToTab(tester, 1);
    await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('draft-to')),
      'delete@example.demo',
    );
    await tester.enterText(
      find.byKey(const Key('draft-subject')),
      'Draft to delete',
    );
    await tester.enterText(
      find.byKey(const Key('draft-body')),
      'This draft must not return after deletion',
    );
    await tester.pump(const Duration(milliseconds: 600));

    await tester.tap(find.byKey(const Key('delete-draft-button')));
    await tester.pumpAndSettle();
    expect(find.text('Удалить черновик?'), findsOneWidget);
    await tester.tap(find.text('Удалить').last);
    await tester.pumpAndSettle();
    await appState.flush();

    expect(appState.draftTo, isEmpty);
    expect(appState.draftSubject, isEmpty);
    expect(appState.draftBody, isEmpty);
    expect(appState.lastSavedDraft.body, isEmpty);

    await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
    await tester.pumpAndSettle();
    expect(_draftText(tester, const Key('draft-to')), isEmpty);
    expect(_draftText(tester, const Key('draft-subject')), isEmpty);
    expect(_draftText(tester, const Key('draft-body')), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
