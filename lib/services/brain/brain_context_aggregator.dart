import 'dart:async';

import '../../data/database/orbit_data_engine.dart';
import '../../data/demo_data.dart';
import '../../state/app_state.dart';
import 'privacy_guardrails.dart';

final class BrainContextAggregator {
  const BrainContextAggregator(this._dataEngine);

  final OrbitDataEngine _dataEngine;

  /// Собирает контекст из базы данных OrbitDataEngine.
  Future<Map<String, Object?>> buildAggregatedContext({
    String? workspaceId,
  }) async {
    final ws = workspaceId ?? _dataEngine.activeWorkspaceId;

    // 1. Gather active tasks
    final tasks = await _dataEngine.getTasks(workspaceId: ws);
    final pendingTasks = tasks.where((t) => !t.isDone).take(5).map((t) {
      return {
        'id': t.id,
        'title': PrivacyGuardrails.sanitizeText(t.title),
        'project': t.project,
        'due': t.dueDate,
      };
    }).toList();

    // 2. Gather today's events
    final events = await _dataEngine.getEvents(workspaceId: ws);
    final upcomingEvents = events.take(4).map((e) {
      return {
        'id': e.id,
        'title': PrivacyGuardrails.sanitizeText(e.title),
        'location': e.location != null
            ? PrivacyGuardrails.sanitizeText(e.location!)
            : null,
        'time': e.startTime.toIso8601String(),
      };
    }).toList();

    // 3. Gather unread emails
    final emails = await _dataEngine.getEmails(workspaceId: ws);
    final unreadEmails = emails.where((e) => !e.isRead).take(5).map((e) {
      return {
        'id': e.id,
        'sender': PrivacyGuardrails.sanitizeText(e.sender),
        'subject': PrivacyGuardrails.sanitizeText(e.subject),
        'preview': PrivacyGuardrails.sanitizeText(e.preview),
      };
    }).toList();

    return {
      'workspaceId': ws,
      'pendingTasksCount': tasks.where((t) => !t.isDone).length,
      'tasks': pendingTasks,
      'events': upcomingEvents,
      'unreadEmailsCount': emails.where((e) => !e.isRead).length,
      'unreadEmails': unreadEmails,
    };
  }

  /// Собирает динамический контекст экосистемы напрямую из OrbitAppState.
  static Map<String, Object?> buildFromAppState(OrbitAppState appState) {
    final pendingTasks = appState.tasks.where((t) => !t.done).toList();
    final urgentTasks = pendingTasks.where((t) => t.priority >= 2).toList();
    final events = appState.events;
    final unreadCount = appState.badgeCountForFolder(OrbitMailFolder.inbox);
    final activeAccount = appState.activeMailAccount;

    return {
      'pendingTasksCount': pendingTasks.length,
      'urgentTasksCount': urgentTasks.length,
      'eventsCount': events.length,
      'nextMeeting': events.isNotEmpty
          ? '${PrivacyGuardrails.sanitizeText(events.first.title)} • ${events.first.time}'
          : 'Свободно на сегодня',
      'unreadEmailsCount': unreadCount,
      'activeMailAccount': {
        'id': activeAccount.id,
        'name': PrivacyGuardrails.sanitizeText(activeAccount.name),
        'email': PrivacyGuardrails.sanitizeText(activeAccount.email),
        'provider': activeAccount.provider,
        'status': activeAccount.status.name,
        'latencyMs': activeAccount.lastLatencyMs,
        'isVerified': activeAccount.status == OrbitMailAccountStatus.verified,
      },
    };
  }
}
