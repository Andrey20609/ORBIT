import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/orbit_localizations.dart';
import '../widgets/glass_panel.dart';
import '../widgets/orbit_environment.dart';
import '../widgets/orbit_page.dart';

final class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    final env = OrbitEnvironment.of(context);
    final task = env.appState.taskById(id);
    if (task == null) {
      return OrbitPage(
        title: context.l10n.taskDetails,
        leading: OrbitBackButton(onTap: () => context.pop()),
        body: Center(child: Text(context.l10n.emptyHere)),
      );
    }
    final palette = env.palette;
    final priorities = [
      context.l10n.priorityLow,
      context.l10n.priorityMedium,
      context.l10n.priorityHigh,
    ];
    return OrbitPage(
      title: context.l10n.taskDetails,
      subtitle: task.localizedProject(context),
      leading: OrbitBackButton(onTap: () => context.pop()),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassPanel(
            palette: palette,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.localizedTitle(context),
                  key: const Key('task-detail-title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 20),
                _DetailRow(
                  icon: Icons.folder_outlined,
                  label: context.l10n.projects,
                  value: task.localizedProject(context),
                ),
                _DetailRow(
                  icon: Icons.schedule_outlined,
                  label: context.l10n.eventTime,
                  value: task.localizedDue(context),
                ),
                _DetailRow(
                  icon: task.done
                      ? Icons.check_circle_outline
                      : Icons.radio_button_unchecked,
                  label: context.l10n.status,
                  value: task.done ? context.l10n.done : context.l10n.active,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OrbitSectionTitle(context.l10n.priority),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var priority = 0; priority < 3; priority++)
                ChoiceChip(
                  key: Key('task-priority-$priority'),
                  label: Text(priorities[priority]),
                  selected: task.priority == priority,
                  onSelected: (_) =>
                      env.appState.setTaskPriority(task.id, priority),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('toggle-task-status'),
            onPressed: () => env.appState.toggleTask(task.id),
            icon: Icon(task.done ? Icons.undo : Icons.check),
            label: Text(
              task.done ? context.l10n.markActive : context.l10n.markDone,
            ),
          ),
        ],
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 3),
              Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ],
          ),
        ),
      ],
    ),
  );
}
