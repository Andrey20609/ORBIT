import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mail/mail_connection_verifier.dart';
import '../services/mail/mail_models.dart';
import '../services/mail/smtp_outbox_store.dart';
import '../state/app_state.dart';
import '../visual_engine/orbit_visual_engine.dart';
import 'glass_panel.dart';
import 'orbit_environment.dart';
import 'orbit_mail_account_sheet.dart';
import 'orbit_spatial_surfaces.dart';

/// MAIL-02A: настоящий read-only INBOX. Отдельная секция от DEMO-писем.
/// Свёрнута по умолчанию (компактная строка) — инbox-экран не раздвигает
/// существующий layout/goldens; по тапу раскрывается: для каждого не-демо
/// аккаунта — карточка со статусом credential, кнопкой синхронизации
/// (EXAMINE + BODY.PEEK, максимум 20 писем, metadata-only) и списком
/// реальных писем. Только просмотр: ответить/удалить/отметить прочтённым
/// для реальных писем невозможно — мутации сервера отсутствуют в
/// транспорте по построению, локальные мутации тоже не выполняются.
/// Тела/HTML/вложения не загружаются и не показываются.
class OrbitRealInboxPanel extends StatefulWidget {
  const OrbitRealInboxPanel({super.key});

  @override
  State<OrbitRealInboxPanel> createState() => _OrbitRealInboxPanelState();
}

class _OrbitRealInboxPanelState extends State<OrbitRealInboxPanel> {
  bool _refreshRequested = false;
  bool _expanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_refreshRequested) {
      _refreshRequested = true;
      final state = OrbitEnvironment.of(context).appState;
      unawaited(state.refreshUserInboxEntries());
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final state = env.appState;

    return GlassPanel(
      palette: palette,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('real-inbox-toggle'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: palette.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Реальный ящик — только чтение (IMAP)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(height: 6),
            Text(
              'Metadata: отправитель, тема, краткий фрагмент. Тела, HTML и '
              'вложения не загружаются; флаги на сервере не меняются '
              '(EXAMINE + BODY.PEEK).',
              style: TextStyle(fontSize: 12, color: palette.textSecondary),
            ),
            const SizedBox(height: 10),
            ..._accountCards(state, palette),
          ],
        ],
      ),
    );
  }

  List<Widget> _accountCards(OrbitAppState state, OrbitPalette palette) {
    final realAccounts = state.mailAccounts.where((a) => !a.isDemo).toList();
    if (realAccounts.isEmpty) {
      return [
        Text(
          'Нет настроенных реальных аккаунтов. Добавьте аккаунт в разделе '
          '«Аккаунты».',
          style: TextStyle(fontSize: 12, color: palette.textSecondary),
        ),
      ];
    }
    final cards = <Widget>[];
    for (var index = 0; index < realAccounts.length; index++) {
      final account = realAccounts[index];
      final entries = state.userInboxEntries
          .where((e) => e.accountId == account.id)
          .toList();
      cards.add(_RealAccountCard(account: account, entries: entries));
      if (index < realAccounts.length - 1) {
        cards.add(const SizedBox(height: 10));
      }
    }
    return cards;
  }
}

class _RealAccountCard extends StatelessWidget {
  const _RealAccountCard({required this.account, required this.entries});

  final OrbitMailAccount account;
  final List<UserInboxEntry> entries;

  String _statusLabel(OrbitMailCredentialStatus status) => switch (status) {
    OrbitMailCredentialStatus.verified => 'Аутентифицировано',
    OrbitMailCredentialStatus.savedUnverified => 'Сохранено, не проверено',
    OrbitMailCredentialStatus.notConfigured => 'Пароль не настроен',
  };

