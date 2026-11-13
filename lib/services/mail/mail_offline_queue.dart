import 'dart:async';
import 'package:flutter/foundation.dart';

import 'mail_models.dart';
import 'mail_transport.dart';

final class MailOfflineQueue extends ChangeNotifier {
  MailOfflineQueue();

  final List<QueuedOutgoingEmail> _queue = [];

  List<QueuedOutgoingEmail> get queue => List.unmodifiable(_queue);
  int get pendingCount =>
      _queue.where((e) => e.status == MailSendStatus.queued).length;

  void enqueue(QueuedOutgoingEmail outgoing) {
    _queue.add(outgoing);
    notifyListeners();
  }

  Future<int> processQueue(
    MailTransport transport, {
    void Function(QueuedOutgoingEmail sent)? onEmailSent,
  }) async {
    var sentCount = 0;
    for (var i = 0; i < _queue.length; i++) {
      final item = _queue[i];
      if (item.status == MailSendStatus.sent) continue;

      _queue[i] = item.copyWith(status: MailSendStatus.sending);
      notifyListeners();

      try {
        final success = await transport.sendEmail(item);
        if (success) {
          final sentItem = item.copyWith(status: MailSendStatus.sent);
          _queue[i] = sentItem;
          sentCount++;
          if (onEmailSent != null) onEmailSent(sentItem);
        } else {
          _queue[i] = item.copyWith(
            status: MailSendStatus.failed,
            retryCount: item.retryCount + 1,
            lastError: 'Server rejected message',
          );
        }
      } catch (e) {
        _queue[i] = item.copyWith(
          status: MailSendStatus.queued,
          retryCount: item.retryCount + 1,
          lastError: e.toString(),
        );
      }
      notifyListeners();
    }
    return sentCount;
  }

  void clearSent() {
    _queue.removeWhere((e) => e.status == MailSendStatus.sent);
    notifyListeners();
  }
}
