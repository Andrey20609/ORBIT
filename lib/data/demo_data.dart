import 'package:flutter/material.dart';
import '../services/mail/mail_connection_verifier.dart';

export '../services/mail/mail_connection_verifier.dart'
    show OrbitMailAccount, OrbitMailAccountStatus, OrbitMailProviderType;

@immutable
final class DemoEmail {
  const DemoEmail({
    required this.id,
    required this.sender,
    required this.email,
    required this.subject,
    required this.preview,
    required this.body,
    required this.time,
    required this.color,
    this.unread = false,
    this.attachments = const [],
    this.starred = false,
  });

  final String id;
  final String sender;
  final String email;
  final String subject;
  final String preview;
  final String body;
  final String time;
  final Color color;
  final bool unread;
  final List<String> attachments;
  final bool starred;
}

enum AttendeeStatus { accepted, declined, tentative, unknown }

@immutable
final class EventAttendee {
  const EventAttendee({
    required this.name,
    required this.email,
    this.status = AttendeeStatus.unknown,
    this.avatarUrl,
  });

  final String name;
  final String email;
  final AttendeeStatus status;
  final String? avatarUrl;

  EventAttendee copyWith({
    String? name,
    String? email,
    AttendeeStatus? status,
    String? avatarUrl,
  }) => EventAttendee(
    name: name ?? this.name,
    email: email ?? this.email,
    status: status ?? this.status,
    avatarUrl: avatarUrl ?? this.avatarUrl,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'email': email,
    'status': status.name,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
  };

  factory EventAttendee.fromJson(Map<String, Object?> json) => EventAttendee(
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    status: AttendeeStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => AttendeeStatus.unknown,
    ),
    avatarUrl: json['avatarUrl'] as String?,
  );
}

@immutable
final class EventOrganizer {
  const EventOrganizer({
    required this.name,
    required this.email,
  });

  final String name;
  final String email;

  EventOrganizer copyWith({String? name, String? email}) => EventOrganizer(
    name: name ?? this.name,
    email: email ?? this.email,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'email': email,
  };

  factory EventOrganizer.fromJson(Map<String, Object?> json) => EventOrganizer(
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
  );
}

@immutable
final class EventAttachment {
  const EventAttachment({
    required this.name,
    required this.type,
    required this.sizeBytes,
    this.uri,
  });

  final String name;
  final String type;
  final int sizeBytes;
  final String? uri;

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'type': type,
    'sizeBytes': sizeBytes,
    if (uri != null) 'uri': uri,
  };

  factory EventAttachment.fromJson(Map<String, Object?> json) => EventAttachment(
    name: json['name'] as String? ?? '',
    type: json['type'] as String? ?? 'file',
    sizeBytes: (json['sizeBytes'] as num? ?? 0).toInt(),
    uri: json['uri'] as String?,
  );
}

@immutable
final class DemoEvent {
  const DemoEvent(
    this.id,
    this.time,
    this.title,
    this.meta,
    this.color, {
    this.date,
    this.endTime,
    this.description,
    this.location,
    this.organizer,
    this.attendees = const <EventAttendee>[],
    this.attachments = const <EventAttachment>[],
    this.conferenceUrl,
  });

  final String id;
  final String time;
  final String title;
  final String meta;
  final Color color;
  final DateTime? date;
  final String? endTime;
  final String? description;
  final String? location;
  final EventOrganizer? organizer;
  final List<EventAttendee> attendees;
  final List<EventAttachment> attachments;
  final String? conferenceUrl;

