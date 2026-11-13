import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../state/app_state.dart';
import 'brain_context_aggregator.dart';
import 'brain_tool_caller.dart';
import 'privacy_guardrails.dart';

/// Автор сообщения в диалоге с Brain.
enum BrainMessageSender {
  user,
  assistant,
  system,
}

/// Сообщение в ленте диалога ORBIT Brain с поддержкой Action Proposal.
@immutable
final class BrainChatMessage {
  const BrainChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.actionProposal,
    this.isStreaming = false,
  });

  final String id;
  final BrainMessageSender sender;
  final String text;
  final DateTime timestamp;
  final BrainActionProposal? actionProposal;
  final bool isStreaming;

  BrainChatMessage copyWith({
    String? id,
    BrainMessageSender? sender,
    String? text,
    DateTime? timestamp,
    BrainActionProposal? actionProposal,
    bool? isStreaming,
  }) {
    return BrainChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      actionProposal: actionProposal ?? this.actionProposal,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

/// Результат генерации ответа Brain Engine.
final class BrainGenerationResult {
  const BrainGenerationResult({
    required this.replyText,
    this.actionProposal,
  });

  final String replyText;
  final BrainActionProposal? actionProposal;
}

/// Центральный нейросетевой оркестратор ORBIT Brain («Гемини на максималках»).
final class BrainEngine {
  const BrainEngine();

  /// Генерация контекстно-зависимого ответа с учетом актуального состояния экосистемы.
  BrainGenerationResult generateResponse({
    required String query,
    required OrbitAppState appState,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    final context = BrainContextAggregator.buildFromAppState(appState);

    final pendingCount = context['pendingTasksCount'] as int? ?? 0;
    final urgentCount = context['urgentTasksCount'] as int? ?? 0;
    final unreadEmails = context['unreadEmailsCount'] as int? ?? 0;
    final nextMeeting = context['nextMeeting'] as String? ?? 'Свободно';
    final activeAccount = context['activeMailAccount'] as Map<String, Object?>?;
    final accountEmail = activeAccount?['email'] as String? ?? 'демо-ящик';
    final isMailVerified = activeAccount?['isVerified'] as bool? ?? false;
    final latency = activeAccount?['latencyMs'] as int? ?? 28;

    // 1. Запрос на план дня / сводку
    if (cleanQuery.contains('план') ||
        cleanQuery.contains('день') ||
        cleanQuery.contains('сводка') ||
        cleanQuery.contains('приоритет')) {
      final text =
          'Сводка контекста на основе экосистемы ORBIT:\n'
          '• Задачи в работе: $pendingCount (из них горящих: $urgentCount).\n'
          '• Непрочитанные письма: $unreadEmails (аккаунт: $accountEmail, статус: ${isMailVerified ? "Подключен ($latency мс)" : "Требует проверки"}).\n'
          '• Календарь: $nextMeeting.\n\n'
          'Рекомендация: сфокусироваться на закрытии $urgentCount приоритетных задач до обеда.';

      final proposal = BrainActionProposal(
        id: 'prop-plan-${DateTime.now().millisecondsSinceEpoch}',
        toolName: 'createTask',
        arguments: {
          'title': 'Сфокусированный блок: закрыть $urgentCount приоритетные задачи',
          'project': 'ORBIT Фокус',
          'due': 'Сегодня 14:00',
        },
      );

      return BrainGenerationResult(
        replyText: PrivacyGuardrails.sanitizeText(text),
        actionProposal: proposal,
      );
    }

    // 2. Запрос на проверку почты / суммаризацию
    if (cleanQuery.contains('почт') ||
        cleanQuery.contains('письм') ||
        cleanQuery.contains('inbox') ||
        cleanQuery.contains('ящик')) {
      final mailStatusText = isMailVerified
          ? 'Соединение с $accountEmail стабильно (задержка: $latency мс).'
          : 'Внимание: соединение с $accountEmail еще не верифицировано!';

      final text =
          'Анализ почтового ящика:\n'
          '• Непрочитанных сообщений: $unreadEmails.\n'
          '• Активный почтовый аккаунт: $accountEmail.\n'
          '• Статус шлюза: $mailStatusText\n'
          '• Все персональные данные и токены экранированы [REDACTED].';

      BrainActionProposal? proposal;
      if (!isMailVerified) {
        proposal = BrainActionProposal(
          id: 'prop-verify-${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'verifyMailHealth',
          arguments: {'email': accountEmail},
        );
      } else {
        proposal = BrainActionProposal(
          id: 'prop-draft-${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'composeMailDraft',
          arguments: {
            'to': 'team@orbit.local',
            'subject': 'Статус синхронизации ORBIT',
            'body': 'Привет! Почтовый шлюз проверен ($latency мс). Готовы к релизу.',
          },
        );
      }

      return BrainGenerationResult(
        replyText: PrivacyGuardrails.sanitizeText(text),
        actionProposal: proposal,
      );
    }

    // 3. Запрос на создание задачи
    if (cleanQuery.contains('задач') ||
        cleanQuery.contains('напомн') ||
        cleanQuery.contains('сделать') ||
        cleanQuery.contains('todo')) {
      final taskTitle = query.length > 20
          ? query.replaceFirst(RegExp(r'^(создай|добавь|поставь)\s+(задачу\s+)?', caseSensitive: false), '').trim()
          : 'Подготовить материалы к релизу ORBIT';

      final cleanTitle = taskTitle.isNotEmpty ? taskTitle : 'Новая задача из ассистента';

      final text =
          'Я подготовил новую задачу для вашего трекера.\n'
          'Название: «$cleanTitle».\n'
          'Нажмите кнопку ниже для подтверждения и добавления в 1 тап.';

      return BrainGenerationResult(
        replyText: PrivacyGuardrails.sanitizeText(text),
        actionProposal: BrainActionProposal(
          id: 'prop-task-${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'createTask',
          arguments: {'title': cleanTitle, 'project': 'Brain AI'},
        ),
      );
    }

    // 4. Запрос на встречу / расписание
    if (cleanQuery.contains('встреч') ||
        cleanQuery.contains('календар') ||
        cleanQuery.contains('совещ') ||
        cleanQuery.contains('синк')) {
      final text =
          'Ближайшее событие в расписании: $nextMeeting.\n'
          'Предлагаю запланировать координационный синк.';

      return BrainGenerationResult(
        replyText: PrivacyGuardrails.sanitizeText(text),
        actionProposal: BrainActionProposal(
          id: 'prop-meeting-${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'scheduleMeeting',
          arguments: {
            'title': 'Координационный синк ORBIT',
            'time': '16:00',
            'location': 'Spatial Room',
          },
        ),
      );
    }

    // 5. Запрос на проверку соединения
    if (cleanQuery.contains('пинг') ||
        cleanQuery.contains('ping') ||
        cleanQuery.contains('соединен') ||
        cleanQuery.contains('связь')) {
      return BrainGenerationResult(
        replyText:
            'Диагностика почтового соединения готова к выполнению. Нажмите кнопку для моментальной проверки сокетов.',
        actionProposal: BrainActionProposal(
          id: 'prop-ping-${DateTime.now().millisecondsSinceEpoch}',
          toolName: 'verifyMailHealth',
          arguments: {'email': accountEmail},
        ),
      );
    }

    // Дефолтный глубокий ответ Gemini
    final defaultResponse =
        'Я изучил текущий контекст экосистемы:\n'
        '• $pendingCount активных задач\n'
        '• $unreadEmails непрочитанных писем\n'
        '• Почтовый ящик: $accountEmail\n\n'
        'Чем именно мы займемся? Могу составить план, написать письмо, запланировать встречу или проверить сокеты почты.';

    return BrainGenerationResult(
      replyText: PrivacyGuardrails.sanitizeText(defaultResponse),
      actionProposal: null,
    );
  }

  /// Потоковая эмуляция выдачи токенов (streaming response).
  Stream<String> streamTokens(String fullText, {Duration delay = const Duration(milliseconds: 15)}) async* {
    final words = fullText.split(' ');
    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(words[i]);
      yield buffer.toString();
      await Future<void>.delayed(delay);
    }
  }
}
