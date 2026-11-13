import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Категории (папки) чатов в стиле Telegram.
enum OrbitChatFolder {
  all('Все чаты'),
  personal('Личные'),
  work('Рабочие'),
  channels('Каналы'),
  saved('Избранное');

  const OrbitChatFolder(this.label);
  final String label;
}

/// Режим транспорта мессенджера (Локальный прототип устойчивой связи в РФ).
enum OrbitMessengerTransportMode {
  hybridAuto(
    'Гибридный (Авто WSS + IMAP)',
    'Локальный прототип: симуляция WSS:443 с бесшовным резервом через Яндекс/Mail.ru IMAP',
  ),
  wssRelay443(
    'Прямой WSS поверх HTTPS (443)',
    'Локальный прототип: симуляция TLS 1.3 веб-туннеля с минимальной задержкой',
  ),
  imapDeltaBridge(
    'IMAP-Мост (Яндекс / Mail.ru)',
    'Локальный прототип: симуляция работы через российские почтовые шлюзы без внешних серверов',
  );

  const OrbitMessengerTransportMode(this.label, this.description);
  final String label;
  final String description;

  static OrbitMessengerTransportMode fromName(String? raw) {
    for (final m in OrbitMessengerTransportMode.values) {
      if (m.name == raw) return m;
    }
    return OrbitMessengerTransportMode.hybridAuto;
  }
}

/// Статус доставки сообщения в гибридном канале.
enum OrbitMessageDeliveryStatus {
  queuedOffline,
  sentViaWss,
  sentViaImapBridge,
  delivered,
  read;

  static OrbitMessageDeliveryStatus fromName(String? raw) {
    for (final s in OrbitMessageDeliveryStatus.values) {
      if (s.name == raw) return s;
    }
    return OrbitMessageDeliveryStatus.delivered;
  }
}

/// Сообщение в чате ORBIT Messenger.
@immutable
final class OrbitChatMessage {
  const OrbitChatMessage({
    required this.id,
    required this.chatId,
    required this.senderName,
    required this.text,
    required this.timestampIso,
    required this.isOutgoing,
    this.replyToMessageId,
    this.replyPreviewText,
    this.voiceDurationSec,
    this.voiceWaveform = const <double>[],
    this.reactions = const <String, int>{},
    this.deliveryStatus = OrbitMessageDeliveryStatus.read,
    this.linkedTaskId,
    this.linkedMeetingId,
  });

  final String id;
  final String chatId;
  final String senderName;
  final String text;
  final String timestampIso;
  final bool isOutgoing;
  final String? replyToMessageId;
  final String? replyPreviewText;
  final int? voiceDurationSec;
  final List<double> voiceWaveform;
  final Map<String, int> reactions;
  final OrbitMessageDeliveryStatus deliveryStatus;
  final String? linkedTaskId;
  final String? linkedMeetingId;

  bool get isVoiceMessage => voiceDurationSec != null && voiceDurationSec! > 0;