  DemoEvent copyWith({
    String? id,
    String? time,
    String? title,
    String? meta,
    Color? color,
    DateTime? date,
    bool clearDate = false,
    String? endTime,
    bool clearEndTime = false,
    String? description,
    bool clearDescription = false,
    String? location,
    bool clearLocation = false,
    EventOrganizer? organizer,
    bool clearOrganizer = false,
    List<EventAttendee>? attendees,
    List<EventAttachment>? attachments,
    String? conferenceUrl,
    bool clearConferenceUrl = false,
  }) => DemoEvent(
    id ?? this.id,
    time ?? this.time,
    title ?? this.title,
    meta ?? this.meta,
    color ?? this.color,
    date: clearDate ? null : (date ?? this.date),
    endTime: clearEndTime ? null : (endTime ?? this.endTime),
    description: clearDescription ? null : (description ?? this.description),
    location: clearLocation ? null : (location ?? this.location),
    organizer: clearOrganizer ? null : (organizer ?? this.organizer),
    attendees: attendees ?? this.attendees,
    attachments: attachments ?? this.attachments,
    conferenceUrl: clearConferenceUrl
        ? null
        : (conferenceUrl ?? this.conferenceUrl),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'time': time,
    'title': title,
    'meta': meta,
    'color': color.toARGB32(),
    'date': date?.toIso8601String(),
    if (endTime != null) 'endTime': endTime,
    if (description != null) 'description': description,
    if (location != null) 'location': location,
    if (organizer != null) 'organizer': organizer!.toJson(),
    if (attendees.isNotEmpty)
      'attendees': attendees.map((a) => a.toJson()).toList(),
    if (attachments.isNotEmpty)
      'attachments': attachments.map((a) => a.toJson()).toList(),
    if (conferenceUrl != null) 'conferenceUrl': conferenceUrl,
  };

  factory DemoEvent.fromJson(Map<String, Object?> json) {
    final color = json['color'];
    final organizerJson = json['organizer'] as Map<String, Object?>?;
    final attendeesJson = json['attendees'] as List<Object?>?;
    final attachmentsJson = json['attachments'] as List<Object?>?;
    return DemoEvent(
      json['id'] as String,
      json['time'] as String,
      json['title'] as String,
      json['meta'] as String? ?? '',
      color is int ? Color(color) : const Color(0xFF9B8CFF),
      date: DateTime.tryParse(json['date'] as String? ?? ''),
      endTime: json['endTime'] as String?,
      description: json['description'] as String?,
      location: json['location'] as String?,
      organizer: organizerJson != null
          ? EventOrganizer.fromJson(organizerJson)
          : null,
      attendees: attendeesJson != null
          ? attendeesJson
              .whereType<Map<String, Object?>>()
              .map(EventAttendee.fromJson)
              .toList()
          : const <EventAttendee>[],
      attachments: attachmentsJson != null
          ? attachmentsJson
              .whereType<Map<String, Object?>>()
              .map(EventAttachment.fromJson)
              .toList()
          : const <EventAttachment>[],
      conferenceUrl: json['conferenceUrl'] as String?,
    );
  }
}

@immutable
final class DemoTask {
  const DemoTask({
    required this.id,
    required this.title,
    required this.project,
    required this.due,
    this.done = false,
    this.priority = 0,
  });

  final String id;
  final String title;
  final String project;
  final String due;
  final bool done;
  final int priority;

  DemoTask copyWith({
    String? title,
    String? project,
    String? due,
    bool? done,
    int? priority,
  }) => DemoTask(
    id: id,
    title: title ?? this.title,
    project: project ?? this.project,
    due: due ?? this.due,
    done: done ?? this.done,
    priority: priority ?? this.priority,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'title': title,
    'project': project,
    'due': due,
    'done': done,
    'priority': priority,
  };

  factory DemoTask.fromJson(Map<String, Object?> json) => DemoTask(
    id: json['id'] as String,
    title: json['title'] as String,
    project: json['project'] as String? ?? 'local-list',
    due: json['due'] as String? ?? 'no-due',
    done: json['done'] as bool? ?? false,
    priority: (json['priority'] as num? ?? 0).toInt().clamp(0, 2),
  );
}

