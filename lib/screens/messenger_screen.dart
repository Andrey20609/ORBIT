import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/messenger/orbit_hybrid_messenger_engine.dart';
import '../theme/orbit_palette.dart';
import '../theme/orbit_profile.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_pressable.dart';
import '../widgets/orbit_spatial_surfaces.dart';

/// Колбэк создания Задачи или Встречи напрямую из сообщения мессенджера.
typedef MessengerCrossActionCallback =
    void Function(
      OrbitChatMessage message,
      String actionType, // 'task' | 'meeting'
    );

final class MessengerScreen extends StatefulWidget {
  const MessengerScreen({
    required this.palette,
    required this.profile,
    this.controller,
    this.onConvertMessageToEntity,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final OrbitHybridMessengerController? controller;
  final MessengerCrossActionCallback? onConvertMessageToEntity;

  @override
  State<MessengerScreen> createState() => _MessengerScreenState();
}

final class _MessengerScreenState extends State<MessengerScreen> {
  late final OrbitHybridMessengerController _controller;
  OrbitChatThread? _activeThread;
  OrbitChatMessage? _replyingTo;
  late final TextEditingController _messageInputController;

  double get _radius => orbitRadiusForProfile(widget.profile);

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? orbitMessengerController;
    _messageInputController = TextEditingController();
  }

  @override
  void dispose() {
    _messageInputController.dispose();
    super.dispose();
  }

  void _openThread(OrbitChatThread thread) {
    HapticFeedback.lightImpact();
    _controller.markChatAsRead(thread.id);
    setState(() {
      _activeThread = thread;
      _replyingTo = null;
    });
  }

  Future<void> _handleSendText() async {
    final thread = _activeThread;
    final text = _messageInputController.text.trim();
    if (thread == null || text.isEmpty) return;

    await HapticFeedback.lightImpact();
    final reply = _replyingTo;
    _messageInputController.clear();
    setState(() => _replyingTo = null);

    await _controller.sendTextMessage(
      chatId: thread.id,
      text: text,
      replyToMessageId: reply?.id,
      replyPreviewText: reply?.text,
    );
  }

  Future<void> _handleSendVoice() async {
    final thread = _activeThread;
    if (thread == null) return;
    await HapticFeedback.mediumImpact();
    await _controller.sendVoiceMessage(chatId: thread.id);
  }

  void _handleConvertToEntity(OrbitChatMessage msg, String type) {
    final thread = _activeThread;
    if (thread == null) return;
    HapticFeedback.mediumImpact();

    final entityId = '${type}_${DateTime.now().millisecondsSinceEpoch}';
    _controller.attachCrossEntityToMessage(
      chatId: thread.id,
      messageId: msg.id,
      taskId: type == 'task' ? entityId : null,
      meetingId: type == 'meeting' ? entityId : null,
    );
    widget.onConvertMessageToEntity?.call(msg, type);

    showOrbitSpatialIsland(
      context,
      palette: widget.palette,
      title: type == 'task'
          ? 'Создана задача из сообщения: «${msg.text}»'
          : 'Назначена встреча из чата: «${msg.text}»',
      icon: type == 'task'
          ? Icons.task_alt_rounded
          : Icons.calendar_month_rounded,
    );
  }

  void _showTransportSelectorSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final palette = widget.palette;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: OrbitSpatialCard(
              palette: palette,
              radius: _radius + 6,
              useBlur: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Гибридный транспорт (Демо-прототип без VPN)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Локальная демонстрационная симуляция протоколов доставки (прямой WSS:443 / IMAP-Мост).',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final mode in OrbitMessengerTransportMode.values) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OrbitFilledButton(
                        buttonKey: Key('messenger-transport-mode-${mode.name}'),
                        palette: palette,
                        radius: _radius * 0.8,
                        isPrimary: _controller.transportMode == mode,
                        icon:
                            mode == OrbitMessengerTransportMode.imapDeltaBridge
                            ? Icons.alternate_email_rounded
                            : Icons.bolt_rounded,
                        label: mode.label,
                        subtitle: mode.description,
                        onTap: () {
                          _controller.setTransportMode(mode);
                          Navigator.of(sheetCtx, rootNavigator: true).pop();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: _activeThread == null
                ? _buildThreadsOverview(context)
                : _buildActiveChatConversation(context, _activeThread!),
          ),
        );
      },
    );
  }

  /// Экран 1: Список чатов, каналов и папок в стиле Telegram.
  Widget _buildThreadsOverview(BuildContext context) {
    final palette = widget.palette;
    final threads = _controller.visibleThreads;
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Шапка мессенджера с индикатором антиблокировочного транспорта
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ORBIT Чаты (Edge Прототип)',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _controller.activeTransportBadge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
              ),
              OrbitFilledButton(
                buttonKey: const Key('messenger-transport-selector-btn'),
                palette: palette,
                radius: _radius * 0.72,
                compact: true,
                isPrimary: false,
                icon: Icons.router_rounded,
                label: 'Транспорт',
                onTap: _showTransportSelectorSheet,
              ),
            ],
          ),
        ),

        // Горизонтальная лента папок Telegram (Все, Личные, Рабочие, Каналы, Избранное)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              for (final folder in OrbitChatFolder.values) ...[
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: OrbitPressable(
                    key: Key('chat-folder-tab-${folder.name}'),
                    semanticLabel: folder.label,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _controller.selectFolder(folder);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: _controller.selectedFolder == folder
                            ? LinearGradient(
                                colors: [
                                  palette.accent,
                                  palette.accentSecondary,
                                ],
                              )
                            : null,
                        color: _controller.selectedFolder == folder
                            ? null
                            : palette.surface.withValues(alpha: 0.72),
                        border: Border.all(
                          color: _controller.selectedFolder == folder
                              ? Colors.white.withValues(alpha: 0.35)
                              : palette.textSecondary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        folder.label,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _controller.selectedFolder == folder
                              ? Colors.white
                              : palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Список чатов
        Expanded(
          child: ListView.builder(
            key: const Key('messenger-threads-list'),
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16, 8, 16, 124 + bottomSafe),
            itemCount: threads.length,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final lastMsg = _controller.lastMessageForChat(thread.id);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OrbitPressable(
                  key: Key('chat-thread-tile-${thread.id}'),
                  semanticLabel: '${thread.title}. ${thread.subtitleRole}',
                  onTap: () => _openThread(thread),
                  child: OrbitSpatialCard(
                    palette: palette,
                    radius: _radius * 0.9,
                    tintColor: thread.unreadCount > 0 ? palette.accent : null,
                    tintIntensity: thread.unreadCount > 0 ? 0.18 : 0.08,
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    palette.accent,
                                    palette.accentSecondary,
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                thread.avatarInitials,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (thread.isOnline)
                              Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.shade400,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: palette.surface,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (thread.isPinned) ...[
                                    Icon(
                                      Icons.push_pin_rounded,
                                      size: 14,
                                      color: palette.accent,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      thread.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: palette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (lastMsg != null)
                                    Text(
                                      lastMsg.timestampIso,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lastMsg != null
                                          ? '${lastMsg.senderName}: ${lastMsg.text}'
                                          : thread.subtitleRole,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (thread.unreadCount > 0) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: palette.accent,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                      child: Text(
                                        '${thread.unreadCount}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Экран 2: Внутри конкретного диалога (Telegram-лента + перевод сообщений в Задачи/Встречи).
  Widget _buildActiveChatConversation(
    BuildContext context,
    OrbitChatThread thread,
  ) {
    final palette = widget.palette;
    final messages = _controller.messagesForChat(thread.id);
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Верхняя панель открытого чата
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: [
              OrbitPressable(
                key: const Key('chat-back-to-threads-btn'),
                semanticLabel: 'Назад к списку чатов',
                onTap: () => setState(() => _activeThread = null),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(_radius * 0.65),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      'Мост: ${thread.peerEmail} • ${_controller.transportMode.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Лента сообщений
        Expanded(
          child: ListView.builder(
            key: const Key('chat-messages-list'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final msg = messages[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ChatMessageBubble(
                  message: msg,
                  palette: palette,
                  radius: _radius,
                  onReply: () => setState(() => _replyingTo = msg),
                  onReaction: (emoji) => _controller.toggleReaction(
                    chatId: thread.id,
                    messageId: msg.id,
                    emoji: emoji,
                  ),
                  onConvertToTask: () => _handleConvertToEntity(msg, 'task'),
                  onConvertToMeeting: () =>
                      _handleConvertToEntity(msg, 'meeting'),
                ),
              );
            },
          ),
        ),

        // Превью ответа (Reply banner), если выбрано сообщение
        if (_replyingTo != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GlassPanel(
              palette: palette,
              radius: _radius * 0.65,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded, size: 16, color: palette.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ответ ${_replyingTo!.senderName}: ${_replyingTo!.text}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  OrbitPressable(
                    semanticLabel: 'Отменить ответ',
                    onTap: () => setState(() => _replyingTo = null),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Поле ввода сообщения + кнопка голосового сообщения (защищено от перекрытия снизу!)
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomSafe),
          child: Row(
            children: [
              OrbitPressable(
                key: const Key('chat-send-voice-btn'),
                semanticLabel: 'Записать голосовое сообщение',
                onTap: _handleSendVoice,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(_radius * 0.75),
                    border: Border.all(
                      color: palette.accent.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.mic_rounded,
                    color: palette.accent,
                    size: 21,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassPanel(
                  palette: palette,
                  radius: _radius * 0.8,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  child: TextField(
                    key: const Key('chat-message-input'),
                    controller: _messageInputController,
                    onSubmitted: (_) => _handleSendText(),
                    style: TextStyle(fontSize: 14, color: palette.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Сообщение (WSS / IMAP без VPN)…',
                      hintStyle: TextStyle(color: palette.textSecondary),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OrbitFilledButton(
                buttonKey: const Key('chat-send-text-btn'),
                palette: palette,
                radius: _radius * 0.75,
                compact: true,
                icon: Icons.send_rounded,
                label: 'Отпр.',
                onTap: _handleSendText,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.palette,
    required this.radius,
    required this.onReply,
    required this.onReaction,
    required this.onConvertToTask,
    required this.onConvertToMeeting,
  });

  final OrbitChatMessage message;
  final OrbitPalette palette;
  final double radius;
  final VoidCallback onReply;
  final ValueChanged<String> onReaction;
  final VoidCallback onConvertToTask;
  final VoidCallback onConvertToMeeting;

  @override
  Widget build(BuildContext context) {
    final isOut = message.isOutgoing;
    final transportTag = switch (message.deliveryStatus) {
      OrbitMessageDeliveryStatus.sentViaImapBridge => 'IMAP-Bridge',
      OrbitMessageDeliveryStatus.sentViaWss => 'WSS:443',
      OrbitMessageDeliveryStatus.queuedOffline => 'В очереди',
      _ => 'Доставлено',
    };

    return Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: OrbitSpatialCard(
        palette: palette,
        radius: radius * 0.88,
        tintColor: isOut ? palette.accent : palette.accentSecondary,
        tintIntensity: isOut ? 0.24 : 0.10,
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    message.senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isOut ? palette.accent : palette.accentSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${message.timestampIso} • $transportTag',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
            if (message.replyPreviewText != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: palette.accent, width: 2.5),
                  ),
                ),
                child: Text(
                  message.replyPreviewText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            if (message.isVoiceMessage)
              _VoiceWaveformBar(
                palette: palette,
                waveform: message.voiceWaveform,
                durationSec: message.voiceDurationSec ?? 7,
              )
            else
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.38,
                  color: palette.textPrimary,
                ),
              ),

            // Отображение активных реакций и быстрые кнопки экосистемы
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final entry in message.reactions.entries)
                  OrbitPressable(
                    semanticLabel: 'Реакция ${entry.key}',
                    onTap: () => onReaction(entry.key),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${entry.key} ${entry.value}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                _MiniBubbleActionChip(
                  palette: palette,
                  icon: Icons.favorite_border_rounded,
                  label: '🔥',
                  onTap: () => onReaction('🔥'),
                ),
                _MiniBubbleActionChip(
                  palette: palette,
                  icon: Icons.reply_rounded,
                  label: 'Ответить',
                  onTap: onReply,
                ),
                _MiniBubbleActionChip(
                  chipKey: Key('msg-to-task-${message.id}'),
                  palette: palette,
                  icon: Icons.add_task_rounded,
                  label: message.linkedTaskId != null ? '✓ Задача' : 'В задачу',
                  onTap: onConvertToTask,
                ),
                _MiniBubbleActionChip(
                  chipKey: Key('msg-to-meeting-${message.id}'),
                  palette: palette,
                  icon: Icons.event_available_rounded,
                  label: message.linkedMeetingId != null
                      ? '✓ Встреча'
                      : 'В календарь',
                  onTap: onConvertToMeeting,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _VoiceWaveformBar extends StatelessWidget {
  const _VoiceWaveformBar({
    required this.palette,
    required this.waveform,
    required this.durationSec,
  });

  final OrbitPalette palette;
  final List<double> waveform;
  final int durationSec;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: palette.accent,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 24,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final amp in waveform)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: Container(
                    width: 3,
                    height: (22 * amp).clamp(4.0, 22.0),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '0:${durationSec.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

final class _MiniBubbleActionChip extends StatelessWidget {
  const _MiniBubbleActionChip({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.chipKey,
  });

  final OrbitPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Key? chipKey;

  @override
  Widget build(BuildContext context) {
    return OrbitPressable(
      key: chipKey,
      semanticLabel: label,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: palette.textSecondary.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: palette.accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