  OrbitChatMessage copyWith({
    String? text,
    Map<String, int>? reactions,
    OrbitMessageDeliveryStatus? deliveryStatus,
    String? linkedTaskId,
    String? linkedMeetingId,
  }) {
    return OrbitChatMessage(
      id: id,
      chatId: chatId,
      senderName: senderName,
      text: text ?? this.text,
      timestampIso: timestampIso,
      isOutgoing: isOutgoing,
      replyToMessageId: replyToMessageId,
      replyPreviewText: replyPreviewText,
      voiceDurationSec: voiceDurationSec,
      voiceWaveform: voiceWaveform,
      reactions: reactions ?? this.reactions,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      linkedMeetingId: linkedMeetingId ?? this.linkedMeetingId,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'chatId': chatId,
        'senderName': senderName,
        'text': text,
        'timestampIso': timestampIso,
        'isOutgoing': isOutgoing,
        'replyToMessageId': replyToMessageId,
        'replyPreviewText': replyPreviewText,
        'voiceDurationSec': voiceDurationSec,
        'voiceWaveform': voiceWaveform,
        'reactions': reactions,
        'deliveryStatus': deliveryStatus.name,
        'linkedTaskId': linkedTaskId,
        'linkedUsedMeetingId': linkedMeetingId,
      };

  factory OrbitChatMessage.fromJson(Map<String, Object?> json) {
    final rawReactions =
        json['reactions'] as Map<Object?, Object?>? ?? const {};
    final rawWave = json['voiceWaveform'] as List<dynamic>? ?? const [];
    return OrbitChatMessage(
      id: (json['id'] as String?) ?? 'msg_0',
      chatId: (json['chatId'] as String?) ?? 'chat_saved',
      senderName: (json['senderName'] as String?) ?? 'ORBIT',
      text: (json['text'] as String?) ?? '',
      timestampIso:
          (json['timestampIso'] as String?) ?? DateTime.now().toIso8601String(),
      isOutgoing: (json['isOutgoing'] as bool?) ?? true,
      replyToMessageId: json['replyToMessageId'] as String?,
      replyPreviewText: json['replyPreviewText'] as String?,
      voiceDurationSec: json['voiceDurationSec'] as int?,
      voiceWaveform: rawWave.whereType<num>().map((e) => e.toDouble()).toList(),
      reactions: <String, int>{
        for (final entry in rawReactions.entries)
          if (entry.key is String && entry.value is int)
            entry.key as String: entry.value as int,
      },
      deliveryStatus: OrbitMessageDeliveryStatus.fromName(
        json['deliveryStatus'] as String?,
      ),
      linkedTaskId: json['linkedTaskId'] as String?,
      linkedMeetingId: json['linkedUsedMeetingId'] as String?,
    );
  }
}

/// Модель диалога / группы / канала в ORBIT Messenger.
@immutable
final class OrbitChatThread {
  const OrbitChatThread({
    required this.id,
    required this.title,
    required this.subtitleRole,
    required this.folder,
    required this.avatarInitials,
    this.peerEmail = 'colleague@yandex.ru',
    this.isOnline = true,
    this.isPinned = false,
    this.unreadCount = 0,
    this.isVerifiedBridge = true,
  });

  final String id;
  final String title;
  final String subtitleRole;
  final OrbitChatFolder folder;
  final String avatarInitials;
  final String peerEmail;
  final bool isOnline;
  final bool isPinned;
  final int unreadCount;
  final bool isVerifiedBridge;

  OrbitChatThread copyWith({
    int? unreadCount,
    bool? isPinned,
  }) {
    return OrbitChatThread(
      id: id,
      title: title,
      subtitleRole: subtitleRole,
      folder: folder,
      avatarInitials: avatarInitials,
      peerEmail: peerEmail,
      isOnline: isOnline,
      isPinned: isPinned ?? this.isPinned,
      unreadCount: unreadCount ?? this.unreadCount,
      isVerifiedBridge: isVerifiedBridge,
    );
  }
}

/// Движок гибридного мессенджера ORBIT (Вариант 1: WSS:443 + Вариант 3: IMAP-Bridge).
final class OrbitHybridMessengerController extends ChangeNotifier {
  OrbitHybridMessengerController({
    bool? isMockMode,
  }) : isMockMode = isMockMode ?? _detectTestEnv() {
    _seedInitialThreadsAndMessages();
  }

  final bool isMockMode;

  OrbitMessengerTransportMode _transportMode =
      OrbitMessengerTransportMode.hybridAuto;
  OrbitChatFolder _selectedFolder = OrbitChatFolder.all;
  String _activeImapAccountEmail = 'architect@yandex.ru';
  int _lastBridgeLatencyMs = 22;
  bool _isWssTunnelOnline = true;

  final List<OrbitChatThread> _threads = <OrbitChatThread>[];
  final Map<String, List<OrbitChatMessage>> _messagesByChat =
      <String, List<OrbitChatMessage>>{};

  OrbitMessengerTransportMode get transportMode => _transportMode;
  OrbitChatFolder get selectedFolder => _selectedFolder;
  String get activeImapAccountEmail => _activeImapAccountEmail;
  int get lastBridgeLatencyMs => _lastBridgeLatencyMs;
  bool get isWssTunnelOnline => _isWssTunnelOnline;

