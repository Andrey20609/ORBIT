import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/screens/today_screen.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('five locales, profiles and large system text on Android', (
    tester,
  ) async {
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previousErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = previousErrorHandler);
    final style = OrbitStyleManager(SharedPreferencesAppearanceRepository());
    await style.load();
    await style.setQuality(OrbitQuality.eco);
    await style.setMotionEnabled(false);
    await style.setRenderer(TodayRenderer.procedural);
    const appTextScalePercent = int.fromEnvironment(
      'ORBIT_APP_TEXT_SCALE_PERCENT',
      defaultValue: 130,
    );
    const minimumScalePercent = int.fromEnvironment(
      'ORBIT_MINIMUM_SCALE_PERCENT',
      defaultValue: 180,
    );
    const appTextScale = appTextScalePercent / 100;
    const minimumScale = minimumScalePercent / 100;
    const matrixTag = String.fromEnvironment(
      'ORBIT_MATRIX_TAG',
      defaultValue: 'compact200',
    );
    await style.setTextScale(appTextScale);
    final quality = OrbitQualityManager();
    await tester.pumpWidget(
      OrbitVisualLabApp(
        style: style,
        quality: quality,
        appState: OrbitAppState(),
      ),
    );
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    const greetings = <String, String>{
      'ru': 'Доброе утро!',
      'en': 'Good morning!',
      'de': 'Guten Morgen!',
      'fr': 'Bonjour !',
      'es': '¡Buenos días!',
    };
    const sectionTitles = <String, List<String>>{
      'ru': ['Входящие', 'Календарь', 'Задачи', 'Настройки'],
      'en': ['Inbox', 'Calendar', 'Tasks', 'Settings'],
      'de': ['Posteingang', 'Kalender', 'Aufgaben', 'Einstellungen'],
      'fr': ['Boîte de réception', 'Calendrier', 'Tâches', 'Réglages'],
      'es': ['Bandeja de entrada', 'Calendario', 'Tareas', 'Ajustes'],
    };
    const composeTitles = <String, String>{
      'ru': 'Новое письмо',
      'en': 'New email',
      'de': 'Neue E-Mail',
      'fr': 'Nouvel e-mail',
      'es': 'Nuevo correo',
    };
    const interfaceTitles = <String, String>{
      'ru': 'Интерфейс',
      'en': 'Interface',
      'de': 'Oberfläche',
      'fr': 'Interface',
      'es': 'Interfaz',
    };
    for (final entry in greetings.entries) {
      await style.setLanguage(entry.key);
      for (final profile in OrbitProfile.values) {
        await style.setProfile(profile);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        final effectiveScale = MediaQuery.textScalerOf(
          tester.element(find.byType(TodayScreen)),
        ).scale(1);
        debugPrint(
          '[ORBIT matrix] $matrixTag ${entry.key}/${profile.name}: textScale=$effectiveScale',
        );
        expect(effectiveScale, greaterThan(minimumScale));
        await _capture(
          'android_${matrixTag}_${entry.key}_${profile.name}_today',
        );
        for (var index = 1; index <= 4; index++) {
          await tester.tap(find.byKey(Key('orbit-nav-$index')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(
              Key('page-title-${sectionTitles[entry.key]![index - 1]}'),
            ),
            findsOneWidget,
          );
          if (index == 1) {
            expect(find.byKey(const Key('email-weekly-plan')), findsOneWidget);
            if (entry.key == 'fr' || entry.key == 'es') {
              await _capture(
                'android_${matrixTag}_${entry.key}_${profile.name}_mail',
              );
            }
            if (minimumScalePercent >= 180) {
              await tester.ensureVisible(
                find.byKey(const Key('email-weekly-plan')),
              );
              tester.widget<InkWell>(
                find.byKey(const Key('email-weekly-plan')),
              ).onTap!();
              await tester.pumpAndSettle();
              expect(find.byKey(const Key('mail-detail-body')), findsOneWidget);
              await _capture(
                'android_${matrixTag}_${entry.key}_${profile.name}_detail',
              );
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(Key('orbit-button-${composeTitles[entry.key]}')),
              );
              await tester.pumpAndSettle();
              expect(find.byKey(const Key('draft-body')), findsOneWidget);
              await _capture(
                'android_${matrixTag}_${entry.key}_${profile.name}_compose',
              );
              await tester.binding.handlePopRoute();
              await tester.pumpAndSettle();
            }
          }
          if (index == 4 && minimumScalePercent >= 180) {
            final tile = find.byKey(
              Key('settings-${interfaceTitles[entry.key]}'),
            );
            await tester.ensureVisible(tile);
            tester.widget<ListTile>(tile).onTap!();
            await tester.pumpAndSettle();
            expect(find.byKey(const Key('profile-one')), findsOneWidget);
            await _capture(
              'android_${matrixTag}_${entry.key}_${profile.name}_interface',
            );
            await tester.binding.handlePopRoute();
            await tester.pumpAndSettle();
          }
          final exception = tester.takeException();
          expect(
            exception,
            isNull,
            reason: '$matrixTag ${entry.key}/${profile.name}, tab $index',
          );
        }
        await tester.tap(find.byKey(const Key('orbit-nav-0')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    }
  });
}

Future<void> _capture(String name) async {
  final binding = IntegrationTestWidgetsFlutterBinding.instance;
  final bytes = await binding.takeScreenshot(name);
  final file = File('${Directory.systemTemp.path}/$name.png');
  await file.writeAsBytes(bytes, flush: true);
  await const MethodChannel('orbit/qa').invokeMethod<void>('saveScreenshot', {
    'name': name,
    'bytes': await file.readAsBytes(),
  });
}