const demoEmails = <DemoEmail>[
  DemoEmail(
    id: 'weekly-plan',
    sender: 'Мария Соколова',
    email: 'maria@example.demo',
    subject: 'План на неделю',
    preview: 'Привет! Прикрепляю обновлённый план на следующую неделю…',
    body:
        'Привет, Алексей!\n\nПрикрепляю обновлённый план на следующую неделю. Давай обсудим на встрече во вторник.\n\nЯ выделила ключевые этапы, добавила время на спокойную проверку и оставила пространство для незапланированных задач.\n\nХорошего дня!',
    time: '09:24',
    color: Color(0xFFB18CE8),
    unread: true,
    attachments: ['План_недели.pdf · 2,4 МБ', 'График.xlsx · 1,1 МБ'],
    starred: true,
  ),
  DemoEmail(
    id: 'design-review',
    sender: 'Илья Волков',
    email: 'ilya@example.demo',
    subject: 'Обсуждение дизайна',
    preview: 'Прикладываю актуальные варианты и короткие комментарии…',
    body:
        'Привет!\n\nПрикладываю актуальные варианты и короткие комментарии. Особенно интересно твоё мнение о плотности списка и поведении нижней навигации.',
    time: '08:47',
    color: Color(0xFF7FB8DA),
    unread: true,
  ),
  DemoEmail(
    id: 'project-update',
    sender: 'Команда ORBIT',
    email: 'team@example.demo',
    subject: 'Обновление по проекту',
    preview: 'Статус, следующие шаги и спокойный фокус на главном…',
    body:
        'Коллеги, привет!\n\nОсновной этап завершён. Следующие шаги: визуальная проверка, тестирование на устройствах и подготовка передачи в основной продукт.',
    time: 'Вчера',
    color: Color(0xFF9B8CFF),
    attachments: ['Презентация.pdf · 7,8 МБ'],
  ),
  DemoEmail(
    id: 'research-notes',
    sender: 'Анна Ремизова',
    email: 'anna@example.demo',
    subject: 'Встреча: подготовка',
    preview: 'Материалы и повестка внутри. Встреча займёт около часа…',
    body:
        'Добрый день!\n\nМатериалы и повестка внутри. Предлагаю сначала обсудить пользовательские сценарии, затем визуальные ограничения.',
    time: 'Вчера',
    color: Color(0xFFE7A1A9),
  ),
  DemoEmail(
    id: 'focus-notes',
    sender: 'ORBIT Notes',
    email: 'notes@example.demo',
    subject: 'Три мысли для спокойного дня',
    preview: 'Начните с главного, оставьте место для паузы…',
    body:
        'Начните с главного, оставьте место для паузы, завершите день коротким обзором.\n\nЭто демонстрационное письмо локальной оболочки ORBIT.',
    time: 'Пн',
    color: Color(0xFF83C5B4),
  ),
];

const demoEvents = <DemoEvent>[
  DemoEvent(
    'review',
    '10:00',
    'Совещание по ВП',
    'Команда · Онлайн · 1 ч',
    Color(0xFF82B9FF),
    endTime: '11:00',
    description:
        'Координационное совещание по внедрению внутренних сервисов ORBIT. Обсуждение этапов интеграции и архитектурного плана.',
    location: 'Переговорная 4 / Онлайн',
    conferenceUrl: 'https://meet.orbit.local/vp-review',
    organizer: EventOrganizer(
      name: 'Алексей Смирнов',
      email: 'a.smirnov@orbit.local',
    ),
    attendees: [
      EventAttendee(
        name: 'Алексей Смирнов',
        email: 'a.smirnov@orbit.local',
        status: AttendeeStatus.accepted,
      ),
      EventAttendee(
        name: 'Мария Кузнецова',
        email: 'm.kuznetsova@orbit.local',
        status: AttendeeStatus.accepted,
      ),
      EventAttendee(
        name: 'Дмитрий Волков',
        email: 'd.volkov@orbit.local',
        status: AttendeeStatus.tentative,
      ),
    ],
    attachments: [
      EventAttachment(
        name: 'План_внедрения_ВП_v2.pdf',
        type: 'PDF',
        sizeBytes: 2450000,
        uri: 'file:///docs/План_внедрения_ВП_v2.pdf',
      ),
      EventAttachment(
        name: 'График_контрольных_точек.xlsx',
        type: 'XLSX',
        sizeBytes: 1120000,
        uri: 'file:///docs/График_контрольных_точек.xlsx',
      ),
    ],
  ),
  DemoEvent(
    'audit',
    '13:30',
    'Аудит СПД Тэнда',
    'Проект · Исследования · 1 ч',
    Color(0xFFFF9A9E),
    endTime: '14:30',
    description:
        'Регулярный аудит сетей передачи данных и проверка соответствия политикам безопасности.',
    location: 'Серверная 2Б',
    organizer: EventOrganizer(
      name: 'Екатерина Морозова',
      email: 'e.morozova@orbit.local',
    ),
    attendees: [
      EventAttendee(
        name: 'Екатерина Морозова',
        email: 'e.morozova@orbit.local',
        status: AttendeeStatus.accepted,
      ),
      EventAttendee(
        name: 'Игорь Павлов',
        email: 'i.pavlov@orbit.local',
        status: AttendeeStatus.accepted,
      ),
    ],
    attachments: [
      EventAttachment(
        name: 'Чеклист_СПД_2026.docx',
        type: 'DOCX',
        sizeBytes: 384000,
        uri: 'file:///docs/Чеклист_СПД_2026.docx',
      ),
    ],
  ),
  DemoEvent(
    'report',
    '17:00',
    'Подготовить отчёт',
    'ВП / БАМ · Фокус · 1 ч',
    Color(0xFFFFC184),
    endTime: '18:00',
    description:
        'Сводка показателей эффективности за текущий период и формирование итоговой аналитики.',
    location: 'Рабочее место',
    organizer: EventOrganizer(
      name: 'Пользователь ORBIT',
      email: 'user@orbit.local',
    ),
  ),
];

