import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/services/brain/gemini_brain_engine.dart';
import 'package:orbit_visual_lab/services/brain/privacy_guardrails.dart';
import 'package:orbit_visual_lab/widgets/orbit_living_backdrop.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  group('PrivacyGuardrails Guide and Russian Lexicon Verification', () {
    test('1. Точный текст из KIMI_TEST_GUIDE.md маскирует пароль и карту', () {
      const guideText = 'пароль test123, карта 4276 1234 5678 9012';
      final sanitized = OrbitGeminiBrainEngine.sanitizeWithPrivacyGuardrails(guideText);

      expect(sanitized, isNot(contains('test123')));
      expect(sanitized, isNot(contains('4276 1234 5678 9012')));
      expect(sanitized, contains('[SECRET_REDACTED]'));
      expect(sanitized, contains('[CARD_REDACTED]'));
      expect(sanitized, 'пароль [SECRET_REDACTED], карта [CARD_REDACTED]');
    });

    test('2. Распознает русские формы пароль, секрет, код, токен, пин, ключ с любыми разделителями', () {
      final samples = <String, String>{
        'мой пароль superSecret': 'мой пароль [SECRET_REDACTED]',
        'пароль: 123456Pass': 'пароль: [SECRET_REDACTED]',
        'секрет AlphaSecretToken': 'секрет [SECRET_REDACTED]',
        'секрета: Token999': 'секрета: [SECRET_REDACTED]',
        'код 8821': 'код [SECRET_REDACTED]',
        'токен=xyz-token-value': 'токен=[SECRET_REDACTED]',
        'пин-код 7712': 'пин-код [SECRET_REDACTED]',
        'ключ MyDatabaseSecretKey': 'ключ [SECRET_REDACTED]',
      };

      for (final entry in samples.entries) {
        final out = OrbitGeminiBrainEngine.sanitizeWithPrivacyGuardrails(entry.key);
        expect(out, entry.value, reason: 'Failed for input: ${entry.key}');
      }
    });

    test('3. PrivacyGuardrails.sanitizeText также маскирует русские секреты и карты', () {
      const input = 'пароль test123, карта 4276 1234 5678 9012';
      final sanitized = PrivacyGuardrails.sanitizeText(input);

      expect(sanitized, isNot(contains('test123')));
      expect(sanitized, isNot(contains('4276 1234 5678 9012')));
      expect(sanitized, contains('[SECRET_REDACTED]'));
      expect(sanitized, contains('•••• •••• •••• 9012'));
    });
  });

  group('Procedural Wallpaper Persistence & File Recovery', () {
    test('восстанавливает изображение по proceduralTheme, если файл на диске удален ОС', () {
      final controller = OrbitLivingWallpaperController();
      controller.setProceduralTheme('Космический рассвет');

      final nonExistentPath = '${Directory.systemTemp.path}/deleted_by_os_${DateTime.now().millisecondsSinceEpoch}.png';
      final stateJson = {
        'livingActive': true,
        'customFilePath': nonExistentPath,
        'proceduralTheme': 'Космический рассвет',
        'effect': 'auroraRays',
        'motionIntensity': 1.0,
      };

      // Применяем сохраненный json, в котором файл на диске отсутствует
      controller.applyJson(stateJson);

      expect(controller.proceduralTheme, 'Космический рассвет');
      expect(controller.hasCustomWallpaper, isTrue);
      expect(controller.activeImageProvider, isNotNull);
      // Провайдер возвращает FileImage (восстановленный на диске файл темы) или MemoryImage
      final provider = controller.activeImageProvider;
      expect(provider is FileImage || provider is MemoryImage, isTrue);

      // Проверяем, что файл на диске был физически восстановлен с валидными байтами темы (>100 байт)
      final persistentFile = OrbitLivingWallpaperController.getPersistentWallpaperFile('Космический рассвет');
      expect(persistentFile.existsSync(), isTrue);
      expect(persistentFile.lengthSync(), greaterThan(100));
    });

    test('генерирует уникальные градиентные байты для Северное сияние и Неоновый каньон', () {
      final auroraBytes = OrbitLivingWallpaperController.getProceduralThemeFallbackBytes('Северное сияние');
      final neonBytes = OrbitLivingWallpaperController.getProceduralThemeFallbackBytes('Неоновый каньон');

      expect(auroraBytes.length, greaterThan(100));
      expect(neonBytes.length, greaterThan(100));
      expect(auroraBytes, isNot(equals(neonBytes)));
    });
  });
}
