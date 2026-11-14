import 'package:flutter/foundation.dart';

import '../../data/database/orbit_database.dart';

/// MAIL-02B: статусы записи персистентного outbox.
/// - queued: ждёт отправки (retry после restart разрешён);
/// - sending: в полёте ТЕКУЩЕГО процесса flush; leftover sending (после
///   crash/restart) переводится в failed БЕЗ повторной отправки -
///   защита от дубликатов (письмо могло быть принято сервером);
/// - sent: сервер принял письмо (250 на DATA) - финальный статус;
/// - failed: постоянный отказ или исчерпаны retry.
const String outboxStatusQueued = 'queued';
const String outboxStatusSending = 'sending';
const String outboxStatusSent = 'sent';
const String outboxStatusFailed = 'failed';

/// MAIL-02B: одна запись персистентной очереди исходящих.
@immutable
final class SmtpOutboxRecord {
  const SmtpOutboxRecord({
    required this.id,
    required this.workspaceId,
    required this.accountId,
    required this.recipient,
    required this.subject,
    required this.body,
    required this.createdAtMs,
    required this.status,
    required this.retryCount,
    this.lastError,
    this.sentAtMs,
  });

  final String id;
  final String workspaceId;
  final String accountId;
  final String recipient;
  final String subject;
  final String body;
  final int createdAtMs;
  final String status;
  final int retryCount;
  final String? lastError;
  final int? sentAtMs;

  SmtpOutboxRecord copyWith({
    String? status,
    int? retryCount,
    String? lastError,
    bool clearLastError = false,
    int? sentAtMs,
  }) {
    return SmtpOutboxRecord(
      id: id,
      workspaceId: workspaceId,
      accountId: accountId,
      recipient: recipient,
      subject: subject,
      body: body,
      createdAtMs: createdAtMs,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
      sentAtMs: sentAtMs ?? this.sentAtMs,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'workspace_id': workspaceId,
    'account_id': accountId,
    'recipient': recipient,
    'subject': subject,
    'body': body,
    'created_at': createdAtMs,
    'status': status,
    'retry_count': retryCount,
    if (lastError != null) 'last_error': lastError,
    if (sentAtMs != null) 'sent_at': sentAtMs,
  };

  factory SmtpOutboxRecord.fromMap(Map<String, Object?> map) {
    return SmtpOutboxRecord(
      id: map['id']! as String,
      workspaceId: (map['workspace_id'] as String?) ?? '',
      accountId: (map['account_id'] as String?) ?? '',
      recipient: (map['recipient'] as String?) ?? '',
      subject: (map['subject'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      createdAtMs: ((map['created_at'] as num?) ?? 0).toInt(),
      status: (map['status'] as String?) ?? outboxStatusQueued,
      retryCount: ((map['retry_count'] as num?) ?? 0).toInt(),
      lastError: map['last_error'] as String?,
      sentAtMs: map['sent_at'] == null
          ? null
          : ((map['sent_at'] as num).toInt()),
    );
  }
}

/// MAIL-02B: персистентное хранилище очереди поверх ТОГО ЖЕ production
/// SQLite (владелец файла - DriftLocalStateRepository; таблица
/// smtp_outbox создаётся additively при открытии базы). Запись
/// уникальна по id (PRIMARY KEY) - повторный enqueue того же id не
/// создаёт дубликат.
final class SmtpOutboxStore {
  SmtpOutboxStore(this._db);

  final OrbitDatabase _db;

  Future<void> upsert(SmtpOutboxRecord record) async {
    await _db.insert(
      'smtp_outbox',
      record.toMap(),
      replaceOnConflict: true,
    );
  }

  Future<SmtpOutboxRecord?> byId(String id) async {
    final rows = await _db.query(
      'smtp_outbox',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SmtpOutboxRecord.fromMap(rows.single);
  }

  Future<List<SmtpOutboxRecord>> byStatus(String status) async {
    final rows = await _db.query(
      'smtp_outbox',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'created_at ASC',
    );
    return rows.map(SmtpOutboxRecord.fromMap).toList();
  }

  Future<List<SmtpOutboxRecord>> all() async {
    final rows = await _db.query(
      'smtp_outbox',
      orderBy: 'created_at DESC',
    );
    return rows.map(SmtpOutboxRecord.fromMap).toList();
  }

  Future<void> updateStatus(
    String id,
    String status, {
    int? retryCount,
    String? lastError,
    bool clearLastError = false,
    int? sentAtMs,
  }) async {
    final record = await byId(id);
    if (record == null) return;
    await upsert(
      record.copyWith(
        status: status,
        retryCount: retryCount,
        lastError: lastError,
        clearLastError: clearLastError,
        sentAtMs: sentAtMs,
      ),
    );
  }
}
