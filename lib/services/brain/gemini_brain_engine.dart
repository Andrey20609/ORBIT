import 'dart:async';
import 'package:flutter/foundation.dart';

import '../mail/mail_connection_verifier.dart';

/// Отправитель сообщения в мульти-терн истории ORBIT Brain.
enum BrainMessageSender {
  user,
  assistant,
  system;

  static BrainMessageSender fromName(String? raw) {
    for (final s in BrainMessageSender.values) {
      if (s.name == raw) return s;
    }
    return BrainMessageSender.assistant;
  }
}

/// Поддерживаемые системные инструменты ИИ (1-Tap Action Proposals).
enum BrainToolType {
  createTask('Создать задачу'),
  scheduleMeeting('Запланировать встречу'),
  composeMailDraft('Подготовить черновик письма'),
  verifyMailHealth('Проверить шлюз почты');

  const BrainToolType(this.label);
  final String label;

  static BrainToolType fromName(String? raw) {
    for (final t in BrainToolType.values) {
      if (t.name == raw) return t;
    }
    return BrainToolType.createTask;
  }
}

/// Интерактивное предложение действия от ИИ с выполнением в 1 тап.
@immutable
final class BrainActionProposal {
  const BrainActionProposal({
    required this.id,
    required this.tool,
    required this.title,
    required this.subtitle,
    required this.arguments,
    this.isExecuted = false,
    this.isDismissed = false,
  });

  final String id;
  final BrainToolType tool;
  final String title;
  final String subtitle;
  final Map<String, String> arguments;
  final bool isExecuted;
  final bool isDismissed;

  BrainActionProposal copyWith({
    bool? isExecuted,
    bool? isDismissed,
  }) {
    return BrainActionProposal(
      id: id,
      tool: tool,
      title: title,
      subtitle: subtitle,
      arguments: arguments,
      isExecuted: isExecuted ?? this.isExecuted,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'tool': tool.name,
        'title': title,
        'subtitle': subtitle,
        'arguments': arguments,
        'isExecuted': isExecuted,
        'isDismissed': isDismissed,
      };

  factory BrainActionProposal.fromJson(Map<String, Object?> json) {
    final rawArgs = json['arguments'] as Map<Object?, Object?>? ?? const {};
    return BrainActionProposal(
      id: (json['id'] as String?) ?? 'prop_0',
      tool: BrainToolType.fromName(json['tool'] as String?),
      title: (json['title'] as String?) ?? 'Действие экосистемы',
      subtitle: (json['subtitle'] as String?) ?? '',
      arguments: <String, String>{
        for (final entry in rawArgs.entries)
          if (entry.key is String && entry.value != null)
            entry.key as String: '${entry.value}',
      },
      isExecuted: (json['isExecuted'] as bool?) ?? false,
      isDismissed: (json['isDismissed'] as bool?) ?? false,
    );
  }
}

/// Сообщение в персистентной истории диалога ORBIT Brain.
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
    String? text,
    BrainActionProposal? actionProposal,
    bool? isStreaming,
  }) {
    return BrainChatMessage(
      id: id,
      sender: sender,
      text: text ?? this.text,
      timestamp: timestamp,
      actionProposal: actionProposal ?? this.actionProposal,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'sender': sender.name,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        if (actionProposal != null) 'actionProposal': actionProposal!.toJson(),
      };

  factory BrainChatMessage.fromJson(Map<String, Object?> json) {
    final propRaw = json['actionProposal'];
    return BrainChatMessage(
      id: (json['id'] as String?) ?? 'msg_0',
      sender: BrainMessageSender.fromName(json['sender'] as String?),
      text: (json['text'] as String?) ?? '',
      timestamp: DateTime.tryParse((json['timestamp'] as String?) ?? '') ??
          DateTime.now(),
      actionProposal: propRaw is Map<String, Object?>
          ? BrainActionProposal.fromJson(propRaw)
          : null,
    );
  }
}

/// Живой снимок контекста экосистемы для промпт-инъекции.
@immutable
final class BrainEcosystemSnapshot {
  const BrainEcosystemSnapshot({
    required this.openTasksCount,
    required this.urgentTaskTitles,
    required this.upcomingMeetingsCount,
    required this.nextMeetingLabel,
    required this.unreadMailCount,
    required this.activeMailAccountEmail,
    required this.mailAccountStatus,
    this.lastMailLatencyMs,
  });

