import 'package:flutter/material.dart';

import '../l10n/orbit_localizations.dart';

final class EventEditorResult {
  const EventEditorResult({required this.title, required this.time});
  final String title;
  final String time;
}

Future<EventEditorResult?> showOrbitEventEditor(BuildContext context) {
  return showDialog<EventEditorResult>(
    context: context,
    builder: (_) => const _EventEditorDialog(),
  );
}

final class _EventEditorDialog extends StatefulWidget {
  const _EventEditorDialog();

  @override
  State<_EventEditorDialog> createState() => _EventEditorDialogState();
}

final class _EventEditorDialogState extends State<_EventEditorDialog> {
  late final TextEditingController _title;
  TimeOfDay _time = const TimeOfDay(hour: 10, minute: 0);

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  String _formattedTime() =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const Key('add-event-dialog'),
    title: Text(context.l10n.newEvent),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          key: const Key('new-event-title'),
          controller: _title,
          autofocus: true,
          maxLength: 120,
          decoration: InputDecoration(hintText: context.l10n.eventTitleHint),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('event-time-button'),
          onPressed: () async {
            final selected = await showTimePicker(
              context: context,
              initialTime: _time,
            );
            if (selected != null) setState(() => _time = selected);
          },
          icon: const Icon(Icons.schedule_outlined),
          label: Text('${context.l10n.eventTime}: ${_formattedTime()}'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.cancel),
      ),
      FilledButton(
        key: const Key('confirm-add-event'),
        onPressed: () => Navigator.of(
          context,
        ).pop(EventEditorResult(title: _title.text, time: _formattedTime())),
        child: Text(context.l10n.add),
      ),
    ],
  );
}