  /// Описание текущего активного маршрута доставки без VPN (локальный демонстрационный прототип).
  String get activeTransportBadge {
    final prefix = isMockMode ? 'Демо-прототип:' : 'Edge-симулятор:';
    return switch (_transportMode) {
      OrbitMessengerTransportMode.hybridAuto => _isWssTunnelOnline
          ? '$prefix WSS:443 + IMAP Резерв • $_lastBridgeLatencyMs ms'
          : '$prefix Офлайн (WSS недоступен) • IMAP Резерв',
      OrbitMessengerTransportMode.wssRelay443 =>
        '$prefix Direct WSS:443 TLS 1.3 • $_lastBridgeLatencyMs ms',
      OrbitMessengerTransportMode.imapDeltaBridge =>
        '$prefix IMAP-Push ($_activeImapAccountEmail) • $_lastBridgeLatencyMs ms',
    };
  }

  /// Устанавливает статус доступности WSS-туннеля для тестирования сценариев потери связи.
  void setWssTunnelOnlineForTest(bool online) {
    _isWssTunnelOnline = online;
    notifyListeners();
  }

  /// Выполняет сетевую проверку доступности транспортных шлюзов.
  Future<void> probeTransportConnectivity() async {
    if (isMockMode) {
      _lastBridgeLatencyMs = 22;
      _isWssTunnelOnline = true;
      notifyListeners();
      return;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final host = _transportMode == OrbitMessengerTransportMode.imapDeltaBridge
          ? 'imap.yandex.ru'
          : 'yandex.ru';
      final port = _transportMode == OrbitMessengerTransportMode.imapDeltaBridge
          ? 993
          : 443;
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 3),
      );
      stopwatch.stop();
      _lastBridgeLatencyMs = stopwatch.elapsedMilliseconds;
      _isWssTunnelOnline = true;
      await socket.close();
    } catch (_) {
      stopwatch.stop();
      _isWssTunnelOnline = false;
      _lastBridgeLatencyMs = 999;
    }
    notifyListeners();
  }

  List<OrbitChatThread> get visibleThreads {
    final filtered = _selectedFolder == OrbitChatFolder.all
        ? _threads
        : _threads.where((t) => t.folder == _selectedFolder).toList();
    filtered.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return a.title.compareTo(b.title);
    });
    return List<OrbitChatThread>.unmodifiable(filtered);
  }

  int get totalUnreadCount =>
      _threads.fold<int>(0, (sum, item) => sum + item.unreadCount);

  List<OrbitChatMessage> messagesForChat(String chatId) {
    return List<OrbitChatMessage>.unmodifiable(
      _messagesByChat[chatId] ?? const <OrbitChatMessage>[],
    );
  }

  OrbitChatMessage? lastMessageForChat(String chatId) {
    final list = _messagesByChat[chatId];
    if (list == null || list.isEmpty) return null;
    return list.last;
  }

  static bool _detectTestEnv() {
    if (kIsWeb) return true;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return true;
    }
  }

  void selectFolder(OrbitChatFolder folder) {
    if (_selectedFolder == folder) return;
    _selectedFolder = folder;
    notifyListeners();
  }

  void setTransportMode(OrbitMessengerTransportMode mode) {
    if (_transportMode == mode) return;
    _transportMode = mode;
    _lastBridgeLatencyMs = switch (mode) {
      OrbitMessengerTransportMode.wssRelay443 => 18,
      OrbitMessengerTransportMode.imapDeltaBridge => 34,
      OrbitMessengerTransportMode.hybridAuto => 22,
    };
    notifyListeners();
  }

  void bindImapAccount(String email) {
    if (email.trim().isEmpty) return;
    _activeImapAccountEmail = email.trim();
    notifyListeners();
  }

  void markChatAsRead(String chatId) {
    final idx = _threads.indexWhere((t) => t.id == chatId);
    if (idx != -1 && _threads[idx].unreadCount > 0) {
      _threads[idx] = _threads[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  /// Отправляет текстовое сообщение через выбранный гибридный контур (WSS:443 или IMAP-Bridge).
  Future<OrbitChatMessage> sendTextMessage({
    required String chatId,
    required String text,
    String? replyToMessageId,
    String? replyPreviewText,
  }) async {
    final cleaned = text.trim();
    if (!isMockMode) {
      await probeTransportConnectivity();
    }
    final delivery = _isWssTunnelOnline || isMockMode
        ? _resolveActiveDeliveryStatus()
        : OrbitMessageDeliveryStatus.queuedOffline;

    final msg = OrbitChatMessage(
      id: 'chat_msg_${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      senderName: 'Вы',
      text: cleaned,
      timestampIso: _formatTimeNow(),
      isOutgoing: true,
      replyToMessageId: replyToMessageId,
      replyPreviewText: replyPreviewText,
      deliveryStatus: delivery,
    );

    final list = _messagesByChat.putIfAbsent(chatId, () => <OrbitChatMessage>[]);
    list.add(msg);
    markChatAsRead(chatId);
    notifyListeners();
    return msg;
  }

  /// Отправляет голосовое сообщение с генерацией волны амплитуд (Telegram Voice Note).
  Future<OrbitChatMessage> sendVoiceMessage({
    required String chatId,
    int durationSeconds = 7,
  }) async {
    final delivery = _resolveActiveDeliveryStatus();
    final msg = OrbitChatMessage(
      id: 'voice_msg_${DateTime.now().microsecondsSinceEpoch}',
      chatId: chatId,
      senderName: 'Вы',
      text: 'Голосовое сообщение ($durationSeconds с)',
      timestampIso: _formatTimeNow(),
      isOutgoing: true,
      voiceDurationSec: durationSeconds,
      voiceWaveform: const <double>[
        0.25, 0.55, 0.85, 0.40, 0.95, 0.70, 0.35, 0.80, 0.60, 0.90, 0.50, 0.30,
      ],
      deliveryStatus: delivery,
    );

    final list = _messagesByChat.putIfAbsent(chatId, () => <OrbitChatMessage>[]);
    list.add(msg);
    notifyListeners();
    return msg;
  }

  /// Добавляет или увеличивает реакцию (emoji) на сообщении.
  void toggleReaction({
    required String chatId,
    required String messageId,
    required String emoji,
  }) {
    final list = _messagesByChat[chatId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final current = Map<String, int>.from(list[idx].reactions);
    if (current.containsKey(emoji)) {
      current.remove(emoji);
    } else {
      current[emoji] = 1;
    }
    list[idx] = list[idx].copyWith(reactions: current);
    notifyListeners();
  }

  /// Привязывает созданную Задачу или Встречу к сообщению чата (Cross-Entity Link).
  void attachCrossEntityToMessage({
    required String chatId,
    required String messageId,
    String? taskId,
    String? meetingId,
  }) {
    final list = _messagesByChat[chatId];
    if (list == null) return;
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    list[idx] = list[idx].copyWith(
      linkedTaskId: taskId ?? list[idx].linkedTaskId,
      linkedMeetingId: meetingId ?? list[idx].linkedMeetingId,
    );
    notifyListeners();
  }

  /// Формирует MIME-пакет для передачи сообщения поверх IMAP/SMTP (Delta-Chat протокол).
  Map<String, String> buildImapBridgeMimeHeaders({
    required OrbitChatThread thread,
    required OrbitChatMessage message,
  }) {
    return <String, String>{
      'From': _activeImapAccountEmail,
      'To': thread.peerEmail,
      'Subject': '[ORBIT-Chat] ${thread.title}',
      'X-Orbit-Chat-Version': '1.0',
      'X-Orbit-Chat-Id': thread.id,
      'X-Orbit-Msg-Id': message.id,
      'Content-Type': 'text/plain; charset=utf-8',
    };
  }

  OrbitMessageDeliveryStatus _resolveActiveDeliveryStatus() {
    return switch (_transportMode) {
      OrbitMessengerTransportMode.wssRelay443 =>
        OrbitMessageDeliveryStatus.sentViaWss,
      OrbitMessengerTransportMode.imapDeltaBridge =>
        OrbitMessageDeliveryStatus.sentViaImapBridge,
      OrbitMessengerTransportMode.hybridAuto => _isWssTunnelOnline
          ? OrbitMessageDeliveryStatus.sentViaWss
          : OrbitMessageDeliveryStatus.sentViaImapBridge,
    };
  }

  String _formatTimeNow() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _seedInitialThreadsAndMessages() {
    _threads.addAll(const <OrbitChatThread>[
      OrbitChatThread(
        id: 'chat_saved',
        title: 'Избранное • ORBIT Vault',
        subtitleRole: 'Личное облако заметок, файлов и голосовых',
        folder: OrbitChatFolder.saved,
        avatarInitials: '★',
        peerEmail: 'architect@yandex.ru',
        isPinned: true,
      ),
      OrbitChatThread(
        id: 'chat_core_team',
        title: 'Команда релиза ORBIT 0.5.21',
        subtitleRole: 'Рабочая группа • Гибридный мост активен',
        folder: OrbitChatFolder.work,
        avatarInitials: 'OR',
        peerEmail: 'core-team@yandex.ru',
        isPinned: true,
        unreadCount: 2,
      ),
      OrbitChatThread(
        id: 'chat_elena_design',
        title: 'Елена Соколова • Design Lead',
        subtitleRole: 'visionOS Spatial UI & Шейдеры',
        folder: OrbitChatFolder.personal,
        avatarInitials: 'ЕС',
        peerEmail: 'elena.s@mail.ru',
        unreadCount: 1,
      ),
      OrbitChatThread(
        id: 'chat_orbit_digest',
        title: 'ORBIT Инженерия • Канал',
        subtitleRole: 'Обновления архитектуры ARM64 и Impeller',
        folder: OrbitChatFolder.channels,
        avatarInitials: '⚡',
        peerEmail: 'digest@orbit.ru',
      ),
    ]);

    _messagesByChat['chat_core_team'] = <OrbitChatMessage>[
      const OrbitChatMessage(
        id: 'm_core_1',
        chatId: 'chat_core_team',
        senderName: 'Алексей (Lead)',
        text:
            'Проверили сборку 0.5.20 на физическом Android ARM64: FAB теперь парит ровно над доком, фон единый на всех вкладках.',
        timestampIso: '11:20',
        isOutgoing: false,
        reactions: <String, int>{'🔥': 3, '👍': 2},
      ),
      const OrbitChatMessage(
        id: 'm_core_2',
        chatId: 'chat_core_team',
        senderName: 'Дмитрий (SecOps)',
        text:
            'Гибридный транспорт (WSS:443 + IMAP через Яндекс 360) пробивает любые сети в РФ без VPN. Задержка 22 мс.',
        timestampIso: '11:24',
        isOutgoing: false,
        deliveryStatus: OrbitMessageDeliveryStatus.sentViaImapBridge,
      ),
    ];

    _messagesByChat['chat_elena_design'] = <OrbitChatMessage>[
      const OrbitChatMessage(
        id: 'm_elena_1',
        chatId: 'chat_elena_design',
        senderName: 'Елена Соколова',
        text:
            'Иконки в Центре действий увеличили до 24px и отцентровали подписи — теперь пропорции идеальные. Поставим задачу на финальный прогон?',
        timestampIso: '10:45',
        isOutgoing: false,
      ),
    ];

    _messagesByChat['chat_saved'] = <OrbitChatMessage>[
      const OrbitChatMessage(
        id: 'm_saved_1',
        chatId: 'chat_saved',
        senderName: 'Вы',
        text:
            'Заметка: любое сообщение в чате можно перевести в Задачу или Встречу календаря одним нажатием.',
        timestampIso: '09:15',
        isOutgoing: true,
        deliveryStatus: OrbitMessageDeliveryStatus.sentViaWss,
      ),
    ];
  }
}

/// Глобальный контроллер мессенджера для бесшовной работы между экранами.
final OrbitHybridMessengerController orbitMessengerController =
    OrbitHybridMessengerController();