  final int openTasksCount;
  final List<String> urgentTaskTitles;
  final int upcomingMeetingsCount;
  final String nextMeetingLabel;
  final int unreadMailCount;
  final String activeMailAccountEmail;
  final OrbitMailAccountStatus mailAccountStatus;
  final int? lastMailLatencyMs;
}

/// Локальный демонстрационный прототип нейросетевого ядра ORBIT Brain (Gemini 2.0 Edge Simulator):
/// формирует системный контекст с защитой приватности PrivacyGuardrails,
/// генерирует потоковый ответ (token streaming) и формирует карточки действий экосистемы в 1 клик.
final class OrbitGeminiBrainEngine {
  OrbitGeminiBrainEngine({
    this.tokenDelay = const Duration(milliseconds: 14),
  });

  final Duration tokenDelay;

  /// Маскирует пароли, банковские карты, пин-коды и Bearer/API-токены перед обработкой.
  /// Поддерживает как английские (password, token, key), так и русские ключевые слова
  /// (пароль, секрет, токен, код, пин, ключ) с любыми разделителями (':', '=', '-', пробел)
  /// или сразу за ключевым словом.
  static String sanitizeWithPrivacyGuardrails(String input) {
    var result = input;
    // 1. Маскирование банковских карт (от 13 до 19 цифр с возможными пробелами/дефисами)
    result = result.replaceAll(
      RegExp(r'\b(?:\d[ -]*?){13,19}\b'),
      '[CARD_REDACTED]',
    );

    // 2. Маскирование секретов, паролей и токенов (RU + EN):
    // Ключевые слова: password, passwd, pass, pwd, secret, token, api_?key, bearer, pin,
    // пароль, пароля, пароли, секрет, секрета, токен, токена, код, кода, пин, ключ, ключа
    // Разделители: ':', '=', '-', пробел(ы)
    result = result.replaceAllMapped(
      RegExp(
        r'(^|[\s,;:(])(password|passwd|pass|pwd|secret|token|api[_-]?key|bearer|pin|парол[ьяеи]|секрет(?:а|ы)?|токен(?:а|ы)?|код(?:а|ы)?|пин(?:-?код)?|ключ(?:а|и)?)\s*[:=\-]?\s*([^\s,;]+)',
        caseSensitive: false,
        unicode: true,
      ),
      (match) {
        final prefix = match.group(1) ?? '';
        final original = match.group(0)!;
        final secret = match.group(3) ?? '';
        final keywordAndSep = original.substring(prefix.length, original.length - secret.length);
        return '$prefix$keywordAndSep[SECRET_REDACTED]';
      },
    );

    return result;
  }

  /// Строит системный контекстный промпт уровня Gemini 2.0 Pro по живому снимку экосистемы.
  String buildSystemPrompt(BrainEcosystemSnapshot snapshot) {
    final latencyInfo = snapshot.lastMailLatencyMs != null
        ? '${snapshot.lastMailLatencyMs} ms'
        : 'н/д';
    return 'SYSTEM [ORBIT Gemini Brain 2.0]: '
        'Задач в работе: ${snapshot.openTasksCount} (Приоритет: ${snapshot.urgentTaskTitles.join(", ")}). '
        'Встреч сегодня: ${snapshot.upcomingMeetingsCount} (Ближайшая: ${snapshot.nextMeetingLabel}). '
        'Непрочитанных писем: ${snapshot.unreadMailCount}. '
        'Почтовый шлюз ${snapshot.activeMailAccountEmail}: ${snapshot.mailAccountStatus.label} ($latencyInfo). '
        'PrivacyGuardrails: ACTIVE.';
  }

