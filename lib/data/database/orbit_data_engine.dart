import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/contact_record.dart';
import '../models/email_record.dart';
import '../models/event_record.dart';
import '../models/file_record.dart';
import '../models/note_record.dart';
import '../models/task_record.dart';
import '../models/workspace_record.dart';
import 'orbit_database.dart';

final class OrbitDataEngine extends ChangeNotifier {
  OrbitDataEngine(this._db);

  final OrbitDatabase _db;
  String _activeWorkspaceId = 'workspace-work';
  bool _initialized = false;

  String get activeWorkspaceId => _activeWorkspaceId;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    await _db.open();
    _initialized = true;
    notifyListeners();
  }

  Future<void> ensureInitialized() async {
    if (!_initialized || !_db.isOpen) {
      await initialize();
    }
  }

  void setActiveWorkspace(String workspaceId) {
    if (_activeWorkspaceId == workspaceId) return;
    _activeWorkspaceId = workspaceId;
    notifyListeners();
  }

  /// Runs [action] inside a database transaction. On any error the whole
  /// batch is rolled back; successful completion commits atomically.
  /// Used by [OrbitLocalStateMigrator]; does not change the app flow.
  Future<T> runInTransaction<T>(Future<T> Function() action) {
    return _db.transaction((_) => action());
  }

  // --- Workspaces ---

  Future<List<WorkspaceRecord>> getWorkspaces() async {
    await ensureInitialized();
    final rows = await _db.query(
      OrbitDatabaseSchema.tableWorkspaces,
      orderBy: 'created_at ASC',
    );
    return rows.map(WorkspaceRecord.fromMap).toList();
  }

  Future<void> saveWorkspace(WorkspaceRecord workspace) async {
    await ensureInitialized();
    await _db.insert(
      OrbitDatabaseSchema.tableWorkspaces,
      workspace.toMap(),
      replaceOnConflict: true,
    );
    notifyListeners();
  }

  // --- Tasks ---

  Future<List<TaskRecord>> getTasks({String? workspaceId}) async {
    await ensureInitialized();
    final ws = workspaceId ?? _activeWorkspaceId;
    final rows = await _db.query(
      OrbitDatabaseSchema.tableTasks,
      where: ws.isEmpty ? null : 'workspace_id = ?',
      whereArgs: ws.isEmpty ? null : [ws],
      orderBy: 'created_at DESC',
    );
    return rows.map(TaskRecord.fromMap).toList();
  }

  Future<void> saveTask(TaskRecord task) async {
    await ensureInitialized();
    await _db.insert(
      OrbitDatabaseSchema.tableTasks,
      task.toMap(),
      replaceOnConflict: true,
    );
    notifyListeners();
  }

  Future<void> setTaskDone(String taskId, bool isDone) async {
    await ensureInitialized();
    await _db.update(
      OrbitDatabaseSchema.tableTasks,
      {'is_done': isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [taskId],
    );
    notifyListeners();
  }

  Future<void> deleteTask(String taskId) async {
    await ensureInitialized();
    await _db.delete(
      OrbitDatabaseSchema.tableTasks,
      where: 'id = ?',
      whereArgs: [taskId],
    );
    notifyListeners();
  }

  // --- Events ---

  Future<List<EventRecord>> getEvents({String? workspaceId}) async {
    await ensureInitialized();
    final ws = workspaceId ?? _activeWorkspaceId;
    final rows = await _db.query(
      OrbitDatabaseSchema.tableEvents,
      where: ws.isEmpty ? null : 'workspace_id = ?',
      whereArgs: ws.isEmpty ? null : [ws],
      orderBy: 'start_time ASC',
    );
    return rows.map(EventRecord.fromMap).toList();
  }

  Future<void> saveEvent(EventRecord event) async {
    await ensureInitialized();
    await _db.insert(
      OrbitDatabaseSchema.tableEvents,
      event.toMap(),
      replaceOnConflict: true,
    );
    notifyListeners();
  }

  Future<void> deleteEvent(String eventId) async {
    await ensureInitialized();
    await _db.delete(
      OrbitDatabaseSchema.tableEvents,
      where: 'id = ?',
      whereArgs: [eventId],
    );
    notifyListeners();
  }

  // --- Emails ---

  Future<List<EmailRecord>> getEmails({
    String? workspaceId,
    String folder = 'inbox',
  }) async {
    await ensureInitialized();
    final ws = workspaceId ?? _activeWorkspaceId;
    final rows = await _db.query(
      OrbitDatabaseSchema.tableEmails,
      where: 'workspace_id = ? AND folder = ?',
      whereArgs: [ws, folder],
      orderBy: 'timestamp DESC',
    );
    return rows.map(EmailRecord.fromMap).toList();
  }

  Future<void> saveEmail(EmailRecord email) async {
    await ensureInitialized();
    await _db.insert(
      OrbitDatabaseSchema.tableEmails,
      email.toMap(),
      replaceOnConflict: true,
    );
    notifyListeners();
  }

  Future<void> setEmailRead(String emailId, bool isRead) async {
    await ensureInitialized();
    await _db.update(
      OrbitDatabaseSchema.tableEmails,
      {'is_read': isRead ? 1 : 0},
      where: 'id = ?',
      whereArgs: [emailId],
    );
    notifyListeners();
  }

  // --- Notes ---

  Future<List<NoteRecord>> getNotes({String? workspaceId}) async {
    await ensureInitialized();
    final ws = workspaceId ?? _activeWorkspaceId;
    final rows = await _db.query(
      OrbitDatabaseSchema.tableNotes,
      where: ws.isEmpty ? null : 'workspace_id = ?',
      whereArgs: ws.isEmpty ? null : [ws],
      orderBy: 'updated_at DESC',
    );
    return rows.map(NoteRecord.fromMap).toList();
  }

  Future<void> saveNote(NoteRecord note) async {
    await ensureInitialized();
    await _db.insert(
      OrbitDatabaseSchema.tableNotes,
      note.toMap(),
      replaceOnConflict: true,
    );
    notifyListeners();
  }

  Future<void> deleteNote(String noteId) async {
    await ensureInitialized();
    await _db.delete(
      OrbitDatabaseSchema.tableNotes,
      where: 'id = ?',
      whereArgs: [noteId],
    );
    notifyListeners();
  }

  // --- Contacts ---

  Future<List<ContactRecord>> getContacts({String? workspaceId}) async {
    await ensureInitialized();
    final ws = workspaceId ?? _activeWorkspaceId;
    final rows = await _db.query(
      OrbitDatabaseSchema.tableContacts,
      where: ws.isEmpty ? null : 'workspace_id = ?',
      whereArgs: ws.isEmpty ? null : [ws],
      orderBy: 'name ASC',
    );
    return rows.map(ContactRecord.fromMap).toList();
  }

  Future<void> saveContact(ContactRecord contact) async {
    await ensureInitialized();
    await _db.insert(
      OrbitDatabaseSchema.tableContacts,
      contact.toMap(),
      replaceOnConflict: true,
    );
    notifyListeners();
  }

  Future<void> deleteContact(String contactId) async {
    await ensureInitialized();
    await _db.delete(
      OrbitDatabaseSchema.tableContacts,
      where: 'id = ?',
      whereArgs: [contactId],
    );
    notifyListeners();
  }

  // --- Files & Attachments ---

  Future<List<FileRecord>> getFiles({
    String? workspaceId,
    String? associatedEntityId,
  }) async {
    await ensureInitialized();
    final ws = workspaceId ?? _activeWorkspaceId;
    final rows = await _db.query(
      OrbitDatabaseSchema.tableFiles,
      where: associatedEntityId != null
          ? 'workspace_id = ? AND associated_entity_id = ?'
          : (ws.isEmpty ? null : 'workspace_id = ?'),
      whereArgs: associatedEntityId != null
          ? [ws, associatedEntityId]
          : (ws.isEmpty ? null : [ws]),
      orderBy: 'created_at DESC',
    );
    return rows.map(FileRecord.fromMap).toList();
  }

  Future<void> saveFile(FileRecord file) async {
    await ensureInitialized();
    await _db.insert(
      OrbitDatabaseSchema.tableFiles,
      file.toMap(),
      replaceOnConflict: true,
    );
    notifyListeners();
  }

  Future<void> deleteFile(String fileId) async {
    await ensureInitialized();
    await _db.delete(
      OrbitDatabaseSchema.tableFiles,
      where: 'id = ?',
      whereArgs: [fileId],
    );
    notifyListeners();
  }
}
