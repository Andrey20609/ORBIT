import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../data/database/orbit_data_engine.dart';
import '../../data/models/email_record.dart';
import 'mail_models.dart';
import 'mail_offline_queue.dart';
import 'mail_transport.dart';

final class MailService extends ChangeNotifier {
  MailService({
    required OrbitDataEngine dataEngine,
    required MailTransport transport,
    MailOfflineQueue? queue,
  }) : _dataEngine = dataEngine,
       _transport = transport,
       _queue = queue ?? MailOfflineQueue();

  final OrbitDataEngine _dataEngine;
  final MailTransport _transport;
  final MailOfflineQueue _queue;

  MailOfflineQueue get queue => _queue;

  Future<int> syncFolder({
    String folder = 'inbox',
    String? workspaceId,
  }) async {
    final ws = workspaceId ?? _dataEngine.activeWorkspaceId;
    final remoteEmails = await _transport.fetchEmails(folder: folder);
    var saved = 0;

    for (final email in remoteEmails) {
      final emailRecord = email.copyWith(workspaceId: ws, folder: folder);
      await _dataEngine.saveEmail(emailRecord);
      saved++;
    }

    notifyListeners();
    return saved;
  }

  Future<QueuedOutgoingEmail> sendEmail({
    required String to,
    required String subject,
    required String body,
    String? workspaceId,
    String? accountId,
    List<String> attachmentPaths = const [],
  }) async {
    final ws = workspaceId ?? _dataEngine.activeWorkspaceId;
    final emailId = 'outgoing-${DateTime.now().millisecondsSinceEpoch}';

    final outgoing = QueuedOutgoingEmail(
      id: emailId,
      workspaceId: ws,
      accountId: accountId,
      to: to,
      subject: subject,
      body: body,
      attachmentPaths: attachmentPaths,
      createdAt: DateTime.now().toUtc(),
    );

    _queue.enqueue(outgoing);

    // Try processing the queue immediately
    await _queue.processQueue(
      _transport,
      onEmailSent: (sentEmail) async {
        // Save to sent folder in local database
        final sentRecord = EmailRecord(
          id: sentEmail.id,
          workspaceId: sentEmail.workspaceId,
          accountId: sentEmail.accountId,
          folder: 'sent',
          sender: 'me@orbit.app',
          recipient: sentEmail.to,
          subject: sentEmail.subject,
          preview: sentEmail.body.length > 60
              ? '${sentEmail.body.substring(0, 60)}...'
              : sentEmail.body,
          body: sentEmail.body,
          timestamp: sentEmail.createdAt,
          isRead: true,
          hasAttachments: sentEmail.attachmentPaths.isNotEmpty,
        );
        await _dataEngine.saveEmail(sentRecord);
      },
    );

    notifyListeners();
    return outgoing;
  }

  Future<int> flushOfflineQueue() async {
    final sentCount = await _queue.processQueue(
      _transport,
      onEmailSent: (sentEmail) async {
        final sentRecord = EmailRecord(
          id: sentEmail.id,
          workspaceId: sentEmail.workspaceId,
          accountId: sentEmail.accountId,
          folder: 'sent',
          sender: 'me@orbit.app',
          recipient: sentEmail.to,
          subject: sentEmail.subject,
          preview: sentEmail.body,
          body: sentEmail.body,
          timestamp: sentEmail.createdAt,
          isRead: true,
        );
        await _dataEngine.saveEmail(sentRecord);
      },
    );
    notifyListeners();
    return sentCount;
  }
}
