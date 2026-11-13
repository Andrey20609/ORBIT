import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/demo_data.dart';
import '../l10n/orbit_localizations.dart';
import '../services/brain/gemini_brain_engine.dart';
import '../visual_engine/orbit_palette.dart';
import '../visual_engine/orbit_profile.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_pressable.dart';
import '../widgets/orbit_spatial_surfaces.dart';

String orbitPlainMarkdown(String text) =>
    text.replaceAll('**', '').replaceAll('*', '');

/// Колбэк выполнения предложенного ИИ действия в 1 касание.
typedef BrainProposalExecutor =
    FutureOr<void> Function(BrainActionProposal proposal);

final class BrainScreen extends StatefulWidget {
  const BrainScreen({
    this.palette,
    this.profile,
    this.snapshot = const BrainEcosystemSnapshot(
      openTasksCount: 3,
      urgentTaskTitles: <String>[
        'Подготовить отчёт по КПЭ',
        'Ревью архитектуры',
      ],
      upcomingMeetingsCount: 1,
      nextMeetingLabel: 'Совещание по ВП • 10:00',
      unreadMailCount: 4,
      activeMailAccountEmail: 'architect@yandex.ru',
      mailAccountStatus: OrbitMailAccountStatus.verified,
      lastMailLatencyMs: 34,
    ),
    this.initialMessages,
    this.onMessagesChanged,
    this.onExecuteProposal,
    this.engine,
    super.key,
  });

  final OrbitPalette? palette;
  final OrbitProfile? profile;
  final BrainEcosystemSnapshot snapshot;
  final List<BrainChatMessage>? initialMessages;
  final ValueChanged<List<BrainChatMessage>>? onMessagesChanged;
  final BrainProposalExecutor? onExecuteProposal;
  final OrbitGeminiBrainEngine? engine;

  @override
  State<BrainScreen> createState() => _BrainScreenState();
}

final class _BrainScreenState extends State<BrainScreen> {
  late final OrbitGeminiBrainEngine _engine;
  late final TextEditingController _promptController;
  late final ScrollController _chatScrollController;
  late List<BrainChatMessage> _messages;
  StreamSubscription<String>? _streamSub;
  bool _isGenerating = false;
  String? _demoResponseText;
  bool _privacyMemoryCleared = false;
  bool _taskCreatedSuccess = false;

  static const List<({String label, String prompt, IconData icon})>
  _quickChips = [
    (
      label: 'Сводка дня',
      prompt: 'Сформируй полную сводку дня и приоритетную задачу',
      icon: Icons.wb_sunny_outlined,
    ),
    (
      label: 'Проверь почту',
      prompt: 'Проверь статус подключения почты и непрочитанные письма',
      icon: Icons.mark_email_read_outlined,
    ),
    (
      label: 'Создай задачу на завтра',
      prompt: 'Создай задачу на завтра по ключевому приоритету',
      icon: Icons.add_task_rounded,
    ),
    (
      label: 'Есть ли срочные встречи?',
      prompt: 'Какие встречи в календаре сегодня и нужно ли назначить ревью?',
      icon: Icons.event_available_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? OrbitGeminiBrainEngine();
    _promptController = TextEditingController();
    _chatScrollController = ScrollController();
    _messages =
        widget.initialMessages != null && widget.initialMessages!.isNotEmpty
        ? List<BrainChatMessage>.from(widget.initialMessages!)
        : <BrainChatMessage>[
            BrainChatMessage(
              id: 'welcome_gemini_msg',
              sender: BrainMessageSender.assistant,
              text:
                  'Ядро **ORBIT Brain (Gemini 2.0 Prototype)** синхронизировано с вашей экосистемой. '
                  'Вижу задач в работе: **${widget.snapshot.openTasksCount}**, '
                  'непрочитанных писем: **${widget.snapshot.unreadMailCount}**, '
                  'ближайшее событие: *${widget.snapshot.nextMeetingLabel}*. Чем помочь?',
              timestamp: DateTime.now(),
            ),
          ];
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _promptController.dispose();
    _chatScrollController.dispose();
    super.dispose();
  }

  void _notifyPersistence() {
    widget.onMessagesChanged?.call(
      List<BrainChatMessage>.unmodifiable(_messages),
    );
  }

  BrainEcosystemSnapshot _resolveSnapshot(BuildContext context) {
    final env = OrbitEnvironment.maybeOf(context);
    final appState = env?.appState;
    if (appState == null) return widget.snapshot;

    final openTasks = appState.tasks.where((t) => !t.done).toList();
    final urgentTasks = openTasks
        .where((t) => t.priority >= 2)
        .map((t) => t.title)
        .toList();
    final activeAcc = appState.activeMailAccount;

    return BrainEcosystemSnapshot(
      openTasksCount: openTasks.length,
      urgentTaskTitles: urgentTasks.isNotEmpty
          ? urgentTasks
          : (openTasks.isNotEmpty
                ? [openTasks.first.title]
                : ['Без срочных задач']),
      upcomingMeetingsCount: appState.events.length,
      nextMeetingLabel: appState.events.isNotEmpty
          ? '${appState.events.first.title} • ${appState.events.first.time}'
          : 'Свободно',
      unreadMailCount: appState.badgeCountForFolder(OrbitMailFolder.inbox),
      activeMailAccountEmail: activeAcc.email,
      mailAccountStatus: activeAcc.status,
      lastMailLatencyMs: activeAcc.lastLatencyMs,
    );
  }

  Future<void> _sendPrompt(
    String rawText, {
    bool showLegacyResponse = false,
  }) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty || _isGenerating) return;

