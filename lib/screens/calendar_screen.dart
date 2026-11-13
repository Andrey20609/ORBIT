import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../data/demo_data.dart';
import '../data/orbit_calendar.dart';
import '../l10n/orbit_localizations.dart';
import '../visual_engine/orbit_visual_engine.dart';
import '../widgets/event_list.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_page.dart';
import 'event_editor.dart';

String _calendarDayKey(DateTime value) => orbitDayKey(value);

final class CalendarScreen extends StatefulWidget {
  const CalendarScreen({this.openAdd = false, super.key});

  final bool openAdd;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

final class _CalendarScreenState extends State<CalendarScreen> {
  int _mode = 1;
  late DateTime _selected = clock.now();

  @override
  void initState() {
    super.initState();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAddDialog());
    }
  }

  Future<void> _showAddDialog() async {
    if (!mounted) return;
    final result = await showOrbitEventEditor(context);
    if (result == null || !mounted || result.title.trim().isEmpty) return;
    OrbitEnvironment.read(
      context,
    ).appState.addEvent(result.title, result.time, _selected);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.eventCreated)));
  }

  void _selectDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    if (DateUtils.isSameDay(normalized, _selected)) return;
    setState(() => _selected = normalized);
  }

  void _shiftDate(int direction) {
    setState(() {
      if (_mode == 2) {
        final target = DateTime(_selected.year, _selected.month + direction);
        final lastDay = DateTime(target.year, target.month + 1, 0).day;
        _selected = DateTime(
          target.year,
          target.month,
          _selected.day > lastDay ? lastDay : _selected.day,
        );
      } else {
        _selected = _selected.add(
          Duration(days: direction * (_mode == 1 ? 7 : 1)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = OrbitEnvironment.of(context).palette;
    return OrbitPage(
      title: context.l10n.calendar,
      subtitle: DateFormat(
        'LLLL yyyy',
        Localizations.localeOf(context).toLanguageTag(),
      ).format(_selected),
      actions: [
        OrbitIconButton(
          palette: palette,
          icon: Icons.search_rounded,
          tooltip: context.l10n.search,
          onTap: () => context.push('/search'),
        ),
        const SizedBox(width: 4),
        OrbitIconButton(
          palette: palette,
          icon: Icons.today_outlined,
          tooltip: context.l10n.today,
          onTap: () => setState(() => _selected = clock.now()),
        ),
        const SizedBox(width: 4),
        OrbitIconButton(
          palette: palette,
          icon: Icons.add_rounded,
          tooltip: context.l10n.newEvent,
          onTap: _showAddDialog,
        ),
      ],
      floatingActionButton: Transform.translate(
        offset: const Offset(0, 24),
        child: OrbitFab(
          palette: palette,
          buttonKey: const Key('add-event-fab'),
          tooltip: context.l10n.newEvent,
          onTap: _showAddDialog,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            key: const Key('calendar-modes'),
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, label) in [
                (0, context.l10n.day),
                (1, context.l10n.week),
                (2, context.l10n.month),
                (3, context.l10n.agenda),
              ])
                ChoiceChip(
                  key: Key('calendar-mode-$index'),
                  label: Text(label),
                  selected: _mode == index,
                  onSelected: (_) => setState(() => _mode = index),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const Key('calendar-previous'),
                onPressed: () => _shiftDate(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Flexible(
                child: Text(
                  DateFormat(
                    'd MMMM y',
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(_selected),
                  key: Key(
                    'calendar-header-date-${_calendarDayKey(_selected)}',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              IconButton(
                key: const Key('calendar-next'),
                onPressed: () => _shiftDate(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_mode == 1)
            _WeekStrip(
              selected: _selected,
              palette: palette,
              onDateSelected: _selectDate,
            ),
          if (_mode == 2)
            _MonthGrid(
              selected: _selected,
              palette: palette,
              onDateSelected: _selectDate,
            ),
          if (_mode == 0) _DaySummary(palette: palette),
          if (_mode != 3) ...[
            const SizedBox(height: 22),
            OrbitSectionTitle(
              DateFormat(
                'EEEE, d MMMM',
                Localizations.localeOf(context).toLanguageTag(),
              ).format(_selected),
            ),
            const SizedBox(height: 10),
            EventList(palette: palette, selectedDate: _selected),
          ] else ...[
            const SizedBox(height: 22),
            OrbitSectionTitle(context.l10n.allUpcoming),
            const SizedBox(height: 10),
            EventList(palette: palette),
            const SizedBox(height: 12),
            GlassPanel(
              palette: palette,
              child: Row(
                children: [
                  Icon(Icons.spa_outlined, color: palette.accentSecondary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(context.l10n.freeTomorrow)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.selected,
    required this.palette,
    required this.onDateSelected,
  });
  final DateTime selected;
  final OrbitPalette palette;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final monday = selected.subtract(Duration(days: selected.weekday - 1));
    final locale = Localizations.localeOf(context).toLanguageTag();
    return GlassPanel(
      palette: palette,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selected.weekday - 1,
                label: DateFormat(
                  'd MMMM y',
                  locale,
                ).format(monday.add(Duration(days: i))),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key(
                      'week-day-${_calendarDayKey(monday.add(Duration(days: i)))}',
                    ),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => onDateSelected(monday.add(Duration(days: i))),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: i == selected.weekday - 1
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  palette.accent,
                                  palette.accentSecondary,
                                ],
                              )
                            : null,
                        color: i == selected.weekday - 1
                            ? null
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: i == selected.weekday - 1
                            ? [
                                BoxShadow(
                                  color: palette.accent.withValues(
                                    alpha: palette.isLight ? 0.28 : 0.45,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat(
                              'EEEEE',
                              locale,
                            ).format(monday.add(Duration(days: i))),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: i == selected.weekday - 1
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: i == selected.weekday - 1
                                  ? Colors.white
                                  : palette.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${monday.add(Duration(days: i)).day}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: i == selected.weekday - 1
                                  ? Colors.white
                                  : palette.textPrimary,
                            ),
                          ),
                          if (i == selected.weekday - 1)
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

final class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.selected,
    required this.palette,
    required this.onDateSelected,
  });
  final DateTime selected;
  final OrbitPalette palette;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(selected.year, selected.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.75;
    return GlassPanel(
      palette: palette,
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      DateFormat(
                        'EEEEE',
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(start.add(Duration(days: i))),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: largeText ? 0.48 : 0.9,
            ),
            itemCount: 42,
            itemBuilder: (_, index) {
              final date = start.add(Duration(days: index));
              final isSelected = DateUtils.isSameDay(date, selected);
              final inMonth = date.month == selected.month;
              return Semantics(
                button: true,
                selected: isSelected,
                label: DateFormat(
                  'd MMMM y',
                  Localizations.localeOf(context).toLanguageTag(),
                ).format(date),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: Key('month-day-${_calendarDayKey(date)}'),
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onDateSelected(date),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? palette.accent.withValues(alpha: 0.28)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 12,
                              color: inMonth
                                  ? palette.textPrimary
                                  : palette.textSecondary.withValues(
                                      alpha: 0.45,
                                    ),
                            ),
                          ),
                          if (inMonth && [4, 6, 12, 19].contains(date.day))
                            Icon(
                              Icons.circle,
                              size: 4,
                              color: demoEvents[date.day % 3].color,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

final class _DaySummary extends StatelessWidget {
  const _DaySummary({required this.palette});
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      palette: palette,
      child: Row(
        children: [
          _TimeBlock(
            label: '09',
            subtitle: context.l10n.morning,
            palette: palette,
          ),
          _TimeBlock(
            label: '03',
            subtitle: context.l10n.events,
            palette: palette,
          ),
          _TimeBlock(
            label: '02',
            subtitle: context.l10n.focusHours,
            palette: palette,
          ),
        ],
      ),
    );
  }
}

final class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.label,
    required this.subtitle,
    required this.palette,
  });
  final String label;
  final String subtitle;
  final OrbitPalette palette;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: palette.accentSecondary,
            ),
          ),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.labelSmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
