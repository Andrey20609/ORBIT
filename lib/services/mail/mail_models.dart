import 'package:flutter/foundation.dart';

enum MailSendStatus {
  queued,
  sending,
  sent,
  failed,
}

@immutable
final class QueuedOutgoingEmail {
  const QueuedOutgoingEmail({
    required this.id,
    required this.workspaceId,
    this.accountId,
    required this.to,
    required this.subject,
    required this.body,
    this.attachmentPaths = const [],
    this.status = MailSendStatus.queued,
    required this.createdAt,
    this.retryCount = 0,
    this.lastError,
  });

  final String id;
  final String workspaceId;
  final String? accountId;
  final String to;
  final String subject;
  final String body;
  final List<String> attachmentPaths;
  final MailSendStatus status;
  final DateTime createdAt;
  final int retryCount;
  final String? lastError;

  QueuedOutgoingEmail copyWith({
    MailSendStatus? status,
    int? retryCount,
    String? lastError,
  }) {
    return QueuedOutgoingEmail(
      id: id,
      workspaceId: workspaceId,
      accountId: accountId,
      to: to,
      subject: subject,
      body: body,
      attachmentPaths: attachmentPaths,
      status: status ?? this.status,
      createdAt: createdAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

/// MAIL-02A: metadata одного реального письма для read-only view.
/// Тело/HTML/вложения не хранятся и не отображаются — только sender,
/// subject, ограниченный preview, время и флаги на момент чтения.
@immutable
final class UserInboxEntry {
  const UserInboxEntry({
    required this.id,
    required this.accountId,
    required this.sender,
    required this.subject,
    required this.preview,
    required this.timestamp,
    required this.isRead,
    required this.isFlagged,
  });

  final String id;
  final String accountId;
  final String sender;
  final String subject;
  final String preview;
  final DateTime timestamp;
  final bool isRead;
  final bool isFlagged;

  /// Из сырой строки SQLite (source_type='user').
  factory UserInboxEntry.fromRow(Map<String, Object?> row) {
    return UserInboxEntry(
      id: row['id']! as String,
      accountId: (row['account_id'] as String?) ?? '',
      sender: (row['sender'] as String?) ?? '',
      subject: (row['subject'] as String?) ?? '',
      preview: (row['preview'] as String?) ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ((row['timestamp'] as num?) ?? 0).toInt(),
        isUtc: true,
      ),
      isRead: ((row['is_read'] as num?)?.toInt() ?? 0) == 1,
      isFlagged: ((row['is_flagged'] as num?)?.toInt() ?? 0) == 1,
    );
  }
}
