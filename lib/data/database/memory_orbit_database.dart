import 'dart:async';
import '../models/workspace_record.dart';
import 'orbit_database.dart';

final class MemoryOrbitDatabase implements OrbitDatabase {
  MemoryOrbitDatabase({bool autoSeed = true}) : _autoSeed = autoSeed;

  final bool _autoSeed;
  bool _isOpen = false;
  final Map<String, List<Map<String, Object?>>> _tables = {};

  @override
  bool get isOpen => _isOpen;

  void _initTables() {
    _tables.putIfAbsent(OrbitDatabaseSchema.tableWorkspaces, () => []);
    _tables.putIfAbsent(OrbitDatabaseSchema.tableAccounts, () => []);
    _tables.putIfAbsent(OrbitDatabaseSchema.tableEmails, () => []);
    _tables.putIfAbsent(OrbitDatabaseSchema.tableEvents, () => []);
    _tables.putIfAbsent(OrbitDatabaseSchema.tableTasks, () => []);
    _tables.putIfAbsent(OrbitDatabaseSchema.tableNotes, () => []);
    _tables.putIfAbsent(OrbitDatabaseSchema.tableContacts, () => []);
    _tables.putIfAbsent(OrbitDatabaseSchema.tableFiles, () => []);
  }

  void _seedWorkspacesSync() {
    final list = _tables.putIfAbsent(OrbitDatabaseSchema.tableWorkspaces, () => []);
    for (final ws in WorkspaceRecord.defaultWorkspaces) {
      final map = ws.toMap();
      final idx = list.indexWhere((r) => r['id'] == map['id']);
      if (idx >= 0) {
        list[idx] = map;
      } else {
        list.add(map);
      }
    }
  }

  @override
  Future<void> open() async {
    if (_isOpen) return;
    _isOpen = true;
    _initTables();

    if (_autoSeed) {
      _seedWorkspacesSync();
    }
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }

  List<Map<String, Object?>> _getTable(String table) {
    if (!_isOpen) {
      _isOpen = true;
      _initTables();
      if (_autoSeed) {
        _seedWorkspacesSync();
      }
    }
    return _tables.putIfAbsent(table, () => []);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final rows = _getTable(table);
    var result = rows.map((r) => Map<String, Object?>.from(r)).toList();

    if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
      // Basic match for expressions like "workspace_id = ?" or "id = ?" or "folder = ?"
      final parts = where.split(' AND ');
      result = result.where((row) {
        var argIndex = 0;
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.contains(' = ?')) {
            final col = trimmed.replaceAll(' = ?', '').trim();
            if (argIndex < whereArgs.length) {
              final expected = whereArgs[argIndex++];
              if (row[col] != expected) return false;
            }
          }
        }
        return true;
      }).toList();
    }

    if (orderBy != null) {
      final desc = orderBy.endsWith(' DESC');
      final col = orderBy.replaceAll(' DESC', '').replaceAll(' ASC', '').trim();
      result.sort((a, b) {
        final valA = a[col];
        final valB = b[col];
        if (valA == null && valB == null) return 0;
        if (valA == null) return desc ? 1 : -1;
        if (valB == null) return desc ? -1 : 1;
        if (valA is Comparable && valB is Comparable) {
          final cmp = valA.compareTo(valB);
          return desc ? -cmp : cmp;
        }
        return 0;
      });
    }

    if (limit != null && result.length > limit) {
      result = result.sublist(0, limit);
    }

    return result;
  }

  @override
  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    bool replaceOnConflict = true,
  }) async {
    final rows = _getTable(table);
    final id = values['id'];

    if (id != null) {
      final existingIndex = rows.indexWhere((r) => r['id'] == id);
      if (existingIndex >= 0) {
        if (replaceOnConflict) {
          rows[existingIndex] = Map<String, Object?>.from(values);
          return 1;
        } else {
          return 0;
        }
      }
    }

    rows.add(Map<String, Object?>.from(values));
    return 1;
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = _getTable(table);
    var updated = 0;

    for (var i = 0; i < rows.length; i++) {
      var matches = true;
      if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
        final parts = where.split(' AND ');
        var argIndex = 0;
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.contains(' = ?')) {
            final col = trimmed.replaceAll(' = ?', '').trim();
            if (argIndex < whereArgs.length) {
              final expected = whereArgs[argIndex++];
              if (rows[i][col] != expected) {
                matches = false;
                break;
              }
            }
          }
        }
      }
      if (matches) {
        rows[i].addAll(values);
        updated++;
      }
    }
    return updated;
  }

  @override
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    final rows = _getTable(table);
    if (where == null) {
      final count = rows.length;
      rows.clear();
      return count;
    }

    var removed = 0;
    rows.removeWhere((row) {
      var matches = true;
      if (whereArgs != null && whereArgs.isNotEmpty) {
        final parts = where.split(' AND ');
        var argIndex = 0;
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.contains(' = ?')) {
            final col = trimmed.replaceAll(' = ?', '').trim();
            if (argIndex < whereArgs.length) {
              final expected = whereArgs[argIndex++];
              if (row[col] != expected) {
                matches = false;
                break;
              }
            }
          }
        }
      }
      if (matches) {
        removed++;
        return true;
      }
      return false;
    });
    return removed;
  }

  @override
  Future<T> transaction<T>(Future<T> Function(OrbitDatabase txn) action) async {
    // In-memory transactions run directly on this instance
    return action(this);
  }
}
