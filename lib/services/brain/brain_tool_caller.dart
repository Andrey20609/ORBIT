import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/database/orbit_data_engine.dart';
import '../../data/models/event_record.dart';
import '../../data/models/task_record.dart';
import '../../state/app_state.dart';
import '../mail/mail_connection_verifier.dart';

@immutable
final class BrainActionProposal {
  const BrainActionProposal({
    required this.id,
    required this.toolName,
    required this.arguments,
    this.isApproved = false,
  });

  final String id;
  final String toolName;
  final Map<String, Object?> arguments;
  final bool isApproved;

  BrainActionProposal copyWith({bool? isApproved}) {
    return BrainActionProposal(
      id: id,
      toolName: toolName,
      arguments: arguments,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  /// Выполнение действия над базой данных OrbitDataEngine.
  Future<bool> execute(OrbitDataEngine dataEngine) async {
    if (!isApproved) {
      throw StateError(
        'Action proposal "$toolName" requires explicit user confirmation before execution.',
      );
    }

    switch (toolName) {
      case 'createTask':
        final title = arguments['title']! as String;
        final project = arguments['project'] as String?;
        final due = arguments['due'] as String?;
        final task = TaskRecord(
          id: 'brain-task-${DateTime.now().millisecondsSinceEpoch}',
          workspaceId: dataEngine.activeWorkspaceId,
          title: title,
          project: project,
          dueDate: due,
          createdAt: DateTime.now().toUtc(),
        );
        await dataEngine.saveTask(task);
        return true;

      case 'scheduleMeeting':
        final title = arguments['title']! as String;
        final startStr = arguments['start'] as String?;
        final startTime = startStr != null
            ? DateTime.tryParse(startStr) ?? DateTime.now()
            : DateTime.now();
        final endTime = startTime.add(const Duration(hours: 1));
        final event = EventRecord(
          id: 'brain-event-${DateTime.now().millisecondsSinceEpoch}',
          workspaceId: dataEngine.activeWorkspaceId,
          title: title,
          startTime: startTime,
          endTime: endTime,
          location: arguments['location'] as String?,
        );
        await dataEngine.saveEvent(event);
        return true;

      case 'markEmailRead':
        final emailId = arguments['emailId']! as String;
        await dataEngine.setEmailRead(emailId, true);
        return true;

      default:
        throw UnsupportedError('Unknown tool: $toolName');
    }
  }

  /// Выполнение действия над живым состоянием OrbitAppState в экосистеме.
  Future<bool> executeOnAppState(OrbitAppState appState) async {
    if (!isApproved) {
      throw StateError(
        'Action proposal "$toolName" requires explicit user confirmation before execution.',
      );
    }

    switch (toolName) {
      case 'createTask':
        final title = arguments['title']! as String;
        appState.addTask(title);
        return true;

      case 'scheduleMeeting':
        final title = arguments['title']! as String;
        final time = (arguments['time'] as String?) ?? (arguments['start'] as String?) ?? '14:00';
        appState.addEvent(title, time, DateTime.now());
        return true;

      case 'composeMailDraft':
        final to = (arguments['to'] as String?) ?? '';
        final subject = (arguments['subject'] as String?) ?? '';
        final body = (arguments['body'] as String?) ?? '';
        appState.updateDraft(to: to, subject: subject, body: body);
        return true;

      case 'markEmailRead':
        final emailId = arguments['emailId']! as String;
        appState.markRead(emailId);
        return true;

      case 'verifyMailHealth':
        final activeAcc = appState.activeMailAccount;
        final verifier = OrbitMailConnectionVerifier();
        final res = await verifier.verifyConnection(
          host: activeAcc.incomingHost.isNotEmpty ? activeAcc.incomingHost : 'imap.yandex.ru',
          port: activeAcc.incomingPort,
          useSsl: activeAcc.useIncomingSsl,
        );
        appState.updateMailAccount(
          activeAcc.copyWith(
            status: res.isSuccess ? OrbitMailAccountStatus.verified : OrbitMailAccountStatus.failed,
            lastLatencyMs: res.isSuccess ? res.latencyMs : null,
            lastVerifiedAtIso: DateTime.now().toIso8601String(),
            lastError: res.isSuccess ? null : res.errorMessage,
          ),
        );
        return true;

      default:
        throw UnsupportedError('Unknown tool: $toolName');
    }
  }
}
