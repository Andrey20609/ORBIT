import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/orbit_corrupt_data.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'corrupt local JSON is backed up and cannot be overwritten by defaults',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocalStateRepository.storageKey: '{broken',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesLocalStateRepository(
        preferences: preferences,
      );
      final state = OrbitAppState(repository);
      await state.load();

      expect(state.lastLoadError, isA<OrbitCorruptDataException>());
      expect(
        preferences.getString(SharedPreferencesLocalStateRepository.backupKey),
        '{broken',
      );
      state.addTask('Must not replace corrupt payload');
      expect(
        preferences.getString(SharedPreferencesLocalStateRepository.storageKey),
        '{broken',
      );

      await state.resetCorruptData();
      expect(state.lastLoadError, isNull);
      expect(
        preferences.getString(SharedPreferencesLocalStateRepository.storageKey),
        isNull,
      );
      expect(
        preferences.getString(SharedPreferencesLocalStateRepository.backupKey),
        '{broken',
      );
    },
  );

  test(
    'corrupt appearance is backed up and changes stay blocked until reset',
    () async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesAppearanceRepository.storageKey: '[]',
      });
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAppearanceRepository(
        preferences: preferences,
      );
      final style = OrbitStyleManager(repository);
      await style.load();

      expect(style.lastLoadError, isA<OrbitCorruptDataException>());
      expect(
        preferences.getString(SharedPreferencesAppearanceRepository.backupKey),
        '[]',
      );
      await style.setProfile(OrbitProfile.zen);
      expect(style.settings.profile, OrbitProfile.zen);
      expect(
        preferences.getString(SharedPreferencesAppearanceRepository.storageKey),
        '[]',
      );

      await style.resetCorruptData();
      expect(style.lastLoadError, isNull);
      expect(
        preferences.getString(SharedPreferencesAppearanceRepository.storageKey),
        isNull,
      );
      expect(
        preferences.getString(SharedPreferencesAppearanceRepository.backupKey),
        '[]',
      );
    },
  );

  testWidgets(
    'corrupt local data requires explicit confirmation before reset',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocalStateRepository.storageKey: '{broken',
      });
      final preferences = await SharedPreferences.getInstance();
      final appState = OrbitAppState(
        SharedPreferencesLocalStateRepository(preferences: preferences),
      );
      await appState.load();
      final style = OrbitStyleManager(
        MemoryAppearanceRepository(
          const AppearanceSettings(
            quality: OrbitQuality.eco,
            motionEnabled: false,
          ),
        ),
      );
      await style.load();
      final quality = OrbitQualityManager();
      addTearDown(quality.dispose);
      await tester.pumpWidget(
        OrbitVisualLabApp(style: style, quality: quality, appState: appState),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('corrupt-reset')), findsOneWidget);
      await tester.tap(find.byKey(const Key('corrupt-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('corrupt-reset-confirm')));
      await tester.pumpAndSettle();

      expect(appState.lastLoadError, isNull);
      expect(find.byKey(const Key('corrupt-reset')), findsNothing);
      expect(
        preferences.getString(SharedPreferencesLocalStateRepository.backupKey),
        '{broken',
      );
    },
  );

  test('corrupt backup export preserves raw payload', () async {
    const channel = MethodChannel('orbit/qa');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    SharedPreferences.setMockInitialValues({
      SharedPreferencesLocalStateRepository.storageKey: '{broken',
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = SharedPreferencesLocalStateRepository(
      preferences: preferences,
    );
    await expectLater(
      repository.load(),
      throwsA(isA<OrbitCorruptDataException>()),
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'exportText');
      return '/documents/ORBIT_recovery/local-state.txt';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final path = await repository.exportCorruptBackup();
    expect(path, '/documents/ORBIT_recovery/local-state.txt');
    expect(
      preferences.getString(SharedPreferencesLocalStateRepository.backupKey),
      '{broken',
    );
  });
}
