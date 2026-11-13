import 'dart:async';
import '../../data/models/email_record.dart';
import 'mail_models.dart';

abstract interface class MailTransport {
  Future<List<EmailRecord>> fetchEmails({
    required String folder,
    int limit = 50,
  });

  Future<bool> sendEmail(QueuedOutgoingEmail outgoing);
}

final class SimulatedMailTransport implements MailTransport {
  SimulatedMailTransport({
    this.isOnline = true,
    List<EmailRecord>? remoteEmails,
  }) : _remoteEmails = remoteEmails ?? [];

  bool isOnline;
  final List<EmailRecord> _remoteEmails;
  final List<QueuedOutgoingEmail> sentDeliveries = [];

  void addRemoteEmail(EmailRecord email) {
    _remoteEmails.add(email);
  }

  @override
  Future<List<EmailRecord>> fetchEmails({
    required String folder,
    int limit = 50,
  }) async {
    if (!isOnline) {
      throw const FormatException('Network connection unavailable');
    }
    return _remoteEmails.where((e) => e.folder == folder).take(limit).toList();
  }

  @override
  Future<bool> sendEmail(QueuedOutgoingEmail outgoing) async {
    if (!isOnline) {
      throw const FormatException('Cannot send: network offline');
    }
    sentDeliveries.add(outgoing);
    return true;
  }
}
