import '../../data/database/orbit_data_engine.dart';
import '../../data/models/note_record.dart';

final class NotesService {
  NotesService({required OrbitDataEngine dataEngine})
      : _dataEngine = dataEngine;

  final OrbitDataEngine _dataEngine;

  Future<List<NoteRecord>> getNotes({
    String? workspaceId,
    String? tagFilter,
  }) async {
    final notes = await _dataEngine.getNotes(workspaceId: workspaceId);
    if (tagFilter == null || tagFilter.isEmpty) {
      return notes;
    }
    final filterLower = tagFilter.toLowerCase().trim();
    return notes
        .where((n) => n.tags.any((t) => t.toLowerCase() == filterLower))
        .toList();
  }

  Future<NoteRecord?> getNoteById(String noteId, {String? workspaceId}) async {
    final notes = await _dataEngine.getNotes(workspaceId: workspaceId);
    for (final n in notes) {
      if (n.id == noteId) return n;
    }
    return null;
  }

  Future<NoteRecord> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
    String? workspaceId,
  }) async {
    final id = 'note_${DateTime.now().millisecondsSinceEpoch}_${title.hashCode.abs()}';
    final note = NoteRecord(
      id: id,
      workspaceId: workspaceId ?? _dataEngine.activeWorkspaceId,
      title: title.trim(),
      content: content.trim(),
      tags: tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
      updatedAt: DateTime.now(),
    );

    await _dataEngine.saveNote(note);
    return note;
  }

  Future<void> updateNote(NoteRecord note) async {
    final updated = note.copyWith(updatedAt: DateTime.now());
    await _dataEngine.saveNote(updated);
  }

  Future<void> deleteNote(String noteId) async {
    await _dataEngine.deleteNote(noteId);
  }

  Future<List<NoteRecord>> searchNotes(String query, {String? workspaceId}) async {
    final cleanQuery = query.toLowerCase().trim();
    if (cleanQuery.isEmpty) return getNotes(workspaceId: workspaceId);

    final notes = await _dataEngine.getNotes(workspaceId: workspaceId);
    return notes.where((note) {
      final matchesTitle = note.title.toLowerCase().contains(cleanQuery);
      final matchesContent = note.content.toLowerCase().contains(cleanQuery);
      final matchesTag = note.tags.any((t) => t.toLowerCase().contains(cleanQuery));
      return matchesTitle || matchesContent || matchesTag;
    }).toList();
  }

  Future<Set<String>> getAllTags({String? workspaceId}) async {
    final notes = await _dataEngine.getNotes(workspaceId: workspaceId);
    final tags = <String>{};
    for (final note in notes) {
      tags.addAll(note.tags);
    }
    return tags;
  }
}
