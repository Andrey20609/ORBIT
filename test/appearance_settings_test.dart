import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppearanceSettings', () {
    test('round-trips every persisted field', () {
      const original = AppearanceSettings(
        profile: OrbitProfile.atelier,
        quality: OrbitQuality.ultra,
        themeMode: ThemeMode.dark,
        accentColor: Color(0xFF77D9C2),
        languageCode: 'ru',
        density: OrbitDensity.compact,
        motionEnabled: false,
        renderer: TodayRenderer.filament,
        textScale: 1.3,
      );

      final restored = AppearanceSettings.fromJson(original.toJson());

      expect(restored.profile, original.profile);
      expect(restored.quality, original.quality);
      expect(restored.themeMode, original.themeMode);
      expect(restored.accentColor, original.accentColor);
      expect(restored.languageCode, original.languageCode);
      expect(restored.density, original.density);
      expect(restored.motionEnabled, original.motionEnabled);
      expect(restored.renderer, original.renderer);
      expect(restored.textScale, original.textScale);
      expect(
        restored.toJson()['schemaVersion'],
        AppearanceSettings.schemaVersion,
      );
    });

    test('corrupt and unknown values use safe defaults', () {
      final restored = AppearanceSettings.fromJson({
        'profile': 'removed-future-profile',
        'quality': 42,
        'accentColor': 'invalid',
        'languageCode': 'unsupported-locale',
        'motionEnabled': 'yes',
      });
      expect(restored.profile, OrbitProfile.one);
      expect(restored.quality, OrbitQuality.auto);
      expect(restored.accentColor, const Color(0xFF9B8CFF));
      expect(restored.languageCode, 'ru');
      expect(restored.motionEnabled, isTrue);
    });
  });

  group('OrbitStyleManager', () {
    test('restores settings through a new repository-backed manager', () async {
      final repository = MemoryAppearanceRepository();
      final first = OrbitStyleManager(repository);
      await first.load();
      await first.setProfile(OrbitProfile.zen);
      await first.setQuality(OrbitQuality.eco);
      await first.setAccentColor(const Color(0xFFFFB68C));
      await first.setDensity(OrbitDensity.compact);
      await first.setMotionEnabled(false);
      await first.setRenderer(TodayRenderer.rive);

      final second = OrbitStyleManager(repository);
      await second.load();

      expect(second.settings.profile, OrbitProfile.zen);
      expect(second.settings.quality, OrbitQuality.eco);
      expect(second.settings.accentColor, const Color(0xFFFFB68C));
      expect(second.settings.density, OrbitDensity.compact);
      expect(second.settings.motionEnabled, isFalse);
      expect(second.settings.renderer, TodayRenderer.rive);
      expect(repository.saveCount, 6);
    });

    test('serializes delayed writes so the newest settings win', () async {
      final repository = DelayedAppearanceRepository();
      final manager = OrbitStyleManager(repository);
      await manager.load();

      final first = manager.setProfile(OrbitProfile.atelier);
      final second = manager.setProfile(OrbitProfile.zen);
      final third = manager.setRenderer(TodayRenderer.filament);
      repository.releaseFirst();
      await Future.wait([first, second, third]);

      expect(repository.completedOrder, [
        OrbitProfile.atelier,
        OrbitProfile.zen,
        OrbitProfile.zen,
      ]);
      expect(repository.value.profile, OrbitProfile.zen);
      expect(repository.value.renderer, TodayRenderer.filament);
      expect(manager.settings.profile, OrbitProfile.zen);
      expect(manager.settings.renderer, TodayRenderer.filament);
    });

    test(
      'keeps the newest optimistic state when an older write fails',
      () async {
        final repository = DelayedAppearanceRepository()..failFirst = true;
        final manager = OrbitStyleManager(repository);
        await manager.load();

        final first = manager.setProfile(OrbitProfile.atelier);
        final second = manager.setProfile(OrbitProfile.flow);
        repository.releaseFirst();
        await Future.wait([first, second]);

        expect(manager.settings.profile, OrbitProfile.flow);
        expect(repository.value.profile, OrbitProfile.flow);
        expect(manager.lastPersistenceError, isNull);
      },
    );

    test('rolls back optimistic state when persistence fails', () async {
      final repository = MemoryAppearanceRepository();
      final manager = OrbitStyleManager(repository);
      await manager.load();
      repository.failNextSave = true;

      await manager.setProfile(OrbitProfile.flow);

      expect(manager.settings.profile, OrbitProfile.one);
      expect(manager.lastPersistenceError, isA<StateError>());
      expect(repository.value.profile, OrbitProfile.one);
    });
  });

  group('OrbitQualityManager', () {
    test('honours explicit modes and system constraints', () {
      final manager = OrbitQualityManager();
      expect(
        manager.resolve(const AppearanceSettings()),
        ResolvedQuality.balanced,
      );
      expect(
        manager.resolve(const AppearanceSettings(quality: OrbitQuality.eco)),
        ResolvedQuality.static,
      );
      expect(
        manager.resolve(
          const AppearanceSettings(quality: OrbitQuality.balanced),
        ),
        ResolvedQuality.balanced,
      );
      expect(
        manager.resolve(const AppearanceSettings(quality: OrbitQuality.ultra)),
        ResolvedQuality.ultra,
      );
      manager.setReduceMotion(true);
      expect(
        manager.resolve(const AppearanceSettings(quality: OrbitQuality.ultra)),
        ResolvedQuality.static,
      );
      manager.setReduceMotion(false);
      expect(
        manager.resolve(
          const AppearanceSettings(
            quality: OrbitQuality.balanced,
            motionEnabled: false,
          ),
        ),
        ResolvedQuality.static,
      );
      manager.setAppLifecycle(resumed: false);
      expect(
        manager.resolve(const AppearanceSettings(quality: OrbitQuality.ultra)),
        ResolvedQuality.static,
      );
      manager.dispose();
    });
  });
}

final class DelayedAppearanceRepository implements OrbitAppearanceRepository {
  AppearanceSettings value = const AppearanceSettings();
  final completedOrder = <OrbitProfile>[];
  final _firstWrite = Completer<void>();
  bool failFirst = false;
  int _saveCalls = 0;

  void releaseFirst() => _firstWrite.complete();

  @override
  Future<AppearanceSettings> load() async => value;

  @override
  Future<void> save(AppearanceSettings settings) async {
    final call = ++_saveCalls;
    if (call == 1) await _firstWrite.future;
    // A newer call must never be able to overtake this delayed suspension.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    if (call == 1 && failFirst) throw StateError('Delayed write failed');
    value = settings;
    completedOrder.add(settings.profile);
  }
}
