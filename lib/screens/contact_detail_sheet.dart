import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../visual_engine/appearance_settings.dart';
import '../visual_engine/orbit_palette.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_spatial_surfaces.dart';

/// Связанная с контактом сущность (письмо, встреча, общая задача).
@immutable
final class ContactRelatedItem {
  const ContactRelatedItem({
    required this.id,
    required this.type, // 'mail' | 'calendar' | 'task'
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String id;
  final String type;
  final String title;
  final String subtitle;
  final String route;
}

/// Детальная модель контакта для карточки просмотра.
@immutable
final class OrbitContactDetailModel {
  const OrbitContactDetailModel({
    required this.id,
    required this.fullName,
    required this.email,
    this.organization = 'ORBIT Ecosystem',
    this.jobTitle = 'Product Architect',
    this.phone = '+7 (999) 000-42-42',
    this.bioNote = 'Ключевой участник рабочей группы по запуску ORBIT 1.0.',
    this.relatedItems = const <ContactRelatedItem>[],
  });

  final String id;
  final String fullName;
  final String email;
  final String organization;
  final String jobTitle;
  final String phone;
  final String bioNote;
  final List<ContactRelatedItem> relatedItems;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'OR';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Вызывает карточку детального просмотра контакта.
Future<void> showContactDetailSheet(
  BuildContext context, {
  required OrbitPalette palette,
  required OrbitProfile profile,
  required OrbitContactDetailModel contact,
}) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => ContactDetailSheet(
      palette: palette,
      profile: profile,
      contact: contact,
    ),
  );
}

final class ContactDetailSheet extends StatelessWidget {
  const ContactDetailSheet({
    required this.palette,
    required this.profile,
    required this.contact,
    super.key,
  });

  final OrbitPalette palette;
  final OrbitProfile profile;
  final OrbitContactDetailModel contact;

  double get _radius => orbitRadiusForProfile(profile);

  void _navigateFromContact(BuildContext context, String route) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final isLargeText = MediaQuery.textScalerOf(context).scale(1.0) > 1.25;
    final encodedEmail = Uri.encodeComponent(contact.email);
    final encodedName = Uri.encodeComponent(contact.fullName);

    final related = contact.relatedItems.isNotEmpty
        ? contact.relatedItems
        : <ContactRelatedItem>[
            ContactRelatedItem(
              id: 'rel_mail_1',
              type: 'mail',
              title: 'Re: Архитектура синхронизации ORBIT Vault',
              subtitle: 'Входящее письмо • Вчера, 18:20',
              route: '/mail',
            ),
            ContactRelatedItem(
              id: 'rel_cal_1',
              type: 'calendar',
              title: 'Синхронизация по роадмапу Q4',
              subtitle: 'Общая встреча • Четверг, 15:00',
              route: '/calendar',
            ),
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: OrbitSpatialCard(
        palette: palette,
        radius: _radius + 8,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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

                // Большой монограммный аватар и ФИО/должность
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: palette.accent.withValues(alpha: 0.38),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        contact.initials,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.fullName,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${contact.jobTitle} • ${contact.organization}',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 3 кнопки быстрых действий экосистемы (полное заполнение)
                if (isLargeText) ...[
                  OrbitFilledButton(
                    buttonKey: const Key('contact-action-mail'),
                    palette: palette,
                    radius: _radius * 0.75,
                    icon: Icons.mail_rounded,
                    label: 'Написать письмо',
                    subtitle: contact.email,
                    onTap: () => _navigateFromContact(
                      context,
                      '/mail/compose?to=$encodedEmail&name=$encodedName',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitFilledButton(
                    buttonKey: const Key('contact-action-calendar'),
                    palette: palette,
                    radius: _radius * 0.75,
                    isPrimary: false,
                    icon: Icons.event_available_rounded,
                    label: 'Назначить встречу',
                    subtitle: 'Добавить в участники календаря',
                    onTap: () => _navigateFromContact(
                      context,
                      '/calendar?add=1&attendee=$encodedEmail',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OrbitFilledButton(
                    buttonKey: const Key('contact-action-task'),
                    palette: palette,
                    radius: _radius * 0.75,
                    isPrimary: false,
                    primaryColor: palette.accentSecondary,
                    icon: Icons.task_alt_rounded,
                    label: 'Поставить задачу',
                    subtitle: 'Связать с контактом',
                    onTap: () => _navigateFromContact(
                      context,
                      '/tasks?add=1&contactId=${contact.id}',
                    ),
                  ),
                ] else
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: OrbitFilledButton(
                            buttonKey: const Key('contact-action-mail'),
                            palette: palette,
                            radius: _radius * 0.75,
                            compact: true,
                            icon: Icons.mail_rounded,
                            label: 'Письмо',
                            onTap: () => _navigateFromContact(
                              context,
                              '/mail/compose?to=$encodedEmail&name=$encodedName',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OrbitFilledButton(
                            buttonKey: const Key('contact-action-calendar'),
                            palette: palette,
                            radius: _radius * 0.75,
                            compact: true,
                            isPrimary: false,
                            icon: Icons.event_available_rounded,
                            label: 'Встреча',
                            onTap: () => _navigateFromContact(
                              context,
                              '/calendar?add=1&attendee=$encodedEmail',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OrbitFilledButton(
                            buttonKey: const Key('contact-action-task'),
                            palette: palette,
                            radius: _radius * 0.75,
                            compact: true,
                            isPrimary: false,
                            primaryColor: palette.accentSecondary,
                            icon: Icons.task_alt_rounded,
                            label: 'Задача',
                            onTap: () => _navigateFromContact(
                              context,
                              '/tasks?add=1&contactId=${contact.id}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Реквизиты контакта (Email, Телефон, Заметка)
                GlassPanel(
                  palette: palette,
                  radius: _radius * 0.85,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ContactFieldRow(
                        palette: palette,
                        icon: Icons.alternate_email_rounded,
                        label: 'Email',
                        value: contact.email,
                      ),
                      const Divider(height: 18),
                      _ContactFieldRow(
                        palette: palette,
                        icon: Icons.phone_outlined,
                        label: 'Телефон',
                        value: contact.phone,
                      ),
                      const Divider(height: 18),
                      _ContactFieldRow(
                        palette: palette,
                        icon: Icons.notes_rounded,
                        label: 'Заметка о контакте',
                        value: contact.bioNote,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Связанные сущности экосистемы (письма, общие встречи)
                Text(
                  'СВЯЗАННЫЕ ПИСЬМА И ВСТРЕЧИ',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.85,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                for (final item in related) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OrbitFilledButton(
                      palette: palette,
                      radius: _radius * 0.75,
                      isPrimary: false,
                      compact: true,
                      icon: item.type == 'mail'
                          ? Icons.mark_email_read_outlined
                          : Icons.calendar_today_rounded,
                      label: item.title,
                      subtitle: item.subtitle,
                      onTap: () => _navigateFromContact(context, item.route),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ContactFieldRow extends StatelessWidget {
  const _ContactFieldRow({
    required this.palette,
    required this.icon,
    required this.label,
    required this.value,
  });

  final OrbitPalette palette;
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: palette.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
