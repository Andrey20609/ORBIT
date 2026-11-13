import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/orbit_bootstrap.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  testWidgets('branded shell precedes restored interactive Today', (
    tester,
  ) async {
    final repository = _DeferredAppearanceRepository();
    final style = OrbitStyleManager(repository);
    final quality = OrbitQualityManager();
    addTearDown(quality.dispose);
    await tester.pumpWidget(
      OrbitBootstrap(
        startup: Stopwatch()..start(),
        style: style,
        quality: quality,
        appState: OrbitAppState(MemoryLocalStateRepository()),
        initializeGraphics: false,
        initializeLocales: false,
      ),
    );

    expect(find.byKey(const Key('orbit-startup-shell')), findsOneWidget);
    expect(find.byKey(const Key('today-greeting')), findsNothing);
    repository.complete(
      const AppearanceSettings(
        profile: OrbitProfile.zen,
        quality: OrbitQuality.eco,
        motionEnabled: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbit-startup-shell')), findsNothing);
    expect(find.byKey(const Key('today-greeting')), findsOneWidget);
    expect(style.settings.profile, OrbitProfile.zen);
  });
}

final class _DeferredAppearanceRepository implements OrbitAppearanceRepository {
  final completer = Completer<AppearanceSettings>();

  void complete(AppearanceSettings value) => completer.complete(value);

  @override
  Future<AppearanceSettings> load() => completer.future;

  @override
  Future<void> save(AppearanceSettings settings) async {}
}
