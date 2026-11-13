abstract interface class OrbitDatabase {
  Future<void> open();
  Future<void> close();
  bool get isOpen;

  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  });

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = true,
  });

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  });

  Future<T> transaction<T>(Future<T> Function(OrbitDatabase txn) action);
}

abstract final class OrbitDatabaseSchema {
  static const tableWorkspaces = 'workspaces';
  static const tableAccounts = 'accounts';
  static const tableEmails = 'emails';
  static const tableEvents = 'events';
  static const tableTasks = 'tasks';
  static const tableNotes = 'notes';
  static const tableContacts = 'contacts';
  static const tableFiles = 'files';

  static const createWorkspaces = '''
    CREATE TABLE IF NOT EXISTS workspaces (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      color_value INTEGER NOT NULL,
      is_default INTEGER NOT NULL,
      created_at INTEGER NOT NULL
    );
  ''';

  static const createAccounts = '''
    CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      email TEXT NOT NULL,
      display_name TEXT NOT NULL,
      provider_type TEXT NOT NULL,
      sync_status TEXT NOT NULL,
      last_sync_at INTEGER,
      FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
    );
  ''';

  static const createEmails = '''
    CREATE TABLE IF NOT EXISTS emails (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      account_id TEXT,
      folder TEXT NOT NULL,
      sender TEXT NOT NULL,
      recipient TEXT NOT NULL,
      subject TEXT NOT NULL,
      preview TEXT NOT NULL,
      body TEXT NOT NULL,
      timestamp INTEGER NOT NULL,
      is_read INTEGER NOT NULL,
      is_flagged INTEGER NOT NULL,
      has_attachments INTEGER NOT NULL,
      FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
    );
  ''';

  static const createEvents = '''
    CREATE TABLE IF NOT EXISTS events (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      start_time INTEGER NOT NULL,
      end_time INTEGER NOT NULL,
      location TEXT,
      is_all_day INTEGER NOT NULL,
      category TEXT NOT NULL,
      participants_json TEXT,
      FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
    );
  ''';

  static const createTasks = '''
    CREATE TABLE IF NOT EXISTS tasks (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      title TEXT NOT NULL,
      project TEXT,
      due_date TEXT,
      is_done INTEGER NOT NULL,
      priority INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
    );
  ''';

  static const createNotes = '''
    CREATE TABLE IF NOT EXISTS notes (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      tags_json TEXT,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
    );
  ''';

  static const createContacts = '''
    CREATE TABLE IF NOT EXISTS contacts (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      name TEXT NOT NULL,
      email TEXT NOT NULL,
      phone TEXT,
      company TEXT,
      role TEXT,
      avatar_url TEXT,
      FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
    );
  ''';

  static const createFiles = '''
    CREATE TABLE IF NOT EXISTS files (
      id TEXT PRIMARY KEY,
      workspace_id TEXT NOT NULL,
      file_name TEXT NOT NULL,
      extension TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      mime_type TEXT NOT NULL,
      local_path TEXT,
      remote_uri TEXT,
      associated_entity_type TEXT,
      associated_entity_id TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      FOREIGN KEY (workspace_id) REFERENCES workspaces (id) ON DELETE CASCADE
    );
  ''';
}
