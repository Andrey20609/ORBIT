import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/demo_data.dart';
import '../data/orbit_calendar.dart';
import '../l10n/orbit_localizations.dart';
import '../visual_engine/orbit_palette.dart';
import 'glass_panel.dart';
import 'orbit_environment.dart';

final class EventList extends StatelessWidget {
  const EventList({
    required this.palette,
    this.compact = false,
    this.selectedDate,
    super.key,
  });
  final OrbitPalette palette;
  final bool compact;
  final DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    final all = OrbitEnvironment.of(context).appState.events;
    final events = selectedDate == null
        ? orbitSortedEvents(all)
        : orbitEventsOn(all, selectedDate!);
    if (events.isEmpty) {
      return GlassPanel(
        palette: palette,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 14 : 16,
          vertical: compact ? 14 : 20,
        ),
        child: Row(
          children: [
            Icon(Icons.event_available_outlined, color: palette.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.emptyHere,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }
    return GlassPanel(
      palette: palette,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++) ...[
            _EventRow(event: events[i], palette: palette, compact: compact),
            if (i != events.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  indent: 62,
                  color: palette.isLight
                      ? Colors.black.withValues(alpha: 0.05)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

final class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.palette,
    this.compact = false,
  });
  final DemoEvent event;
  final OrbitPalette palette;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.25;
    final time = Text(
      event.time,
      maxLines: 1,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: palette.textPrimary,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
    final title = Text(
      event.localizedTitle(context),
      maxLines: largeText ? 3 : 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
        letterSpacing: -0.1,
      ),
    );
    final meta = Text(
      event.localizedMeta(context),
      maxLines: largeText ? 3 : 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 11.5,
        color: palette.textSecondary.withValues(alpha: 0.9),
      ),
    );
    final marker = Container(
      width: largeText ? 36 : 3.5,
      height: largeText ? 3.5 : 34,
      margin: largeText
          ? const EdgeInsets.only(left: 10)
          : const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: event.color,
        borderRadius: BorderRadius.circular(2.5),
        boxShadow: [
          BoxShadow(
            color: event.color.withValues(alpha: palette.isLight ? 0.35 : 0.6),
            blurRadius: 5,
            offset: const Offset(0, 0.5),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: '${event.time}, ${event.localizedTitle(context)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('event-row-${event.id}'),
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.push('/event/${event.id}'),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 4,
              vertical: compact ? 8 : 10,
            ),
            child: largeText
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [time, marker]),
                      const SizedBox(height: 6),
                      title,
                      const SizedBox(height: 3),
                      meta,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 50,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: time,
                        ),
                      ),
                      marker,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [title, const SizedBox(height: 3), meta],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
