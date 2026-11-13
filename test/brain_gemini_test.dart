import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/screens/brain_screen.dart';
import 'package:orbit_visual_lab/services/brain/gemini_brain_engine.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/theme/orbit_palette.dart';
import 'package:orbit_visual_lab/theme/orbit_profile.dart';

void main() {
  group('ORBIT Gemini Brain Engine & 1-Tap Action Proposals', () {
    const snapshot = BrainEcosystemSnapshot(
      openTasksCount: 4,
      urgentTaskTitles: <String>['Аудит безопасности 0.5.17'],
      upcomingMeetingsCount: 2,
      nextMeetingLabel: 'Синк архитектуры • 15:00',
      unreadMailCount: 5,
      activeMailAccountEmail: 'architect@yandex.ru',
      mailAccountStatus: OrbitMailAccountStatus.verified,
      lastMailLatencyMs: 29,
    );

    test('1. PrivacyGuardrails маскирует пароли, токены и номера банковских карт', () {
      const dirty =
          'Мой password: superSecret123 и карта 4276 1234 5678 9012, token=abc987xyz';
      final clean =
          OrbitGeminiBrainEngine.sanitizeWithPrivacyGuardrails(dirty);

      expect(clean, isNot(contains('superSecret123')));
      expect(clean, isNot(contains('4276 1234 5678 9012')));
      expect(clean, contains('[SECRET_REDACTED]'));
      expect(clean, contains('[CARD_REDACTED]'));
    });

    test('2. Инъекция живого контекста формирует корректные Action Proposals для задач, встреч и почты', () {
      final engine = OrbitGeminiBrainEngine(tokenDelay: Duration.zero);

      final mailEval = engine.evaluatePrompt('Проверь почту', snapshot);
      expect(mailEval.proposal?.tool, BrainToolType.verifyMailHealth);
      expect(mailEval.fullText, contains('architect@yandex.ru'));

      final meetEval =
          engine.evaluatePrompt('Есть ли срочные встречи?', snapshot);
      expect(meetEval.proposal?.tool, BrainToolType.scheduleMeeting);

      final summaryEval = engine.evaluatePrompt('Сводка дня', snapshot);
      expect(summaryEval.proposal?.tool, BrainToolType.createTask);
      expect(summaryEval.fullText, contains('Аудит безопасности 0.5.17'));
    });

    testWidgets('3. BrainScreen стримит ответ и выполняет карточку действия в 1 тап', (tester) async {
      BrainActionProposal? executedProposal;
      final fastEngine = OrbitGeminiBrainEngine(tokenDelay: Duration.zero);

      await tester.pumpWidget(
        MaterialApp(
          home: BrainScreen(
            palette: OrbitPalette.fromProfile(OrbitProfile.one, isLight: false),
            profile: OrbitProfile.one,
            snapshot: snapshot,
            engine: fastEngine,
            onExecuteProposal: (proposal) {
              executedProposal = proposal;
            },
          ),
        ),
      );

      // Нажимаем быстрый чип «Сводка дня»
      await tester.tap(find.byKey(const Key('brain-quick-chip-0')));
      await tester.pumpAndSettle();

      // Проверяем, что появилась карточка предложения действия
      expect(find.textContaining('Предложение действия:'), findsOneWidget);
      expect(find.text('Выполнить в 1 тап'), findsOneWidget);

      // Выполняем действие в 1 касание
      await tester.tap(find.text('Выполнить в 1 тап'));
      await tester.pumpAndSettle();

      expect(executedProposal, isNotNull);
      expect(executedProposal!.tool, BrainToolType.createTask);
      expect(find.text('Выполнено в экосистеме ORBIT'), findsOneWidget);
    });
  });
}
