import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:go_router/go_router.dart';

import '../data/demo_data.dart';
import '../l10n/orbit_localizations.dart';
import '../visual_engine/orbit_visual_engine.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_page.dart';

export 'task_detail_screen.dart';

final class TasksScreen extends StatefulWidget {
  const TasksScreen({this.openAdd = false, super.key});
  final bool openAdd;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

enum TaskSortOrder { date, priority, title }

final class _TasksScreenState extends State<TasksScreen> {
  int _filter = 0;
  TaskSortOrder _sortOrder = TaskSortOrder.date;
  bool _hideCompleted = false;

  @override
  void initState() {
    super.initState();
    if (widget.openAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAddDialog());
    }
  }

  void _showTasksMenu() {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              margin: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 28 + MediaQuery.paddingOf(ctx).bottom,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceStrong.withValues(
                  alpha: palette.isLight ? 0.96 : 0.92,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: palette.isLight
                      ? Colors.black.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.transparent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: palette.textSecondary.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 20, color: palette.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Опции задач',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: palette.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'СОРТИРОВКА',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: palette.textSecondary.withValues(alpha: 0.8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildSortChip(TaskSortOrder.date, 'По сроку', Icons.schedule_rounded, palette, setSheetState),
                          _buildSortChip(TaskSortOrder.priority, 'Важные', Icons.star_rounded, palette, setSheetState),
                          _buildSortChip(TaskSortOrder.title, 'А–Я', Icons.sort_by_alpha_rounded, palette, setSheetState),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(color: palette.textPrimary.withValues(alpha: 0.08), height: 1),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Скрыть выполненные',
                          style: TextStyle(fontSize: 14, color: palette.textPrimary),
                        ),
                        value: _hideCompleted,
                        activeThumbColor: palette.accent,
                        onChanged: (val) {
                          setSheetState(() => _hideCompleted = val);
                          setState(() => _hideCompleted = val);
                        },
                      ),
                      Divider(color: palette.textPrimary.withValues(alpha: 0.08), height: 1),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.done_all_rounded, color: palette.accent, size: 22),
                        title: Text('Отметить все как выполненные', style: TextStyle(fontSize: 14, color: palette.textPrimary)),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          env.appState.markAllTasksDone();
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 22),
                        title: const Text('Очистить выполненные задачи', style: TextStyle(fontSize: 14, color: Color(0xFFEF4444))),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          env.appState.clearCompletedTasks();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        );
      },
    );
  }

  Widget _buildSortChip(
    TaskSortOrder order,
    String label,
    IconData icon,
    OrbitPalette palette,
    void Function(void Function()) setSheetState,
  ) {
    final selected = _sortOrder == order;
    return ChoiceChip(
      selected: selected,
      avatar: Icon(icon, size: 16, color: selected ? Colors.white : palette.textSecondary),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? Colors.white : palette.textPrimary,
      ),
      selectedColor: palette.accent,
      backgroundColor: palette.surface.withValues(alpha: 0.45),
      side: BorderSide(
        color: selected ? palette.accent : palette.textPrimary.withValues(alpha: 0.12),
      ),
      onSelected: (_) {
        setSheetState(() => _sortOrder = order);
        setState(() => _sortOrder = order);
      },
    );
  }

  Future<void> _showAddDialog() async {
    if (!mounted) return;
    final result = await showDialog<String>(
      context: context,
      builder: (_) => const _AddTaskDialog(),
    );
    if (result != null && mounted) {
      OrbitEnvironment.read(context).appState.addTask(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final palette = env.palette;
    final tasks = env.appState.tasks;
    var visible = switch (_filter) {
      1 => tasks.where((task) => !task.done).toList(),
      2 => tasks.where((task) => !task.id.startsWith('local-')).toList(),
      _ => tasks.toList(),
    };
    if (_hideCompleted) {
      visible = visible.where((t) => !t.done).toList();
    }
    switch (_sortOrder) {
      case TaskSortOrder.priority:
        visible.sort((a, b) => b.priority.compareTo(a.priority));
      case TaskSortOrder.title:
        visible.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case TaskSortOrder.date:
        break;
    }
    final progress = tasks.isEmpty
        ? 0.0
        : env.appState.completedTasks / tasks.length;

    final filterLabels = [
      context.l10n.today,
      'Неделя',
      context.l10n.projects,
    ];

    return OrbitPage(
      title: context.l10n.tasks,
      subtitle: context.l10n.completedOf(
        env.appState.completedTasks,
        tasks.length,
      ),
      actions: [
        OrbitIconButton(
          palette: palette,
          icon: Icons.search_rounded,
          tooltip: 'Поиск',
          onTap: () => context.push('/search'),
        ),
        OrbitIconButton(
          key: const Key('tasks-more-button'),
          palette: palette,
          icon: Icons.more_horiz_rounded,
          tooltip: 'Ещё',
          onTap: _showTasksMenu,
        ),
      ],
      floatingActionButton: OrbitFab(
        palette: palette,
        buttonKey: const Key('add-task-fab'),
        tooltip: context.l10n.addTask,
        onTap: _showAddDialog,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Pills Row
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filterLabels.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final isSelected = _filter == index;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: filterLabels[index],
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: Key('task-filter-$index'),
                      borderRadius: BorderRadius.circular(19),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [
                                    palette.accent,
                                    palette.accentSecondary,
                                  ],
                                )
                              : null,
                          color: isSelected
                              ? null
                              : palette.surface.withValues(
                                  alpha: palette.isLight ? 0.65 : 0.25,
                                ),
                          borderRadius: BorderRadius.circular(19),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : palette.isLight
                                    ? Colors.black.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.12),
                            width: 0.75,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: palette.accent.withValues(
                                      alpha: palette.isLight ? 0.28 : 0.45,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            filterLabels[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : palette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Progress Card
          GlassPanel(
            palette: palette,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.l10n.progressDay,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    key: const Key('task-progress'),
                    value: progress,
                    minHeight: 6,
                    backgroundColor: palette.textSecondary.withValues(
                      alpha: 0.15,
                    ),
                    valueColor: AlwaysStoppedAnimation(palette.accentSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Task List Container
          GlassPanel(
            palette: palette,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  _TaskRow(
                    task: visible[i],
                    palette: palette,
                    onChanged: () => env.appState.toggleTask(visible[i].id),
                  ),
                  if (i < visible.length - 1)
                    Divider(
                      height: 1,
                      thickness: 0.5,
                      indent: 44,
                      color: palette.isLight
                          ? Colors.black.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bottom Quick Add Button (accessible inside scrollable)
          Center(
            child: OutlinedButton.icon(
              key: const Key('add-task-bottom'),
              onPressed: _showAddDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.textPrimary,
                side: BorderSide(
                  color: palette.isLight
                      ? Colors.black.withValues(alpha: 0.10)
                      : Colors.white.withValues(alpha: 0.16),
                  width: 0.75,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(context.l10n.quickAdd),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

final class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

final class _AddTaskDialogState extends State<_AddTaskDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('add-task-dialog'),
      title: Text(context.l10n.newTask),
      content: TextField(
        key: const Key('new-task-title'),
        controller: _controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(hintText: context.l10n.taskHint),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('confirm-add-task'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(context.l10n.add),
        ),
      ],
    );
  }
}

final class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.palette,
    required this.onChanged,
  });
  final DemoTask task;
  final OrbitPalette palette;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isDueToday = task.due.contains('Сегодня') || task.due.contains('17:00');
    final dueColor = task.done
        ? palette.textSecondary.withValues(alpha: 0.6)
        : isDueToday
            ? const Color(0xFFFF6E6E)
            : palette.textSecondary;

    return Semantics(
      button: true,
      selected: task.done,
      label: '${task.localizedTitle(context)}, ${task.localizedDue(context)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('task-${task.id}'),
          onTap: () => context.push('/tasks/task/${task.id}'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
            child: Row(
              children: [
                // Custom Rounded Checkbox
                GestureDetector(
                  key: Key('task-toggle-${task.id}'),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onChanged();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: task.done
                          ? LinearGradient(
                              colors: [
                                palette.accent,
                                palette.accentSecondary,
                              ],
                            )
                          : null,
                      color: task.done
                          ? null
                          : palette.isLight
                              ? Colors.black.withValues(alpha: 0.04)
                              : Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: task.done
                            ? Colors.transparent
                            : palette.textSecondary.withValues(
                                alpha: palette.isLight ? 0.35 : 0.40,
                              ),
                        width: 1.5,
                      ),
                      boxShadow: task.done
                          ? [
                              BoxShadow(
                                color: palette.accent.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: task.done
                        ? const Icon(
                            Icons.check_rounded,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),

                // Title and Subtitle / Due
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.localizedTitle(context),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              decoration: task.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: task.done
                                  ? palette.textSecondary
                                  : palette.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${task.localizedProject(context)} · ${task.localizedDue(context)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isDueToday && !task.done
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: dueColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // Priority Indicator
                if (task.priority > 0) ...[
                  const SizedBox(width: 8),
                  Icon(
                    task.priority == 2
                        ? Icons.star_rounded
                        : Icons.flag_rounded,
                    size: 20,
                    color: task.priority == 2
                        ? const Color(0xFFFFB800)
                        : palette.accentSecondary,
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
