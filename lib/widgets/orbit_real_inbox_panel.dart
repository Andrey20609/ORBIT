import 'dart:async';

import 'package:flutter/material.dart';

import '../services/mail/mail_connection_verifier.dart';
import '../services/mail/mail_models.dart';
import '../services/mail/smtp_outbox_store.dart';
import '../state/app_state.dart';
import '../visual_engine/orbit_visual_engine.dart';
import 'glass_panel.dart';
import 'orbit_environment.dart';
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
          Row(
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
              const SizedBox(width: 8),
              Icon(
                Icons.lock_outline_rounded,
                size: 14,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Только чтение',
                style: TextStyle(fontSize: 11, color: palette.textSecondary),
              ),
            ],
          ),
          // MAIL-02B: контролируемая SMTP-отправка (один разрешённый
          // получатель из конфигурации; персистентный outbox с retry).
          const SizedBox(height: 4),
          Row(
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
              const SizedBox(width: 4),
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

/// MAIL-02B: контролируемая SMTP-отправка. Получатель ограничен
/// конфигурацией (prefill единственного разрешённого адреса, если он
/// один); результат — sanitized статус из персистентного outbox.
Future<void> showSmtpSendSheet(
  BuildContext context,
  OrbitAppState state,
  OrbitMailAccount account,
) async {
  final allowed = state.smtpSendConfig.allowedRecipients;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      var to = allowed.isEmpty ? '' : allowed.first;
      var subject = '';
      var body = '';
      var busy = false;
      String? resultText;
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            setSheetState(() {
              busy = true;
              resultText = null;
            });
            final outcome = await state.sendRealEmail(
              to: to,
              subject: subject,
              body: body,
            );
            await state.refreshSmtpOutboxEntries();
            setSheetState(() {
              busy = false;
              resultText = '${outcome.status}: ${outcome.message}';
            });
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
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
                  allowed.isEmpty
                      ? 'Получатель не настроен: задайте тестовый адрес '
                          'получателя в конфигурации сборки.'
                      : 'Разрешённый получатель: ${allowed.join(', ')}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('smtp-sheet-to'),
                  controller: TextEditingController(text: to),
                  enabled: allowed.length != 1,
                  decoration: const InputDecoration(
                    labelText: 'Кому (разрешённый получатель)',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => to = value,
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('smtp-sheet-subject'),
                  controller: TextEditingController(text: subject),
                  decoration: const InputDecoration(
                    labelText: 'Тема',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => subject = value,
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('smtp-sheet-body'),
                  controller: TextEditingController(text: body),
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Текст письма',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => body = value,
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const Key('smtp-sheet-submit'),
                  onPressed: busy || allowed.isEmpty ? null : submit,
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Поставить в очередь и отправить'),
                ),
                if (resultText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    key: const Key('smtp-sheet-result'),
                    resultText!,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Письмо попадает в персистентную очередь: retry при '
                  'сетевых сбоях, без дубликатов; содержимое и статус — '
                  'только в локальной базе устройства.',
                  style: TextStyle(fontSize: 11),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
