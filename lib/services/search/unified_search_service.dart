import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/database/orbit_data_engine.dart';
import 'search_models.dart';

final class UnifiedSearchService extends ChangeNotifier {
  UnifiedSearchService(this._dataEngine);

  final OrbitDataEngine _dataEngine;

  Future<List<SearchResultItem>> search(
    String rawQuery, {
    SearchCategory category = SearchCategory.all,
    String? workspaceId,
    int limit = 50,
  }) async {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];

    // Stem for Russian inflection (remove last character if length > 4)
    final stem = query.length > 4 ? query.substring(0, query.length - 1) : query;

    bool matchesText(String? text) {
      if (text == null || text.isEmpty) return false;
      final lower = text.toLowerCase();
      return lower.contains(query) || lower.contains(stem);
    }

    final results = <SearchResultItem>[];
    final ws = workspaceId;

    // 1. Search Emails
    if (category == SearchCategory.all || category == SearchCategory.email) {
      final emails = await _dataEngine.getEmails(workspaceId: ws);
      for (final email in emails) {
        if (matchesText(email.subject) ||
            matchesText(email.sender) ||
            matchesText(email.preview) ||
            matchesText(email.body)) {
          results.add(
            SearchResultItem(
              id: email.id,
              category: SearchCategory.email,
              workspaceId: email.workspaceId,
              title: email.subject,
              subtitle: email.sender,
              snippet: email.preview.isNotEmpty ? email.preview : email.body,
              timestamp: email.timestamp,
              route: '/mail',
            ),
          );
        }
      }
    }

    // 2. Search Tasks
    if (category == SearchCategory.all || category == SearchCategory.task) {
      final tasks = await _dataEngine.getTasks(workspaceId: ws);
      for (final task in tasks) {
        if (matchesText(task.title) || matchesText(task.project)) {
          results.add(
            SearchResultItem(
              id: task.id,
              category: SearchCategory.task,
              workspaceId: task.workspaceId,
              title: task.title,
              subtitle: task.project ?? 'Без проекта',
              snippet: task.dueDate != null ? 'Срок: ${task.dueDate}' : '',
              timestamp: task.createdAt,
              route: '/tasks/task/${task.id}',
            ),
          );
        }
      }
    }

    // 3. Search Events
    if (category == SearchCategory.all || category == SearchCategory.event) {
      final events = await _dataEngine.getEvents(workspaceId: ws);
      for (final event in events) {
        if (matchesText(event.title) ||
            matchesText(event.location) ||
            matchesText(event.description)) {
          results.add(
            SearchResultItem(
              id: event.id,
              category: SearchCategory.event,
              workspaceId: event.workspaceId,
              title: event.title,
              subtitle: event.location ?? 'Встреча',
              snippet: event.description ?? '',
              timestamp: event.startTime,
              route: '/event/${event.id}',
            ),
          );
        }
      }
    }

    // 4. Search Notes
    if (category == SearchCategory.all || category == SearchCategory.note) {
      final notes = await _dataEngine.getNotes(workspaceId: ws);
      for (final note in notes) {
        final matchesTags = note.tags.any(matchesText);

        if (matchesText(note.title) ||
            matchesText(note.content) ||
            matchesTags) {
          results.add(
            SearchResultItem(
              id: note.id,
              category: SearchCategory.note,
              workspaceId: note.workspaceId,
              title: note.title,
              subtitle: note.tags.isNotEmpty ? note.tags.join(', ') : 'Заметка',
              snippet: note.content,
              timestamp: note.updatedAt,
            ),
          );
        }
      }
    }

    // 5. Search Contacts
    if (category == SearchCategory.all || category == SearchCategory.contact) {
      final contacts = await _dataEngine.getContacts(workspaceId: ws);
      for (final contact in contacts) {
        if (matchesText(contact.name) ||
            matchesText(contact.email) ||
            matchesText(contact.company) ||
            matchesText(contact.role)) {
          results.add(
            SearchResultItem(
              id: contact.id,
              category: SearchCategory.contact,
              workspaceId: contact.workspaceId,
              title: contact.name,
              subtitle: contact.company ?? contact.email,
              snippet: contact.role ?? contact.email,
              timestamp: DateTime.now().toUtc(),
            ),
          );
        }
      }
    }

    // Sort by recency
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (results.length > limit) {
      return results.sublist(0, limit);
    }
    return results;
  }
}
