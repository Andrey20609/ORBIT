import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

Future<(OrbitStyleManager, OrbitQualityManager)> _pumpApp(
  WidgetTester tester, {
  AppearanceSettings initial = const AppearanceSettings(
    quality: OrbitQuality.eco,
    motionEnabled: false,
  ),
}) async {
  final style = OrbitStyleManager(MemoryAppearanceRepository(initial));
  await style.load();
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitVisualLabApp(
      style: style,
      quality: quality,
      appState: OrbitAppState(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return (style, quality);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native power and memory signals constrain and restore quality',
    () async {
      final manager = OrbitQualityManager();
      addTearDown(manager.dispose);
      const settings = AppearanceSettings(quality: OrbitQuality.ultra);
      const channel = MethodChannel('orbit/system');
      const codec = StandardMethodCodec();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('powerSaveMode', true)),
        (_) {},
      );
      expect(manager.powerSaveMode, isTrue);
      expect(manager.resolve(settings), ResolvedQuality.static);

      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('powerSaveMode', false)),
        (_) {},
      );
      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('lowMemory')),
        (_) {},
      );
      expect(manager.lowMemory, isTrue);
      expect(manager.resolve(settings), ResolvedQuality.static);

      await messenger.handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(const MethodCall('memoryRecovered')),
        (_) {},
      );
      expect(manager.lowMemory, isFalse);
      expect(manager.resolve(settings), ResolvedQuality.ultra);
    },
  );

  testWidgets('Eco never creates a native 3D view', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await _pumpApp(
        tester,
        initial: const AppearanceSettings(
          quality: OrbitQuality.eco,
          motionEnabled: false,
          renderer: TodayRenderer.filament,
        ),
      );

      expect(find.byKey(const Key('filament-native-surface')), findsNothing);
      expect(find.byKey(const Key('today-greeting')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('unknown route uses the recoverable error screen', (
    tester,
  ) async {
    await _pumpApp(tester);
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('today-greeting'))),
    );
    router.go('/route-that-does-not-exist');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Маршрут не найден'), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    await tester.tap(find.text('Сегодня'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('today-greeting')), findsOneWidget);
  });

  testWidgets('secondary routes fit 320 px and work without network', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _OfflineOverrides();
    addTearDown(() => HttpOverrides.global = previousOverrides);
    await _pumpApp(tester);
    final router = GoRouter.of(
      tester.element(find.byKey(const Key('today-greeting'))),
    );

    for (final route in [
      '/mail/message/weekly-plan',
      '/mail/compose',
      '/settings/personalization',
      '/settings/personalization/interface',
      '/settings/lab',
      '/brain',
    ]) {
      router.go(route);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final exception = tester.takeException();
      expect(exception, isNull, reason: '$route: $exception');
      expect(find.byType(ErrorWidget), findsNothing, reason: route);
    }
  });
}

final class _OfflineOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    throw StateError('Network access is disabled in this test');
  }
}
