import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/demo_data.dart';
import '../data/orbit_calendar.dart';
import '../l10n/orbit_localizations.dart';
import '../visual_engine/orbit_palette.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_page.dart';

final class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final event = env.appState.eventById(id);
    if (event == null) {
      return OrbitPage(
        title: context.l10n.eventDetails,
        leading: OrbitBackButton(onTap: () => context.pop()),
        body: Center(child: Text(context.l10n.emptyHere)),
      );
    }

    final palette = env.palette;
    final eventDate = orbitEventDay(event);
    final locale = Localizations.localeOf(context).toString();
    final formattedDate = DateFormat.yMMMMd(locale).format(eventDate);
    final timeSpan = event.endTime != null && event.endTime!.isNotEmpty
        ? '${event.time} — ${event.endTime}'
        : event.time;

    return OrbitPage(
      title: context.l10n.eventDetails,
      subtitle: '$formattedDate · $timeSpan',
      leading: OrbitBackButton(onTap: () => context.pop()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Main Header Card
          GlassPanel(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 38,
                      margin: const EdgeInsets.only(right: 12, top: 4),
                      decoration: BoxDecoration(
                        color: event.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.localizedTitle(context),
                            key: const Key('event-detail-title'),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (event.meta.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.localizedMeta(context),
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: palette.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: context.l10n.calendar,
                  value: formattedDate,
                  palette: palette,
                ),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  label: context.l10n.eventTime,
                  value: timeSpan,
                  palette: palette,
                ),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: context.l10n.eventLocation,
                  value: event.location ?? context.l10n.noLocation,
                  palette: palette,
                ),
              ],
            ),
          ),

          // 2. Online Conference Card (if available)
          if (event.conferenceUrl != null &&
              event.conferenceUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            GlassPanel(
              palette: palette,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.videocam_rounded,
                      color: palette.accent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.eventConference,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          event.conferenceUrl!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    key: const Key('copy-meeting-link'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Clipboard.setData(
                        ClipboardData(text: event.conferenceUrl!),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.linkCopied),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text(context.l10n.joinMeeting),
                  ),
                ],
              ),
            ),
          ],

          // 3. Description
          const SizedBox(height: 20),
          OrbitSectionTitle(context.l10n.eventDescription),
          const SizedBox(height: 8),
          GlassPanel(
            palette: palette,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                event.description != null && event.description!.isNotEmpty
                    ? event.description!
                    : context.l10n.noDescription,
                key: const Key('event-detail-description'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: event.description != null &&
                          event.description!.isNotEmpty
                      ? palette.textPrimary
                      : palette.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ),

          // 4. Organizer
          const SizedBox(height: 20),
          OrbitSectionTitle(context.l10n.eventOrganizer),
          const SizedBox(height: 8),
          GlassPanel(
            palette: palette,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: palette.accent.withValues(alpha: 0.18),
                  child: Text(
                    (event.organizer?.name.isNotEmpty == true
                            ? event.organizer!.name[0]
                            : 'O')
                        .toUpperCase(),
                    style: TextStyle(
                      color: palette.accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.organizer?.name ?? context.l10n.appName,
                        key: const Key('event-organizer-name'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (event.organizer?.email != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.organizer!.email,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: palette.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 5. Attendees
          const SizedBox(height: 20),
          OrbitSectionTitle(
            '${context.l10n.eventAttendees} (${event.attendees.length})',
          ),
          const SizedBox(height: 8),
          GlassPanel(
            palette: palette,
            child: event.attendees.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      context.l10n.noAttendees,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < event.attendees.length; i++) ...[
                        _AttendeeRow(
                          attendee: event.attendees[i],
                          palette: palette,
                        ),
                        if (i != event.attendees.length - 1)
                          const Divider(height: 16),
                      ],
                    ],
                  ),
          ),

          // 6. Attachments
          const SizedBox(height: 20),
          OrbitSectionTitle(
            '${context.l10n.attachments} (${event.attachments.length})',
          ),
          const SizedBox(height: 8),
          GlassPanel(
            palette: palette,
            child: event.attachments.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      context.l10n.noAttachments,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < event.attachments.length; i++) ...[
                        _AttachmentRow(
                          attachment: event.attachments[i],
                          palette: palette,
                        ),
                        if (i != event.attachments.length - 1)
                          const Divider(height: 16),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final String value;
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: palette.textSecondary),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

final class _AttendeeRow extends StatelessWidget {
  const _AttendeeRow({required this.attendee, required this.palette});

  final EventAttendee attendee;
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    final (statusIcon, statusColor, statusLabel) = switch (attendee.status) {
      AttendeeStatus.accepted => (
        Icons.check_circle_rounded,
        Colors.green,
        context.l10n.statusAccepted,
      ),
      AttendeeStatus.declined => (
        Icons.cancel_rounded,
        Colors.redAccent,
        context.l10n.statusDeclined,
      ),
      AttendeeStatus.tentative => (
        Icons.help_rounded,
        Colors.amber,
        context.l10n.statusTentative,
      ),
      AttendeeStatus.unknown => (
        Icons.schedule_rounded,
        palette.textSecondary,
        context.l10n.statusAwaiting,
      ),
    };

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: palette.textPrimary.withValues(alpha: 0.08),
          child: Text(
            attendee.name.isNotEmpty ? attendee.name[0].toUpperCase() : '?',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                attendee.name,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
              Text(
                attendee.email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, size: 12, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment, required this.palette});

  final EventAttachment attachment;
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    final icon = switch (attachment.type.toUpperCase()) {
      'PDF' => Icons.picture_as_pdf_outlined,
      'DOCX' || 'DOC' => Icons.description_outlined,
      'XLSX' || 'XLS' => Icons.table_chart_outlined,
      _ => Icons.insert_drive_file_outlined,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${attachment.name} (${attachment.formattedSize})'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.accentSecondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: palette.accentSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  Text(
                    '${attachment.type.toUpperCase()} · ${attachment.formattedSize}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: palette.textSecondary),
          ],
        ),
      ),
    );
  }
}