const initialTasks = <DemoTask>[
  DemoTask(
    id: 'report',
    title: 'Подготовить отчёт по КПЭ',
    project: 'ORBIT One',
    due: 'Сегодня, 17:00',
    priority: 2,
  ),
  DemoTask(
    id: 'plan',
    title: 'Актуализировать план развития',
    project: 'Стратегия',
    due: 'Завтра',
    priority: 1,
  ),
  DemoTask(
    id: 'materials',
    title: 'Согласовать материалы по ВП',
    project: 'ВП',
    due: 'Выполнено',
    done: true,
  ),
  DemoTask(
    id: 'data',
    title: 'Отправить данные в ЦА',
    project: 'ВП / БАМ',
    due: '5 ноября',
  ),
];

/// Системные папки почтового клиента ORBIT Mail.
enum OrbitMailFolder {
  inbox('Входящие', Icons.inbox_rounded),
  sent('Отправленные', Icons.send_rounded),
  drafts('Черновики', Icons.drafts_rounded),
  outbox('Исходящие', Icons.outbox_rounded),
  archive('Архив', Icons.archive_outlined),
  trash('Корзина', Icons.delete_outline_rounded),
  spam('Спам', Icons.report_gmailerrorred_rounded);

  const OrbitMailFolder(this.label, this.icon);
  final String label;
  final IconData icon;

  static OrbitMailFolder fromName(String? raw) {
    for (final folder in OrbitMailFolder.values) {
      if (folder.name == raw) return folder;
    }
    return OrbitMailFolder.inbox;
  }
}

/// Модель отправленного / пользовательского письма с поддержкой JSON-персистентности.
@immutable
final class OrbitSentMailEntry {
  const OrbitSentMailEntry({
    required this.id,
    required this.recipient,
    required this.subject,
    required this.body,
    required this.sentAtIso,
    this.isImportant = false,
  });

  final String id;
  final String recipient;
  final String subject;
  final String body;
  final String sentAtIso;
  final bool isImportant;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'recipient': recipient,
        'subject': subject,
        'body': body,
        'sentAtIso': sentAtIso,
        'isImportant': isImportant,
      };

  factory OrbitSentMailEntry.fromJson(Map<String, Object?> json) {
    return OrbitSentMailEntry(
      id: (json['id'] as String?) ?? 'sent_0',
      recipient: (json['recipient'] as String?) ?? '',
      subject: (json['subject'] as String?) ?? 'Без темы',
      body: (json['body'] as String?) ?? '',
      sentAtIso:
          (json['sentAtIso'] as String?) ?? DateTime.now().toIso8601String(),
      isImportant: (json['isImportant'] as bool?) ?? false,
    );
  }
}

/// Стартовый список учетных записей (демо-аккаунт по умолчанию).
final List<OrbitMailAccount> initialMailAccounts =
    OrbitMailAccount.defaultInitialAccounts;



