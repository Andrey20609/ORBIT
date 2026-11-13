import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI-created data survives an Android process restart', (
    tester,
  ) async {
    final style = OrbitStyleManager(SharedPreferencesAppearanceRepository());
    final appState = OrbitAppState(SharedPreferencesLocalStateRepository());
    await style.load();
    await appState.load();
    final quality = OrbitQualityManager();
    await tester.pumpWidget(
      OrbitVisualLabApp(style: style, quality: quality, appState: appState),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('orbit-nav-3')));
    await tester.pumpAndSettle();
    expect(find.text('ORB05 persistence task'), findsOneWidget);

    await tester.tap(find.byKey(const Key('orbit-nav-2')));
    await tester.pumpAndSettle();
    expect(find.text('ORB05 persistence event'), findsOneWidget);

    await tester.tap(find.byKey(const Key('orbit-nav-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('orbit-button-Новое письмо')));
    await tester.pumpAndSettle();
    String value(Key key) => tester
        .widget<TextField>(
          find.descendant(
            of: find.byKey(key),
            matching: find.byType(TextField),
            matchRoot: true,
          ),
        )
        .controller!
        .text;
    expect(value(const Key('draft-to')), 'persistence@example.demo');
    expect(value(const Key('draft-subject')), 'ORB05 persistence draft');
    expect(value(const Key('draft-body')), 'Process death evidence');
    expect(tester.takeException(), isNull);
  });
}
