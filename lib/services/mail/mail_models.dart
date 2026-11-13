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