  /// Генерирует ответ и структурированное предложение действия (`BrainActionProposal`) по запросу.
  ({String fullText, BrainActionProposal? proposal}) evaluatePrompt(
    String rawUserPrompt,
    BrainEcosystemSnapshot snapshot,
  ) {
    final sanitizedPrompt = sanitizeWithPrivacyGuardrails(rawUserPrompt);
    final lower = sanitizedPrompt.toLowerCase();
    final nowId = DateTime.now().microsecondsSinceEpoch;

    if (lower.contains('почт') ||
        lower.contains('письм') ||
        lower.contains('imap') ||
        lower.contains('соединен')) {
      final statusText =
          snapshot.mailAccountStatus == OrbitMailAccountStatus.verified
              ? 'подключен и защищен TLS (${snapshot.lastMailLatencyMs ?? 32} мс)'
              : 'требует верификации соединения';
      return (
        fullText:
            'Проверил почтовый контур **${snapshot.activeMailAccountEmail}**: шлюз $statusText. '
            'Во входящих неразобрано писем: **${snapshot.unreadMailCount}**. '
            'Могу запустить глубокую диагностику IMAP/SMTP или подготовить черновик ответа.',
        proposal: BrainActionProposal(
          id: 'prop_mail_$nowId',
          tool: BrainToolType.verifyMailHealth,
          title: 'Проверить почтовый шлюз ${snapshot.activeMailAccountEmail}',
          subtitle: 'DNS • TCP • TLSv1.3 • Замер пинга',
          arguments: <String, String>{
            'email': snapshot.activeMailAccountEmail,
            'action': 'ping',
          },
        ),
      );
    }

    if (lower.contains('встреч') ||
        lower.contains('календар') ||
        lower.contains('синк') ||
        lower.contains('совещ')) {
      return (
        fullText:
            'В вашем расписании на сегодня запланировано встреч: **${snapshot.upcomingMeetingsCount}**.\n'
            'Ближайшее событие: **${snapshot.nextMeetingLabel}**.\n'
            'Рекомендую назначить синк по согласованию релиза 0.5.30+36.',
        proposal: BrainActionProposal(
          id: 'prop_meet_$nowId',
          tool: BrainToolType.scheduleMeeting,
          title: 'Запланировать: Синк релиза 0.5.30+36',
          subtitle: 'Сегодня в 16:30 • Spatial Meeting Room',
          arguments: <String, String>{
            'title': 'Синк релиза 0.5.30+36',
            'time': '16:30',
            'location': 'Spatial Room',
          },
        ),
      );
    }

    if (lower.contains('задач') ||
        lower.contains('завтра') ||
        lower.contains('план') ||
        lower.contains('сводка')) {
      final focusTask = snapshot.urgentTaskTitles.isNotEmpty
          ? snapshot.urgentTaskTitles.first
          : 'Аудит релизного комплекта 0.5.30';
      return (
        fullText:
            'Сформировал фокусную сводку экосистемы:\n'
            '• Активных задач: **${snapshot.openTasksCount}**\n'
            '• Главный приоритет: **$focusTask**\n'
            '• Почтовый ящик: **${snapshot.activeMailAccountEmail}** (${snapshot.unreadMailCount} неразобранных)\n\n'
            'Предлагаю зафиксировать высокоприоритетную задачу в ORBIT Tasks:',
        proposal: BrainActionProposal(
          id: 'prop_task_$nowId',
          tool: BrainToolType.createTask,
          title: 'Фокус: $focusTask',
          subtitle: 'Приоритет: Высокий • Срок: Завтра 12:00',
          arguments: <String, String>{
            'title': focusTask,
            'project': 'Релизный аудит',
            'due': 'Завтра 12:00',
          },
        ),
      );
    }

    // Дефолтный свободный ответ Gemini Pro с контекстной инъекцией
    return (
      fullText:
          'ORBIT Brain на связи. Я держу в активном контексте ваши **${snapshot.openTasksCount} задач**, '
          '**${snapshot.upcomingMeetingsCount} встречи** и почтовый шлюз **${snapshot.activeMailAccountEmail}**.\n\n'
          'Готов составить план, отправить черновик письма или провести проверку подключения.',
      proposal: null,
    );
  }

  /// Потоковый генератор выдачи токенов (эмуляция генерации Gemini).
  Stream<String> streamTokens(String text) async* {
    if (tokenDelay == Duration.zero) {
      yield text;
      return;
    }
    final words = text.split(' ');
    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(words[i]);
      yield buffer.toString();
      await Future<void>.delayed(tokenDelay);
    }
  }
}
