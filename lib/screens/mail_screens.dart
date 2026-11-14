import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/demo_data.dart';
import '../l10n/orbit_localizations.dart';
import '../state/app_state.dart';
import '../visual_engine/orbit_visual_engine.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_mail_folders_sheet.dart';
import '../widgets/orbit_page.dart';
import '../widgets/orbit_real_inbox_panel.dart';
import '../widgets/orbit_snackbar.dart';
import '../widgets/orbit_spatial_surfaces.dart';

/// Виджет кликабельного заголовка выбора папки в шапке MailScreen.
final class OrbitMailFolderHeaderSelector extends StatelessWidget {
  const OrbitMailFolderHeaderSelector({
    required this.palette,
    required this.profile,
    required this.currentFolder,
    required this.unreadOrTotalBadge,
    required this.onTap,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final OrbitMailFolder currentFolder;
  final int unreadOrTotalBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = orbitRadiusForProfile(profile, offset: -4);

    return OrbitPressable(
      key: const Key('mail-folder-selector-trigger'),
      semanticLabel:
          'Выбрать папку почты. Текущая папка: ${currentFolder.label}',
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.38),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              currentFolder.icon,
              size: 19,
              color: palette.accent,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Почта: ${currentFolder.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: palette.textPrimary,
                ),
              ),
            ),
            if (unreadOrTotalBadge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$unreadOrTotalBadge',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: palette.accent,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: palette.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Плашка для папки «Корзина» с возможностью полной очистки.
final class OrbitTrashBannerBar extends StatelessWidget {
  const OrbitTrashBannerBar({
    required this.palette,
    required this.profile,
    required this.trashCount,
    required this.onEmptyTrash,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final int trashCount;
  final VoidCallback onEmptyTrash;

  @override
  Widget build(BuildContext context) {
    if (trashCount == 0) return const SizedBox.shrink();
    final radius = orbitRadiusForProfile(profile, offset: -4);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OrbitSpatialCard(
        palette: palette,
        radius: radius,
        tintColor: Colors.redAccent,
        tintIntensity: 0.14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.delete_sweep_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'В корзине: $trashCount',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
            ),
            OrbitFilledButton(
              buttonKey: const Key('mail-empty-trash-button'),
              palette: palette,
              radius: radius * 0.75,
              compact: true,
              primaryColor: Colors.redAccent,
              label: 'Очистить корзину',
              onTap: onEmptyTrash,
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка отправленного письма для папки «Отправленные».
final class OrbitSentMailTile extends StatelessWidget {
  const OrbitSentMailTile({
    required this.palette,
    required this.profile,
    required this.entry,
    required this.onMoveToTrash,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final OrbitSentMailEntry entry;
  final VoidCallback onMoveToTrash;

  @override
  Widget build(BuildContext context) {
    final radius = orbitRadiusForProfile(profile);

    return OrbitSpatialCard(
      palette: palette,
      radius: radius,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.outbond_rounded, size: 18, color: palette.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Кому: ${entry.recipient}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: palette.accent,
                  ),
                ),
              ),
              OrbitPressable(
                key: Key('sent-delete-${entry.id}'),
                semanticLabel: 'Переместить отправленное письмо в корзину',
                onTap: onMoveToTrash,
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.subject,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
          if (entry.body.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              entry.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: palette.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Панель действий над письмом в детальном просмотре или в Корзине:
/// позволяет переместить письмо в Архив, Спам, Корзину или восстановить во Входящие.
final class OrbitMailFolderActionRow extends StatelessWidget {
  const OrbitMailFolderActionRow({
    required this.palette,
    required this.profile,
    required this.emailId,
    required this.currentFolder,
    required this.onMoveToFolder,
    required this.onRestoreFromTrash,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final String emailId;
  final OrbitMailFolder currentFolder;
  final ValueChanged<OrbitMailFolder> onMoveToFolder;
  final VoidCallback onRestoreFromTrash;

  @override
  Widget build(BuildContext context) {
    final radius = orbitRadiusForProfile(profile, offset: -4);

    if (currentFolder == OrbitMailFolder.trash) {
      return Row(
        children: [
          Expanded(
            child: OrbitFilledButton(
              buttonKey: Key('mail-restore-button-$emailId'),
              palette: palette,
              radius: radius,
              compact: true,
              icon: Icons.restore_from_trash_rounded,
              label: 'Восстановить во Входящие',
              onTap: onRestoreFromTrash,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (currentFolder != OrbitMailFolder.archive)
          OrbitFilledButton(
            buttonKey: Key('mail-move-archive-$emailId'),
            palette: palette,
            radius: radius,
            compact: true,
            isPrimary: false,
            icon: Icons.archive_outlined,
            label: 'В архив',
            onTap: () => onMoveToFolder(OrbitMailFolder.archive),
          ),
        if (currentFolder != OrbitMailFolder.spam)
          OrbitFilledButton(
            buttonKey: Key('mail-move-spam-$emailId'),
            palette: palette,
            radius: radius,
            compact: true,
            isPrimary: false,
            icon: Icons.report_gmailerrorred_rounded,
            label: 'В спам',
            onTap: () => onMoveToFolder(OrbitMailFolder.spam),
          ),
        OrbitFilledButton(
          buttonKey: Key('mail-move-trash-$emailId'),
          palette: palette,
          radius: radius,
          compact: true,
          isPrimary: false,
          primaryColor: Colors.redAccent,
          icon: Icons.delete_sweep_outlined,
          label: 'В корзину',
          onTap: () => onMoveToFolder(OrbitMailFolder.trash),
        ),
      ],
    );
  }
}

final class MailScreen extends StatefulWidget {
  const MailScreen({super.key});

  @override
  State<MailScreen> createState() => _MailScreenState();
}

final class _MailScreenState extends State<MailScreen> {
  int _filter = 0;

  void _openFoldersSheet(
    BuildContext context,
    OrbitAppState state,
    OrbitPalette palette,
    OrbitProfile profile,
  ) {
    showOrbitMailFoldersSheet(
      context,
      palette: palette,
      profile: profile,
      currentFolder: state.currentMailFolder,
      badgeBuilder: (folder) => state.badgeCountForFolder(folder),
      onFolderSelected: (folder) {
        state.selectMailFolder(folder);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final state = env.appState;
    final folder = state.currentMailFolder;

    final emails = switch (_filter) {
      1 => demoEmails.where((e) => state.isEmailInInbox(e.id) && !state.isRead(e)).toList(),
      2 => demoEmails.where((e) => state.isEmailInInbox(e.id) && state.isStarred(e)).toList(),
      _ => demoEmails.where((e) => state.isEmailInInbox(e.id)).toList(),
    };
    final unreadTotal = state.unreadCount(emails);

    final String pageTitle = folder == OrbitMailFolder.inbox ? context.l10n.inbox : folder.label;
    final String pageSubtitle = folder == OrbitMailFolder.inbox
        ? context.l10n.unreadSummary(unreadTotal)
        : '${folder.label} • ${state.badgeCountForFolder(folder)}';

    return OrbitPage(
      title: pageTitle,
      subtitle: pageSubtitle,
      actions: [
        OrbitIconButton(
          key: const Key('mail-folder-selector-action'),
          palette: palette,
          icon: Icons.folder_outlined,
          tooltip: 'Папки почты',
          onTap: () => _openFoldersSheet(context, state, palette, palette.profile),
        ),
        const SizedBox(width: 6),
        OrbitIconButton(
          palette: palette,
          icon: Icons.search_rounded,
          tooltip: context.l10n.search,
          onTap: () => showSearch(
            context: context,
            delegate: _MailSearchDelegate(palette),
          ),
        ),
        const SizedBox(width: 6),
        OrbitIconButton(
          palette: palette,
          icon: Icons.edit_outlined,
          tooltip: context.l10n.newEmail,
          onTap: () => context.push('/mail/compose'),
        ),
      ],
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 24),
        child: OrbitFab(
          palette: palette,
          buttonKey: const Key('compose-fab'),
          icon: Icons.edit_rounded,
          tooltip: context.l10n.newEmail,
          onTap: () => context.push('/mail/compose'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OrbitMailFolderHeaderSelector(
            palette: palette,
            profile: palette.profile,
            currentFolder: folder,
            unreadOrTotalBadge: state.badgeCountForFolder(folder),
            onTap: () => _openFoldersSheet(context, state, palette, palette.profile),
          ),
          const SizedBox(height: 12),
          if (folder == OrbitMailFolder.inbox) ...[
            // MAIL-02A: настоящий read-only INBOX (отдельно от DEMO).
            const OrbitRealInboxPanel(),
            const SizedBox(height: 12),
            // Filter capsules row (Входящие / Непрочитанные / Важные)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (index, label) in [
                  (0, context.l10n.all),
                  (1, context.l10n.unread),
                  (2, context.l10n.important),
                ])
                  ChoiceChip(
                    key: Key('mail-filter-$index'),
                    label: Text(label),
                    selected: _filter == index,
                    onSelected: (_) => setState(() => _filter = index),
                    selectedColor: palette.accent.withValues(alpha: 0.35),
                    backgroundColor: palette.surface.withValues(alpha: 0.4),
                    labelStyle: TextStyle(
                      fontWeight: _filter == index ? FontWeight.w600 : FontWeight.w500,
                      color: _filter == index ? Colors.white : palette.textSecondary,
                      fontSize: 13,
                    ),
                    elevation: _filter == index ? 4 : 0,
                    shadowColor: palette.accent.withValues(alpha: 0.4),
                    side: BorderSide(
                      color: _filter == index
                          ? palette.accent.withValues(alpha: 0.8)
                          : palette.textPrimary.withValues(alpha: 0.12),
                      width: _filter == index ? 1.4 : 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Email cards list
            GlassPanel(
              palette: palette,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              radius: 24,
              child: emails.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(child: Text(context.l10n.emptyHere)),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < emails.length; i++) ...[
                          _EmailRow(
                            email: emails[i],
                            read: state.isRead(emails[i]),
                            onTap: () {
                              state.markRead(emails[i].id);
                              context.push('/mail/message/${emails[i].id}');
                            },
                          ),
                          if (i < emails.length - 1)
                            Divider(
                              height: 1,
                              indent: 58,
                              color: palette.textPrimary.withValues(alpha: 0.08),
                            ),
                        ],
                      ],
                    ),
            ),
          ] else if (folder == OrbitMailFolder.sent) ...[
            if (state.sentEmails.isEmpty)
              GlassPanel(
                palette: palette,
                padding: const EdgeInsets.all(32),
                radius: 24,
                child: Center(child: Text(context.l10n.emptyHere)),
              )
            else
              Column(
                children: [
                  for (final sentEntry in state.sentEmails) ...[
                    OrbitSentMailTile(
                      palette: palette,
                      profile: palette.profile,
                      entry: sentEntry,
                      onMoveToTrash: () => state.moveToFolder(sentEntry.id, OrbitMailFolder.trash),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
          ] else if (folder == OrbitMailFolder.drafts) ...[
            if (state.draftSubject.isEmpty && state.draftBody.isEmpty && state.draftTo.isEmpty)
              GlassPanel(
                palette: palette,
                padding: const EdgeInsets.all(32),
                radius: 24,
                child: Center(child: Text(context.l10n.emptyHere)),
              )
            else
              InkWell(
                onTap: () => context.push('/mail/compose'),
                borderRadius: BorderRadius.circular(16),
                child: OrbitSpatialCard(
                  palette: palette,
                  radius: orbitRadiusForProfile(palette.profile),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_note_rounded, color: palette.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            state.draftTo.isEmpty ? 'Черновик (без получателя)' : 'Кому: ${state.draftTo}',
                            style: TextStyle(fontWeight: FontWeight.w700, color: palette.accent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.draftSubject.isEmpty ? '(Без темы)' : state.draftSubject,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.textPrimary),
                      ),
                      if (state.draftBody.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          state.draftBody,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: palette.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ] else if (folder == OrbitMailFolder.trash) ...[
            OrbitTrashBannerBar(
              palette: palette,
              profile: palette.profile,
              trashCount: state.trashEmails.length,
              onEmptyTrash: () => state.emptyTrash(),
            ),
            Builder(
              builder: (context) {
                final trashList = demoEmails.where((e) => state.trashEmails.contains(e.id)).toList();
                if (trashList.isEmpty) {
                  return GlassPanel(
                    palette: palette,
                    padding: const EdgeInsets.all(32),
                    radius: 24,
                    child: Center(child: Text(context.l10n.emptyHere)),
                  );
                }
                return Column(
                  children: [
                    for (final email in trashList) ...[
                      OrbitSpatialCard(
                        palette: palette,
                        radius: orbitRadiusForProfile(palette.profile),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    email.localizedSender(context),
                                    style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary),
                                  ),
                                ),
                                OrbitFilledButton(
                                  buttonKey: Key('mail-restore-button-${email.id}'),
                                  palette: palette,
                                  radius: orbitRadiusForProfile(palette.profile, offset: -6),
                                  compact: true,
                                  icon: Icons.restore_from_trash_rounded,
                                  label: 'Восстановить',
                                  onTap: () => state.restoreFromTrash(email.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              email.localizedSubject(context),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: palette.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email.localizedPreview(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: palette.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ] else ...[
            // archive, spam, outbox
            Builder(
              builder: (context) {
                final folderEmails = switch (folder) {
                  OrbitMailFolder.archive => demoEmails.where((e) => state.archiveEmails.contains(e.id)).toList(),
                  OrbitMailFolder.spam => demoEmails.where((e) => state.spamEmails.contains(e.id)).toList(),
                  OrbitMailFolder.outbox => demoEmails.where((e) => state.outboxEmails.contains(e.id)).toList(),
                  _ => <DemoEmail>[],
                };
                if (folderEmails.isEmpty) {
                  return GlassPanel(
                    palette: palette,
                    padding: const EdgeInsets.all(32),
                    radius: 24,
                    child: Center(child: Text(context.l10n.emptyHere)),
                  );
                }
                return Column(
                  children: [
                    for (final email in folderEmails) ...[
                      OrbitSpatialCard(
                        palette: palette,
                        radius: orbitRadiusForProfile(palette.profile),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    email.localizedSender(context),
                                    style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary),
                                  ),
                                ),
                                OrbitFilledButton(
                                  palette: palette,
                                  radius: orbitRadiusForProfile(palette.profile, offset: -6),
                                  compact: true,
                                  icon: Icons.inbox_rounded,
                                  label: 'Во входящие',
                                  onTap: () => state.moveToFolder(email.id, OrbitMailFolder.inbox),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              email.localizedSubject(context),
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: palette.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email.localizedPreview(context),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: palette.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            OrbitMailFolderActionRow(
                              palette: palette,
                              profile: palette.profile,
                              emailId: email.id,
                              currentFolder: folder,
                              onMoveToFolder: (target) => state.moveToFolder(email.id, target),
                              onRestoreFromTrash: () => state.restoreFromTrash(email.id),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 14),
          Center(
            child: Text(
              context.l10n.mailDemoNotice,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

final class _EmailRow extends StatelessWidget {
  const _EmailRow({
    required this.email,
    required this.read,
    required this.onTap,
  });
  final DemoEmail email;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = OrbitEnvironment.of(context).palette;
    return InkWell(
      key: Key('email-${email.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(email: email, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender name + Unread badge + Timestamp
                  Row(
                    children: [
                      if (!read)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: palette.accentSecondary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: palette.accentSecondary.withValues(alpha: 0.6),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: Text(
                          email.localizedSender(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        email.localizedTime(context),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: read ? palette.textSecondary : palette.accentSecondary,
                          fontWeight: read ? FontWeight.normal : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Subject row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          email.localizedSubject(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                            fontWeight: read ? FontWeight.w400 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (email.starred)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: palette.sun,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Snippet
                  Text(
                    email.localizedPreview(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: palette.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  // Attachments indicator
                  if (email.attachments.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.surface.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.textPrimary.withValues(alpha: 0.12)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.attach_file_rounded,
                                size: 12,
                                color: palette.accentSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${email.attachments.length}',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Avatar extends StatelessWidget {
  const _Avatar({required this.email, this.size = 44});
  final DemoEmail email;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Custom recognizable styling for branded or individual senders
    final senderLower = email.sender.toLowerCase();
    if (senderLower.contains('figma')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFF24E1E), Color(0xFFA259FF), Color(0xFF0ACF83)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white24, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          'F',
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );
    }
    if (senderLower.contains('яндекс') || senderLower.contains('yandex')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFFC3F1D),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          'Я',
          style: TextStyle(
            fontSize: size * 0.42,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );
    }
    if (senderLower.contains('booking')) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFF003580),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(
          'B',
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      );
    }

    final initials = email.sender
        .split(' ')
        .take(2)
        .map((word) => word.isEmpty ? '' : word[0])
        .join();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            email.color.withValues(alpha: 0.8),
            email.color.withValues(alpha: 0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: email.color.withValues(alpha: 0.5),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: email.color.withValues(alpha: 0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

final class MailDetailScreen extends StatelessWidget {
  const MailDetailScreen({required this.id, super.key});
  final String id;

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final email = demoEmails.firstWhere(
      (item) => item.id == id,
      orElse: () => demoEmails.first,
    );

    return OrbitPage(
      title: email.localizedSubject(context),
      subtitle: '${context.l10n.inbox} · ${email.localizedTime(context)}',
      reduceEffects: true,
      leading: OrbitBackButton(onTap: () => context.pop()),
      actions: [
        OrbitIconButton(
          palette: palette,
          icon: env.appState.isStarred(email)
              ? Icons.star_rounded
              : Icons.star_outline_rounded,
          tooltip: context.l10n.importantSingle,
          onTap: () {
            final nowStarred = env.appState.toggleStarred(email.id, email.starred);
            showOrbitBanner(
              context,
              palette: palette,
              message: nowStarred
                  ? 'Письмо помечено как важное'
                  : 'Снята отметка важности',
            );
          },
        ),
        const SizedBox(width: 4),
        OrbitIconButton(
          palette: palette,
          icon: Icons.delete_outline_rounded,
          tooltip: 'Удалить',
          onTap: () {
            final appState = env.appState;
            appState.deleteEmail(email.id);
            context.pop();
            showOrbitBanner(
              context,
              palette: palette,
              message: 'Письмо удалено',
              actionLabel: 'Отмена',
              onAction: () => appState.restoreEmail(email.id),
            );
          },
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header info: Badges
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.accent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  context.l10n.inbox,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: palette.accent,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.textPrimary.withValues(alpha: 0.12)),
                ),
                child: Text(
                  email.localizedTime(context),
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Sender Card
          GlassPanel(
            palette: palette,
            quality: ResolvedQuality.static,
            padding: const EdgeInsets.all(14),
            radius: 18,
            child: Row(
              children: [
                _Avatar(email: email, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email.localizedSender(context),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.toMe(email.email),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Body Panel
          GlassPanel(
            palette: palette,
            quality: ResolvedQuality.static,
            padding: const EdgeInsets.all(18),
            radius: 20,
            child: Text(
              email.localizedBody(context),
              key: const Key('mail-detail-body'),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.5,
                fontSize: 15,
              ),
            ),
          ),

          // Attachment Cards
          if (email.attachments.isNotEmpty) ...[
            const SizedBox(height: 20),
            OrbitSectionTitle(context.l10n.attachments),
            const SizedBox(height: 10),
            for (final (index, _) in email.attachments.indexed) ...[
              _AttachmentCard(
                palette: palette,
                attachmentText: email.localizedAttachment(context, index),
                onTap: () => _localNotice(
                  context,
                  context.l10n.demoAttachmentNotice,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],

          const SizedBox(height: 24),

          // Cross-Entity Linkage: Create Task & Schedule Meeting
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                key: const Key('mail-create-task-chip'),
                avatar: Icon(Icons.check_circle_outline_rounded, size: 16, color: palette.accent),
                label: const Text('В задачи'),
                backgroundColor: palette.surface.withValues(alpha: 0.5),
                side: BorderSide(color: palette.textPrimary.withValues(alpha: 0.15)),
                labelStyle: TextStyle(fontSize: 12, color: palette.textPrimary),
                onPressed: () {
                  final title = email.localizedSubject(context);
                  env.appState.addTask(title);
                  showOrbitBanner(
                    context,
                    palette: palette,
                    message: 'Задача создана: $title',
                    actionLabel: 'Перейти',
                    onAction: () => context.go('/tasks'),
                  );
                },
              ),
              ActionChip(
                key: const Key('mail-schedule-meeting-chip'),
                avatar: const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFFFFB366)),
                label: const Text('Встреча'),
                backgroundColor: palette.surface.withValues(alpha: 0.5),
                side: BorderSide(color: palette.textPrimary.withValues(alpha: 0.15)),
                labelStyle: TextStyle(fontSize: 12, color: palette.textPrimary),
                onPressed: () {
                  final title = email.localizedSubject(context);
                  env.appState.addEvent(
                    title,
                    '11:00',
                    DateTime.now().add(const Duration(days: 1)),
                  );
                  showOrbitBanner(
                    context,
                    palette: palette,
                    message: 'Встреча добавлена: $title',
                    actionLabel: 'Перейти',
                    onAction: () => context.go('/calendar'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Reply / Reply All / Forward
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                key: const Key('reply-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  env.appState.startReply(
                    email,
                    localizedSubject: email.localizedSubject(context),
                    localizedBody: context.l10n.demoReplyBody(
                      email.localizedPreview(context),
                    ),
                  );
                  context.push('/mail/compose');
                },
                icon: const Icon(Icons.reply_rounded, size: 18),
                label: Text(context.l10n.reply),
              ),
              OutlinedButton.icon(
                key: const Key('reply-all-button'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.textPrimary.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  env.appState.startReply(
                    email,
                    to: '${email.email}; orbit-team@example.demo',
                    localizedSubject: email.localizedSubject(context),
                    localizedBody: context.l10n.demoReplyBody(
                      email.localizedPreview(context),
                    ),
                  );
                  context.push('/mail/compose');
                },
                icon: const Icon(Icons.reply_all_rounded, size: 18),
                label: Text(context.l10n.replyAll),
              ),
              IconButton.outlined(
                key: const Key('forward-button'),
                tooltip: context.l10n.forward,
                style: IconButton.styleFrom(
                  side: BorderSide(color: palette.textPrimary.withValues(alpha: 0.15)),
                  padding: const EdgeInsets.all(12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  env.appState.startReply(
                    email,
                    to: '',
                    subject: 'Fwd: ${email.localizedSubject(context)}',
                    localizedSubject: email.localizedSubject(context),
                    localizedBody: context.l10n.demoForwardBody(
                      email.localizedPreview(context),
                    ),
                  );
                  context.push('/mail/compose');
                },
                icon: const Icon(Icons.forward_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OrbitMailFolderActionRow(
            palette: palette,
            profile: palette.profile,
            emailId: email.id,
            currentFolder: env.appState.folderForEmail(email.id),
            onMoveToFolder: (targetFolder) {
              env.appState.moveToFolder(email.id, targetFolder);
              showOrbitBanner(
                context,
                palette: palette,
                message: 'Перемещено в: ${targetFolder.label}',
              );
              context.pop();
            },
            onRestoreFromTrash: () {
              env.appState.restoreFromTrash(email.id);
              showOrbitBanner(
                context,
                palette: palette,
                message: 'Восстановлено во Входящие',
              );
              context.pop();
            },
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }

  static void _localNotice(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

final class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.palette,
    required this.attachmentText,
    required this.onTap,
  });

  final OrbitPalette palette;
  final String attachmentText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPdf = attachmentText.toLowerCase().contains('.pdf');
    final isXlsx = attachmentText.toLowerCase().contains('.xlsx');
    final iconColor = isPdf
        ? const Color(0xFFEF4444)
        : isXlsx
            ? const Color(0xFF10B981)
            : palette.accentSecondary;
    final badgeLabel = isPdf ? 'PDF' : isXlsx ? 'XLSX' : 'DOC';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: GlassPanel(
        palette: palette,
        quality: ResolvedQuality.static,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 16,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withValues(alpha: 0.4)),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: iconColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachmentText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.openAttachment,
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.accentSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download_rounded,
              color: palette.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

final class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

final class _ComposeScreenState extends State<ComposeScreen>
    with WidgetsBindingObserver {
  static const _autosaveDelay = Duration(milliseconds: 450);

  late final TextEditingController _to;
  late final TextEditingController _subject;
  late final TextEditingController _body;
  late final OrbitAppState _appState;
  Timer? _autosaveTimer;
  bool _deletingDraft = false;

  @override
  void initState() {
    super.initState();
    final state = OrbitEnvironment.read(context);
    _appState = state.appState;
    _to = TextEditingController(text: state.appState.draftTo);
    _subject = TextEditingController(text: state.appState.draftSubject);
    _body = TextEditingController(text: state.appState.draftBody);
    _to.addListener(_scheduleAutosave);
    _subject.addListener(_scheduleAutosave);
    _body.addListener(_scheduleAutosave);
    WidgetsBinding.instance.addObserver(this);
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, _persistDraft);
  }

  void _persistDraft() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (_deletingDraft) return;
    _appState.updateDraft(
      to: _to.text,
      subject: _subject.text,
      body: _body.text,
    );
  }

  Future<bool> _flushDraft() async {
    _persistDraft();
    final appState = _appState;
    try {
      await appState.flush();
      return true;
    } on Object {
      return false;
    }
  }

  void _insertFormatting(String prefix, String suffix) {
    HapticFeedback.selectionClick();
    final text = _body.text;
    final selection = _body.selection;
    if (selection.isValid && !selection.isCollapsed) {
      final selected = selection.textInside(text);
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '$prefix$selected$suffix',
      );
      _body.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.start + prefix.length + selected.length,
        ),
      );
    } else {
      final cursor = selection.isValid ? selection.start : text.length;
      final newText = text.replaceRange(cursor, cursor, '$prefix$suffix');
      _body.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursor + prefix.length),
      );
    }
    _scheduleAutosave();
  }

  void _sendEmail() {
    _persistDraft();
    HapticFeedback.mediumImpact();
    final draft = _appState.draft;
    _appState.sendEmail(draft);
    final env = OrbitEnvironment.of(context);
    showOrbitSpatialIsland(
      context,
      palette: env.palette,
      title: 'Письмо отправлено',
      icon: Icons.send_rounded,
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _saveDraft() async {
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    messenger.hideCurrentSnackBar();
    final saved = await _flushDraft();
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved ? context.l10n.draftSaved : context.l10n.localSaveFailed,
        ),
      ),
    );
  }

  Future<void> _deleteDraft() async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить черновик?'),
        content: const Text(
          'Черновик будет удалён без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _deletingDraft = true;
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    _to.clear();
    _subject.clear();
    _body.clear();
    _appState.clearDraft();
    await _appState.flush();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _close() async {
    final navigator = Navigator.of(context);
    final saved = await _flushDraft();
    if (!mounted) return;
    if (saved) {
      navigator.pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.localSaveFailed)));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    _persistDraft();
    unawaited(_appState.flush().catchError((_) {}));
  }

  @override
  void dispose() {
    _persistDraft();
    unawaited(_appState.flush().catchError((_) {}));
    WidgetsBinding.instance.removeObserver(this);
    _to
      ..removeListener(_scheduleAutosave)
      ..dispose();
    _subject
      ..removeListener(_scheduleAutosave)
      ..dispose();
    _body
      ..removeListener(_scheduleAutosave)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final saveState = env.appState.hasUnsavedDraftChanges
        ? context.l10n.draftUnsavedChanges
        : context.l10n.draftSavedState;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_close());
      },
      child: OrbitPage(
        title: context.l10n.newEmail,
        subtitle: '${context.l10n.draftSubtitle} · $saveState',
        reduceEffects: true,
        leading: OrbitBackButton(onTap: _close),
        actions: [
          OrbitIconButton(
            key: const Key('delete-draft-button'),
            palette: palette,
            icon: Icons.delete_outline_rounded,
            tooltip: 'Удалить черновик',
            onTap: _deleteDraft,
          ),
          const SizedBox(width: 6),
          OrbitIconButton(
            key: const Key('compose-send-icon'),
            palette: palette,
            icon: Icons.send_rounded,
            tooltip: 'Отправить',
            onTap: _sendEmail,
          ),
          const SizedBox(width: 6),
          OrbitIconButton(
            palette: palette,
            icon: Icons.save_outlined,
            tooltip: context.l10n.saveDraft,
            onTap: _saveDraft,
          ),
        ],
        body: GlassPanel(
          palette: palette,
          quality: ResolvedQuality.static,
          padding: const EdgeInsets.all(18),
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DraftField(
                controller: _to,
                label: context.l10n.to,
                hint: 'name@example.demo',
                key: const Key('draft-to'),
              ),
              const Divider(height: 20),
              _DraftField(
                controller: _subject,
                label: context.l10n.subject,
                hint: context.l10n.subjectHint,
                key: const Key('draft-subject'),
              ),
              const Divider(height: 20),
              // Rich Formatting toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.textPrimary.withValues(alpha: 0.1)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('formatting-disabled'),
                        tooltip: context.l10n.formatting,
                        onPressed: null,
                        icon: const Icon(Icons.text_format_rounded, size: 20),
                      ),
                      _ToolbarChip(
                        key: const Key('format-bold'),
                        label: 'B',
                        isBold: true,
                        onTap: () => _insertFormatting('**', '**'),
                      ),
                      _ToolbarChip(
                        key: const Key('format-italic'),
                        label: 'I',
                        isItalic: true,
                        onTap: () => _insertFormatting('*', '*'),
                      ),
                      IconButton(
                        key: const Key('format-list'),
                        icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                        tooltip: 'List',
                        onPressed: () => _insertFormatting('\n• ', ''),
                      ),
                      IconButton(
                        key: const Key('format-link'),
                        icon: const Icon(Icons.link_rounded, size: 18),
                        tooltip: 'Link',
                        onPressed: () => _insertFormatting('[', '](https://)'),
                      ),
                      IconButton(
                        tooltip: context.l10n.attachmentsDisabled,
                        onPressed: () => MailDetailScreen._localNotice(
                          context,
                          context.l10n.localFilesDisabled,
                        ),
                        icon: const Icon(Icons.attach_file_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('draft-body'),
                controller: _body,
                minLines: 8,
                maxLines: 16,
                decoration: InputDecoration(
                  hintText: context.l10n.bodyHint,
                  border: InputBorder.none,
                ),
              ),
              const Divider(height: 20),
              // Attachment chip indicator
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 14,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 6),
                        const Flexible(
                          child: Text(
                            'План_недели.pdf 2.4 МБ',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: palette.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.textPrimary.withValues(alpha: 0.12)),
                    ),
                    child: Icon(Icons.add_rounded, size: 18, color: palette.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('save-draft-button'),
                      onPressed: _saveDraft,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: palette.textPrimary.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.save_outlined, size: 18),
                      label: Text(context.l10n.save),
                    ),
                    FilledButton.icon(
                      key: const Key('send-email-button'),
                      onPressed: _sendEmail,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Отправить'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({
    required this.label,
    required this.onTap,
    this.isBold = false,
    this.isItalic = false,
    super.key,
  });

  final String label;
  final VoidCallback onTap;
  final bool isBold;
  final bool isItalic;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

final class _DraftField extends StatelessWidget {
  const _DraftField({
    required this.controller,
    required this.label,
    required this.hint,
    super.key,
  });
  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      decoration: InputDecoration(hintText: hint, border: InputBorder.none),
    );
    if (MediaQuery.textScalerOf(context).scale(1) > 1.25) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          field,
        ],
      );
    }
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(child: field),
      ],
    );
  }
}

final class _MailSearchDelegate extends SearchDelegate<void> {
  _MailSearchDelegate(this.palette);
  final OrbitPalette palette;

  @override
  ThemeData appBarTheme(BuildContext context) =>
      palette.themeData(palette.accent);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(
      onPressed: () => query = '',
      icon: const Icon(Icons.clear_rounded),
    ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(Icons.arrow_back_rounded),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final matches = demoEmails.where((email) {
      final haystack =
          '${email.localizedSender(context)} '
                  '${email.localizedSubject(context)} '
                  '${email.localizedPreview(context)}'
              .toLowerCase();
      return haystack.contains(query.toLowerCase());
    }).toList();
    return ColoredBox(
      color: palette.surfaceStrong,
      child: ListView.builder(
        itemCount: matches.length,
        itemBuilder: (_, index) => ListTile(
          leading: _Avatar(email: matches[index]),
          title: Text(matches[index].localizedSubject(context)),
          subtitle: Text(matches[index].localizedSender(context)),
          onTap: () {
            close(context, null);
            GoRouter.of(context).push('/mail/message/${matches[index].id}');
          },
        ),
      ),
    );
  }
}