  String _timeLabel(DateTime utc) {
    final local = utc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '${local.day}.${local.month} $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final state = env.appState;
    final syncing = state.isRealInboxSyncing;
    final disabled =
        syncing ||
        account.credentialStatus == OrbitMailCredentialStatus.notConfigured;
    return OrbitSpatialCard(
      palette: palette,
      radius: 16,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${account.name} · ${account.email}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      account.credentialStatus ==
                          OrbitMailCredentialStatus.verified
                      ? Colors.green.withValues(alpha: 0.18)
                      : palette.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel(account.credentialStatus),
                  style: TextStyle(fontSize: 11, color: palette.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // MAIL-02B r3 (UI-2): Wrap вместо Row - на узких экранах
          // элементы переносятся на следующую строку без обрезки.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: Key('real-inbox-sync-${account.id}'),
                onPressed: disabled
                    ? null
                    : () => unawaited(state.syncRealInbox(account.id)),
                icon: syncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: const Text(
                  'Загрузить INBOX (только чтение)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 2),
              Text(
                'Только чтение',
                style: TextStyle(fontSize: 11, color: palette.textSecondary),
              ),
            ],
          ),
          // MAIL-02B r3 (UX-3): после auth-rejection (notConfigured) у
          // пользователя остаётся явное действие - настроить пароль.
          if (account.credentialStatus ==
              OrbitMailCredentialStatus.notConfigured)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: Key('configure-credentials-${account.id}'),
                onPressed: () => unawaited(
                  _openAccountSettings(context, state, palette),
                ),
                icon: const Icon(Icons.key_rounded, size: 16),
                label: const Text(
                  'Настроить пароль / войти',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          // MAIL-02B: контролируемая SMTP-отправка (один разрешённый
          // получатель из конфигурации; персистентный outbox с retry).
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton.icon(
                key: Key('smtp-send-${account.id}'),
                onPressed: () =>
                    unawaited(showSmtpSendSheet(context, state, account)),
                icon: const Icon(Icons.forward_to_inbox_rounded, size: 16),
                label: const Text(
                  'SMTP: контрольная отправка',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              Text(
                _outboxSummary(state.smtpOutboxEntries, account.id),
                style: TextStyle(
                  fontSize: 11,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          if (state.lastRealInboxSyncError != null) ...[
            const SizedBox(height: 4),
            Text(
              state.lastRealInboxSyncError!,
              key: const Key('real-inbox-error'),
              style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
            ),
          ],
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: InkWell(
                  key: Key('email-entry-${entry.id}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => unawaited(
                    showEmailBodySheet(context, state, entry),
                  ),
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      entry.isRead
                          ? Icons.mark_email_read_outlined
                          : Icons.mark_email_unread_outlined,
                      size: 16,
                      color: entry.isRead
                          ? palette.textSecondary
                          : palette.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.sender,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                _timeLabel(entry.timestamp),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            entry.subject.isEmpty ? '(Без темы)' : entry.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            entry.preview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

String _outboxSummary(List<SmtpOutboxRecord> entries, String accountId) {
  final own = entries.where((e) => e.accountId == accountId).toList();
  final queued = own
      .where(
        (e) => e.status == outboxStatusQueued || e.status == outboxStatusSending,
      )
      .length;
  final sent = own.where((e) => e.status == outboxStatusSent).length;
  final failed = own.where((e) => e.status == outboxStatusFailed).length;
  return 'очередь: $queued · доставлено: $sent · ошибок: $failed';
}

/// MAIL-02B r3 (UX-3): открытие листа настроек аккаунтов с листа
/// реального ящика (выход из тупика notConfigured).
Future<void> _openAccountSettings(
  BuildContext context,
  OrbitAppState state,
  OrbitPalette palette,
) {
  return showOrbitMailAccountsSheet(context, palette: palette);
}

/// MAIL-02B: контролируемая SMTP-отправка. Ровно ОДИН разрешённый
/// получатель: dart-define ORBIT_SMTP_ALLOWED_RECIPIENT (приоритет)
/// ЛИБО адрес, сохранённый пользователем на устройстве (r3: без
/// перекомпиляции APK). Результат - sanitized статус из персистентного
/// outbox.
Future<void> showSmtpSendSheet(
  BuildContext context,
  OrbitAppState state,
  OrbitMailAccount account,
) async {
  // r2 (блокер 3): контроллеры создаются ОДИН раз до листа и
  // освобождаются после его закрытия - никаких пересозданий на ребилдах
  // StatefulBuilder и никаких утечек.
  final toController = TextEditingController();
  final subjectController = TextEditingController();
  final bodyController = TextEditingController();
  try {
    await showModalBottomSheet<void>(
      context: context,
      // r3 (UI-1): root navigator - лист открывается ПОВЕРХ нижнего
      // дока навигации OrbitShell, а не под ним.
      useRootNavigator: true,
      isScrollControlled: true,
      // r3 (UI-1): системная навигация Android не перекрывает контент.
      useSafeArea: true,
      builder: (sheetContext) {
        return _SmtpSheetContents(
          state: state,
          toController: toController,
          subjectController: subjectController,
          bodyController: bodyController,
        );
      },
    );
  } finally {
    toController.dispose();
    subjectController.dispose();
    bodyController.dispose();
  }
}

/// r3: busy/resultText живут в State - лист может пересоздаваться
/// (глобальный rebuild при notify app_state), но состояние отправки
/// переживает пересоздание (Element reuse) и результат не теряется.
final class _SmtpSheetContents extends StatefulWidget {
  const _SmtpSheetContents({
    required this.state,
    required this.toController,
    required this.subjectController,
    required this.bodyController,
  });

  final OrbitAppState state;
  final TextEditingController toController;
  final TextEditingController subjectController;
  final TextEditingController bodyController;

  @override
  State<_SmtpSheetContents> createState() => _SmtpSheetContentsState();
}

final class _SmtpSheetContentsState extends State<_SmtpSheetContents> {
  bool _busy = false;
  String? _resultText;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _resultText = null;
    });
    final state = widget.state;
    final hardLocked = state.smtpSendConfig.isConfigured;
    // r3 (UX-3): без dart-define получатель сохраняется на устройстве
    // (ровно один, с валидацией) прямо при отправке.
    if (!hardLocked) {
      final saveError = state.setControlledRecipient(
        widget.toController.text,
      );
      if (saveError != null) {
        setState(() {
          _busy = false;
          _resultText = 'rejected: $saveError';
        });
        return;
      }
    }
    final outcome = await state.sendRealEmail(
      to: widget.toController.text,
      subject: widget.subjectController.text,
      body: widget.bodyController.text,
    );
    await state.refreshSmtpOutboxEntries();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _resultText = '${outcome.status}: ${outcome.message}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final sheetContext = context;
    final toController = widget.toController;
    final configured = state.smtpSendConfig;
    final hardLocked = configured.isConfigured;
    final savedRecipient = state.controlledRecipient;
    final effectiveRecipient = hardLocked
        ? configured.allowedRecipients.first
        : savedRecipient;
    if (toController.text.isEmpty && effectiveRecipient != null) {
      // Prefill без слушателя: присваивание идемпотентно, пока поле
      // не редактировалось вручную.
      toController.text = effectiveRecipient;
    }
    final busy = _busy;
    final resultText = _resultText;
    Future<void> submit() => _submit();

    final media = MediaQuery.of(sheetContext);
            // r3 (UI-1): клавиатура И системная навигация; при открытой
            // клавиатуре viewPadding уже не «съедается» SafeArea.
            final bottomInset = media.viewInsets.bottom > 0
                ? media.viewInsets.bottom + 12
                : media.viewPadding.bottom + 16;
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 16),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.forward_to_inbox_rounded,
                            size: 18,
                            color: Theme.of(sheetContext).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'SMTP: контрольная отправка',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hardLocked
                            ? 'Разрешённый получатель (из конфигурации '
                                  'сборки): $effectiveRecipient'
                            : savedRecipient == null
                            ? 'Получатель не задан: введите ОДИН '
                                  'контролируемый тестовый адрес - он '
                                  'сохранится на устройстве.'
                            : 'Сохранённый получатель (на устройстве): '
                                  '$savedRecipient',
                        key: const Key('smtp-sheet-recipient-hint'),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('smtp-sheet-to'),
                        controller: toController,
                        enabled: !hardLocked,
                        decoration: const InputDecoration(
                          labelText: 'Кому (разрешённый получатель)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('smtp-sheet-subject'),
                        controller: widget.subjectController,
                        decoration: const InputDecoration(
                          labelText: 'Тема',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('smtp-sheet-body'),
                        controller: widget.bodyController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Текст письма',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FilledButton.icon(
                        key: const Key('smtp-sheet-submit'),
                        onPressed: busy ? null : submit,
                        icon: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Поставить в очередь и отправить'),
                      ),
                      if (resultText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          key: const Key('smtp-sheet-result'),
                          resultText,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text(
                        'Письмо попадает в персистентную очередь: retry при '
                        'сетевых сбоях, без дубликатов; содержимое и статус - '
                        'только в локальной базе устройства. Для '
                        'Яндекс/Mail.ru/Gmail нужен именно пароль '
                        'приложения, а не пароль аккаунта.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            );
  }
}

/// MAIL-02C: детали реального письма - тело on-demand (read-only
/// BODY.PEEK с size cap) с кэшем в production SQLite и ТОЛЬКО
/// метаданными вложений (имя/размер/mime); содержимое вложений никогда
/// не скачивается и не сохраняется. Рендеринг тела - исключительно
/// plain-text (Flutter Text): HTML/скрипты не исполняются по построению.
/// Верстка по правилам MAIL-02B r3: useRootNavigator + useSafeArea +
/// SingleChildScrollView (узкие экраны и системная навигация).
Future<void> showEmailBodySheet(
  BuildContext context,
  OrbitAppState state,
  UserInboxEntry entry,
) async {
  await state.fetchEmailBodyFor(entry.id);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewPadding.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: state,
              builder: (sheetContext, _) {
                final body = state.cachedBodyFor(entry.id);
                final error = state.lastBodyFetchError;
                final loading = state.isBodyFetchInProgress;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.subject.isEmpty ? '(Без темы)' : entry.subject,
                      key: const Key('email-body-subject'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.sender,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                    ),
                    const Divider(height: 24),
                    if (loading && body == null)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (body == null && error != null)
                      Text(
                        key: const Key('email-body-error'),
                        error,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orangeAccent,
                        ),
                      )
                    else if (body != null) ...[
                      Row(
                        children: [
                          Icon(
                            body.fromCache
                                ? Icons.cached_rounded
                                : Icons.cloud_download_outlined,
                            size: 14,
                            color:
                                Theme.of(sheetContext).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            key: const Key('email-body-source'),
                            body.fromCache
                                ? 'Из локального кэша (без сети)'
                                : 'Загружено с сервера (read-only)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          if (body.truncated) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.content_cut_rounded,
                              size: 14,
                              color: Colors.orangeAccent,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                key: const Key('email-body-truncated'),
                                'Фрагмент: ${body.bodyText.length} из '
                                '${body.fullSize} байт',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SelectableText(
                        key: const Key('email-body-text'),
                        body.bodyText.isEmpty
                            ? '(Пустое тело письма)'
                            : body.bodyText,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      if (body.attachments.isNotEmpty) ...[
                        const Divider(height: 24),
                        Text(
                          'Вложения (${body.attachments.length}) - только '
                          'метаданные, содержимое не скачивается:',
                          key: const Key('email-body-attachments-header'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        for (final attachment in body.attachments)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.attach_file_rounded,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    attachment.fileName.isEmpty
                                        ? '(без имени)'
                                        : attachment.fileName,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Text(
                                  key: Key(
                                    'email-attachment-'
                                    '${attachment.fileName}',
                                  ),
                                  '${attachment.mimeType} - '
                                  '${attachment.sizeBytes} Б',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Тело получено по IMAP без изменения состояния '
                      'сервера (BODY.PEEK); отображение - только текст.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
