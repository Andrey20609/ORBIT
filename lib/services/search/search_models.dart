import 'package:flutter/foundation.dart';

enum SearchCategory {
  all,
  email,
  task,
  event,
  note,
  contact;

  String get displayName => switch (this) {
    SearchCategory.all => 'Все',
    SearchCategory.email => 'Почта',
    SearchCategory.task => 'Задачи',
    SearchCategory.event => 'Календарь',
    SearchCategory.note => 'Заметки',
    SearchCategory.contact => 'Контакты',
  };
}

@immutable
final class SearchResultItem {
  const SearchResultItem({
    required this.id,
    required this.category,
    required this.workspaceId,
    required this.title,
    required this.subtitle,
    required this.snippet,
    required this.timestamp,
    this.route,
  });

  final String id;
  final SearchCategory category;
  final String workspaceId;
  final String title;
  final String subtitle;
  final String snippet;
  final DateTime timestamp;
  final String? route;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchResultItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          workspaceId == other.workspaceId &&
          title == other.title;

  @override
  int get hashCode => Object.hash(id, category, workspaceId, title);
}
