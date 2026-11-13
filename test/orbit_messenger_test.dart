import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/screens/messenger_screen.dart';
import 'package:orbit_visual_lab/services/messenger/orbit_hybrid_messenger_engine.dart';
import 'package:orbit_visual_lab/theme/orbit_palette.dart';
import 'package:orbit_visual_lab/theme/orbit_profile.dart';

void main() {
  group('ORBIT 0.5.21+27 Hybrid Messenger (WSS:443 + IMAP Bridge) & UX Tests', () {
    test('1. Гибридный транспорт переключается между WSS:443 и IMAP-Bridge (Яндекс/Mail.ru)', () async {
      final controller = OrbitHybridMessengerController(isMockMode: true);

      // По умолчанию активен гибридный режим
      expect(
        controller.transportMode,
        OrbitMessengerTransportMode.hybridAuto,
      );

      // Переключаем на чистый почтовый мост IMAP (Вариант 3 — без внешних серверов)
      controller.setTransportMode(OrbitMessengerTransportMode.imapDeltaBridge);
      controller.bindImapAccount('architect@yandex.ru');

      final sentMsg = await controller.sendTextMessage(
        chatId: 'chat_core_team',
        text: 'Проверка связи через IMAP-мост без VPN',
      );

      expect(
        sentMsg.deliveryStatus,
        OrbitMessageDeliveryStatus.sentViaImapBridge,
      );

      final headers = controller.buildImapBridgeMimeHeaders(
        thread: controller.visibleThreads.first,
        message: sentMsg,
      );
      expect(headers['From'], 'architect@yandex.ru');
      expect(headers['X-Orbit-Chat-Version'], '1.0');
    });

    test('2. Фильтрация по папкам Telegram (Личные, Рабочие, Каналы, Избранное)', () {
      final controller = OrbitHybridMessengerController(isMockMode: true);

      controller.selectFolder(OrbitChatFolder.saved);
      expect(controller.visibleThreads, hasLength(1));
      expect(controller.visibleThreads.first.id, 'chat_saved');

      controller.selectFolder(OrbitChatFolder.work);
      expect(controller.visibleThreads.first.id, 'chat_core_team');
    });

    testWidgets('3. Открытие чата, отправка сообщения и конвертация в Задачу в 1 тап', (tester) async {
      final controller = OrbitHybridMessengerController(isMockMode: true);
      String? convertedType;

      await tester.pumpWidget(
        MaterialApp(
          home: MessengerScreen(
            palette: OrbitPalette.fromProfile(OrbitProfile.one, isLight: false),
            profile: OrbitProfile.one,
            controller: controller,
            onConvertMessageToEntity: (msg, type) {
              convertedType = type;
            },
          ),
        ),
      );

      // Открываем рабочий чат команды
      await tester.tap(find.byKey(const Key('chat-thread-tile-chat_core_team')));
      await tester.pumpAndSettle();

      // Конвертируем первое сообщение в задачу в 1 тап
      await tester.tap(find.byKey(const Key('msg-to-task-m_core_1')));
      await tester.pumpAndSettle();

      expect(convertedType, 'task');
      expect(find.text('✓ Задача'), findsOneWidget);

      // Дожидаемся авто-закрытия плавающего острова (3 секунды)
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    testWidgets('4. Конвертация сообщения чата во Встречу календаря в 1 тап', (tester) async {
      final controller = OrbitHybridMessengerController(isMockMode: true);
      String? convertedType;

      await tester.pumpWidget(
        MaterialApp(
          home: MessengerScreen(
            palette: OrbitPalette.fromProfile(OrbitProfile.one, isLight: false),
            profile: OrbitProfile.one,
            controller: controller,
            onConvertMessageToEntity: (msg, type) {
              convertedType = type;
            },
          ),
        ),
      );

      // Открываем рабочий чат команды
      await tester.tap(find.byKey(const Key('chat-thread-tile-chat_core_team')));
      await tester.pumpAndSettle();

      // Конвертируем первое сообщение во встречу в 1 тап
      await tester.tap(find.byKey(const Key('msg-to-meeting-m_core_1')));
      await tester.pumpAndSettle();

      expect(convertedType, 'meeting');
      expect(find.text('✓ Встреча'), findsOneWidget);

      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });

    test('5. Сетевой probe и переключение статуса онлайн/офлайн для WSS-туннеля', () async {
      final controller = OrbitHybridMessengerController(isMockMode: true);
      expect(controller.isWssTunnelOnline, isTrue);
      expect(controller.activeTransportBadge, contains('Демо-прототип'));

      await controller.probeTransportConnectivity();
      expect(controller.isWssTunnelOnline, isTrue);
      expect(controller.lastBridgeLatencyMs, 22);

      controller.setWssTunnelOnlineForTest(false);
      expect(controller.isWssTunnelOnline, isFalse);
      expect(controller.activeTransportBadge, contains('Офлайн'));
    });
  });
}