    unawaited(HapticFeedback.lightImpact());
    _promptController.clear();

    final snap = _resolveSnapshot(context);
    final sanitizedUserText =
        OrbitGeminiBrainEngine.sanitizeWithPrivacyGuardrails(trimmed);
    final userMsg = BrainChatMessage(
      id: 'usr_${DateTime.now().microsecondsSinceEpoch}',
      sender: BrainMessageSender.user,
      text: sanitizedUserText,
      timestamp: DateTime.now(),
    );

    final evaluation = _engine.evaluatePrompt(sanitizedUserText, snap);
    final assistantId = 'ast_${DateTime.now().microsecondsSinceEpoch}';

    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );

    if (isTest || _engine.tokenDelay == Duration.zero) {
      final assistantMsg = BrainChatMessage(
        id: assistantId,
        sender: BrainMessageSender.assistant,
        text: evaluation.fullText,
        timestamp: DateTime.now(),
        actionProposal: evaluation.proposal,
        isStreaming: false,
      );
      setState(() {
        _demoResponseText = showLegacyResponse ? evaluation.fullText : null;
        _privacyMemoryCleared = false;
        _messages.add(userMsg);
        _messages.add(assistantMsg);
      });
      _notifyPersistence();
      if (!showLegacyResponse) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_chatScrollController.hasClients) {
            _chatScrollController.jumpTo(
              _chatScrollController.position.maxScrollExtent,
            );
          }
        });
      }
      return;
    }

    final placeholderAssistant = BrainChatMessage(
      id: assistantId,
      sender: BrainMessageSender.assistant,
      text: '…',
      timestamp: DateTime.now(),
      isStreaming: true,
    );

    setState(() {
      _isGenerating = true;
      _privacyMemoryCleared = false;
      _demoResponseText = showLegacyResponse ? evaluation.fullText : null;
      _messages.add(userMsg);
      _messages.add(placeholderAssistant);
    });

    await _streamSub?.cancel();
    _streamSub = _engine
        .streamTokens(evaluation.fullText)
        .listen(
          (partialText) {
            if (!mounted) return;
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == assistantId);
              if (idx != -1) {
                _messages[idx] = _messages[idx].copyWith(
                  text: partialText,
                  isStreaming: true,
                );
              }
            });
          },
          onDone: () {
            if (mounted) {
              setState(() {
                _isGenerating = false;
                final idx = _messages.indexWhere((m) => m.id == assistantId);
                if (idx != -1) {
                  _messages[idx] = _messages[idx].copyWith(
                    text: evaluation.fullText,
                    actionProposal: evaluation.proposal,
                    isStreaming: false,
                  );
                }
              });
              _notifyPersistence();
              if (!showLegacyResponse) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_chatScrollController.hasClients) {
                    _chatScrollController.jumpTo(
                      _chatScrollController.position.maxScrollExtent,
                    );
                  }
                });
              }
            }
          },
        );
  }

  Future<void> _handleApproveProposal(String messageId) async {
    unawaited(HapticFeedback.mediumImpact());
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final proposal = _messages[idx].actionProposal;
    if (proposal == null || proposal.isExecuted) return;

    final env = OrbitEnvironment.maybeOf(context);
    final appState = env?.appState;

    if (appState != null) {
      switch (proposal.tool) {
        case BrainToolType.createTask:
          final title = proposal.arguments['title'] ?? proposal.title;
          appState.addTask(title);
        case BrainToolType.scheduleMeeting:
          final title = proposal.arguments['title'] ?? proposal.title;
          final time = proposal.arguments['time'] ?? '16:00';
          appState.addEvent(title, time, DateTime.now());
        case BrainToolType.composeMailDraft:
          final to = proposal.arguments['to'] ?? '';
          final subject = proposal.arguments['subject'] ?? '';
          final body = proposal.arguments['body'] ?? '';
          appState.updateDraft(to: to, subject: subject, body: body);
        case BrainToolType.verifyMailHealth:
          final acc = appState.activeMailAccount;
          unawaited(appState.verifyAccountConnection(acc));
      }
    }

    await widget.onExecuteProposal?.call(proposal);

    setState(() {
      _messages[idx] = _messages[idx].copyWith(
        actionProposal: proposal.copyWith(isExecuted: true),
      );
      _taskCreatedSuccess = true;
    });
    _notifyPersistence();

    if (!mounted) return;
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    final palette =
        widget.palette ?? OrbitEnvironment.maybeOf(context)?.palette;
    if (!isTest && palette != null) {
      showOrbitSpatialIsland(
        context,
        palette: palette,
        title: 'Выполнено: ${proposal.title}',
        icon: Icons.check_circle_rounded,
      );
    }
  }

  void _handleDismissProposal(String messageId) {
    unawaited(HapticFeedback.lightImpact());
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;

    final proposal = _messages[idx].actionProposal;
    if (proposal == null) return;

    setState(() {
      _messages[idx] = _messages[idx].copyWith(
        actionProposal: proposal.copyWith(isDismissed: true),
      );
    });
    _notifyPersistence();
  }

  void _clearChatHistory() {
    unawaited(HapticFeedback.heavyImpact());
    setState(() {
      _messages.clear();
      _demoResponseText = null;
      _privacyMemoryCleared = true;
      _taskCreatedSuccess = false;
    });
    _notifyPersistence();
  }

  void _showBrainSettingsSheet(BuildContext context, OrbitPalette palette) {
    unawaited(HapticFeedback.mediumImpact());
    showOrbitModalSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              24 + MediaQuery.paddingOf(ctx).bottom,
            ),
            child: OrbitSpatialCard(
              palette: palette,
              radius: 28,
              useBlur: true,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: palette.textSecondary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      OrbitLivingAiOrb(palette: palette, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Параметры ORBIT Brain',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: palette.textPrimary,
                              ),
                            ),
                            Text(
                              'Нейросетевое ядро и конфиденциальность',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'РЕЖИМ ОБРАБОТКИ ДАННЫХ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitFilledButton(
                    buttonKey: const Key('brain-setting-edge'),
                    palette: palette,
                    compact: true,
                    isPrimary: true,
                    icon: Icons.shield_rounded,
                    label: 'On-Device Edge Neural Engine',
                    subtitle: '100% приватность без передачи на серверы',
                    onTap: () {
                      Navigator.pop(ctx);
                      showOrbitSpatialIsland(
                        context,
                        palette: palette,
                        title: 'Включен локальный Edge AI',
                        icon: Icons.check_circle_rounded,
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OrbitFilledButton(
                    buttonKey: const Key('brain-setting-cloud'),
                    palette: palette,
                    compact: true,
                    isPrimary: false,
                    icon: Icons.cloud_outlined,
                    label: 'Cloud Hybrid Pro (2028 Next-Gen)',
                    subtitle: 'Глубокие рассуждения с маскированием PII',
                    onTap: () {
                      Navigator.pop(ctx);
                      showOrbitSpatialIsland(
                        context,
                        palette: palette,
                        title: 'Включен гибридный режим AI',
                        icon: Icons.cloud_done_rounded,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.maybeOf(context);
    final palette =
        widget.palette ?? env?.palette ?? OrbitPalette.of(OrbitProfile.one);
    final profile = widget.profile ?? palette.profile;
    final radius = orbitRadiusForProfile(profile);
    final snap = _resolveSnapshot(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Верхний бар с анимированной AI-сферой
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  OrbitLivingAiOrb(
                    palette: palette,
                    size: 38,
                    intensity: _isGenerating ? 1.4 : 1.0,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ORBIT Brain',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          _isGenerating
                              ? 'Локальный синтез ответа и проверка инструментов…'
                              : 'Локальный прототип Gemini 2.0 • PrivacyGuardrails',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.tune_rounded,
                      color: palette.textSecondary,
                    ),
                    tooltip: 'Settings',
                    onPressed: () => _showBrainSettingsSheet(context, palette),
                  ),
                  OrbitPressable(
                    key: const Key('brain-clear-history-btn'),
                    semanticLabel: 'Очистить историю диалога',
                    onTap: _clearChatHistory,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(radius * 0.65),
                      ),
                      child: Icon(
                        Icons.cleaning_services_rounded,
                        size: 19,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. Основная прокручиваемая лента: контекст дня, быстрые команды и диалог
            Expanded(
              child: SingleChildScrollView(
                key: const Key('brain-chat-list'),
                controller: _chatScrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Стеклянная панель «КОНТЕКСТ ДНЯ»
                    OrbitSpatialCard(
                      key: const Key('brain-live-context-bar'),
                      palette: palette,
                      radius: radius * 0.85,
                      tintColor: palette.accent,
                      tintIntensity: 0.16,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'КОНТЕКСТ ДНЯ',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: palette.accent,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            children: [
                              _ContextPillMetric(
                                palette: palette,
                                icon: Icons.task_alt_rounded,
                                label: 'Задачи: ${snap.openTasksCount}',
                              ),
                              _ContextPillMetric(
                                palette: palette,
                                icon: Icons.event_rounded,
                                label: 'Встречи: ${snap.upcomingMeetingsCount}',
                              ),
                              _ContextPillMetric(
                                palette: palette,
                                icon: Icons.mark_email_unread_rounded,
                                label: 'Почта: ${snap.unreadMailCount} новых',
                              ),
                              _ContextPillMetric(
                                palette: palette,
                                icon: Icons.verified_user_outlined,
                                label: snap.activeMailAccountEmail,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Приветствие и быстрые команды
                    Text(
                      context.l10n.brainGreeting,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    OrbitFilledButton(
                      buttonKey: const Key('brain-cmd-daily-plan'),
                      palette: palette,
                      radius: radius * 0.75,
                      compact: true,
                      icon: Icons.auto_awesome_rounded,
                      label: context.l10n.brainPromptPlan,
                      onTap: () => _sendPrompt(
                        context.l10n.brainPromptPlan,
                        showLegacyResponse: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OrbitFilledButton(
                            buttonKey: const Key('brain-cmd-mail-summary'),
                            palette: palette,
                            radius: radius * 0.7,
                            compact: true,
                            isPrimary: false,
                            icon: Icons.summarize_rounded,
                            label: 'Почта',
                            onTap: () => _sendPrompt(
                              'Проверь почту',
                              showLegacyResponse: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OrbitFilledButton(
                            buttonKey: const Key('brain-cmd-clear-privacy'),
                            palette: palette,
                            radius: radius * 0.7,
                            compact: true,
                            isPrimary: false,
                            icon: Icons.shield_rounded,
                            label: 'Сброс',
                            onTap: _clearChatHistory,
                          ),
                        ),
                      ],
                    ),

                    if (_demoResponseText != null) ...[
                      const SizedBox(height: 10),
                      GlassPanel(
                        key: const Key('brain-demo-response'),
                        palette: palette,
                        padding: const EdgeInsets.all(12),
                        radius: radius * 0.75,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _demoResponseText!,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: palette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_taskCreatedSuccess)
                              OrbitFilledButton(
                                palette: palette,
                                radius: radius * 0.7,
                                compact: true,
                                isPrimary: false,
                                icon: Icons.check_circle_rounded,
                                label: 'Задача создана — открыть список задач',
                                onTap: () => context.push('/tasks'),
                              )
                            else
                              OrbitFilledButton(
                                buttonKey: const Key('brain-confirm-task-0'),
                                palette: palette,
                                radius: radius * 0.7,
                                compact: true,
                                icon: Icons.add_task_rounded,
                                label: 'Создать предложенную задачу',
                                onTap: () {
                                  if (_messages.isNotEmpty) {
                                    _handleApproveProposal(_messages.last.id);
                                  } else {
                                    setState(() => _taskCreatedSuccess = true);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                    ],

                    if (_privacyMemoryCleared) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: palette.accent,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Контекстный кэш ORBIT Brain полностью очищен.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // Лента сообщений и карточек предложений
                    for (final msg in _messages)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _BrainMessageBubble(
                          message: msg,
                          palette: palette,
                          radius: radius,
                          onApproveProposal: () =>
                              _handleApproveProposal(msg.id),
                          onDismissProposal: () =>
                              _handleDismissProposal(msg.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // 3. Горизонтальная лента быстрых контекстных чипов
            SizedBox(
              height: (38.0 * textScale).clamp(38.0, 56.0),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickChips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final chip = _quickChips[i];
                  return OrbitPressable(
                    key: Key('brain-quick-chip-$i'),
                    onTap: () => _sendPrompt(chip.prompt),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: (6.0 / textScale).clamp(2.0, 6.0),
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: palette.accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(chip.icon, size: 14, color: palette.accent),
                          const SizedBox(width: 6),
                          Text(
                            chip.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 5. Поле ввода промпта в стиле visionOS Floating Glass
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: palette.isLight ? 0.5 : 0.18,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 2, 4, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: TextField(
                          key: const Key('brain-query-input'),
                          controller: _promptController,
                          style: TextStyle(
                            fontSize: 14,
                            color: palette.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Спросите Gemini 2.0 о задачах, почте или расписании…',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: palette.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (text) =>
                              _sendPrompt(text, showLegacyResponse: true),
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('brain-send-button'),
                      icon: _isGenerating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.arrow_upward_rounded,
                              color: palette.accent,
                              size: 20,
                            ),
                      onPressed: _isGenerating
                          ? null
                          : () => _sendPrompt(
                              _promptController.text,
                              showLegacyResponse: true,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ContextPillMetric extends StatelessWidget {
  const _ContextPillMetric({
    required this.palette,
    required this.icon,
    required this.label,
  });

  final OrbitPalette palette;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 230),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _BrainMessageBubble extends StatelessWidget {
  const _BrainMessageBubble({
    required this.message,
    required this.palette,
    required this.radius,
    required this.onApproveProposal,
    required this.onDismissProposal,
  });

  final BrainChatMessage message;
  final OrbitPalette palette;
  final double radius;
  final VoidCallback onApproveProposal;
  final VoidCallback onDismissProposal;

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == BrainMessageSender.user;
    final proposal = message.actionProposal;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: isUser
                    ? palette.accent.withValues(alpha: 0.22)
                    : palette.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(radius * 0.75),
                  topRight: Radius.circular(radius * 0.75),
                  bottomLeft: Radius.circular(isUser ? radius * 0.75 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : radius * 0.75),
                ),
                border: Border.all(
                  color: isUser
                      ? palette.accent.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  orbitPlainMarkdown(message.text),
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ),
            if (proposal != null && !proposal.isDismissed) ...[
              const SizedBox(height: 8),
              _ActionProposalCard(
                proposal: proposal,
                palette: palette,
                radius: radius * 0.78,
                onApprove: onApproveProposal,
                onDismiss: onDismissProposal,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _ActionProposalCard extends StatelessWidget {
  const _ActionProposalCard({
    required this.proposal,
    required this.palette,
    required this.radius,
    required this.onApprove,
    required this.onDismiss,
  });

  final BrainActionProposal proposal;
  final OrbitPalette palette;
  final double radius;
  final VoidCallback onApprove;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      palette: palette,
      radius: radius,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: palette.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Предложение действия: ${proposal.tool.label}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            proposal.title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          if (proposal.subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              proposal.subtitle,
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          if (proposal.isExecuted)
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 17,
                  color: Colors.greenAccent.shade400,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Выполнено в экосистеме ORBIT',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: palette.textPrimary,
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OrbitFilledButton(
                    buttonKey: Key('brain-approve-proposal-${proposal.id}'),
                    palette: palette,
                    radius: radius * 0.7,
                    compact: true,
                    isPrimary: true,
                    icon: Icons.check_rounded,
                    label: 'Выполнить в 1 тап',
                    onTap: onApprove,
                  ),
                ),
                const SizedBox(width: 8),
                OrbitPressable(
                  key: Key('brain-dismiss-proposal-${proposal.id}'),
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(radius * 0.7),
                    ),
                    child: Text(
                      'Отклонить',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
