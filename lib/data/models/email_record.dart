import 'package:flutter/foundation.dart';

@immutable
final class EmailRecord {
  const EmailRecord({
    required this.id,
    required this.workspaceId,
    this.accountId,
    this.folder = 'inbox',
    required this.sender,
    required this.recipient,
    required this.subject,
    required this.preview,
    required this.body,
    required this.timestamp,
    this.isRead = false,
    this.isFlagged = false,
    this.hasAttachments = false,
  });

  final String id;
  final String workspaceId;
  final String? accountId;
  final String folder; // 'inbox', 'sent', 'drafts', 'archive', 'trash'
  final String sender;
  final String recipient;
  final String subject;
  final String preview;
  final String body;
  final DateTime timestamp;
  final bool isRead;
  final bool isFlagged;
  final bool hasAttachments;

  Map<String, Object?> toMap() => {
    'id': id,
    'workspace_id': workspaceId,
    'account_id': accountId,
    'folder': folder,
    'sender': sender,
    'recipient': recipient,
    'subject': subject,
    'preview': preview,
    'body': body,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'is_read': isRead ? 1 : 0,
    'is_flagged': isFlagged ? 1 : 0,
    'has_attachments': hasAttachments ? 1 : 0,
  };

  factory EmailRecord.fromMap(Map<String, Object?> map) {
    return EmailRecord(
      id: map['id']! as String,
      workspaceId: (map['workspace_id'] as String?) ?? 'workspace-work',
      accountId: map['account_id'] as String?,
      folder: (map['folder'] as String?) ?? 'inbox',
      sender: map['sender']! as String,
      recipient: (map['recipient'] as String?) ?? '',
      subject: map['subject']! as String,
      preview: (map['preview'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num).toInt(),
        isUtc: true,
      ),
      isRead: ((map['is_read'] as num?)?.toInt() ?? 0) == 1,
      isFlagged: ((map['is_flagged'] as num?)?.toInt() ?? 0) == 1,
      hasAttachments: ((map['has_attachments'] as num?)?.toInt() ?? 0) == 1,
    );
  }

  EmailRecord copyWith({
    String? workspaceId,
    String? accountId,
    String? folder,
    String? sender,
    String? recipient,
    String? subject,
    String? preview,
    String? body,
    DateTime? timestamp,
    bool? isRead,
    bool? isFlagged,
    bool? hasAttachments,
  }) {
    return EmailRecord(
      id: id,
      workspaceId: workspaceId ?? this.workspaceId,
      accountId: accountId ?? this.accountId,
      folder: folder ?? this.folder,
      sender: sender ?? this.sender,
      recipient: recipient ?? this.recipient,
      subject: subject ?? this.subject,
      preview: preview ?? this.preview,
      body: body ?? this.body,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isFlagged: isFlagged ?? this.isFlagged,
      hasAttachments: hasAttachments ?? this.hasAttachments,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmailRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workspaceId == other.workspaceId &&
          folder == other.folder &&
          sender == other.sender &&
          subject == other.subject &&
          isRead == other.isRead &&
          isFlagged == other.isFlagged;

  @override
  int get hashCode => Object.hash(
    id,
    workspaceId,
    folder,
    sender,
    subject,
    isRead,
    isFlagged,
  );
}
