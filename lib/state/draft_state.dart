import 'package:flutter/foundation.dart';

@immutable
final class DraftState {
  const DraftState({this.to = '', this.subject = '', this.body = ''});

  final String to;
  final String subject;
  final String body;

  DraftState copyWith({String? to, String? subject, String? body}) =>
      DraftState(
        to: to ?? this.to,
        subject: subject ?? this.subject,
        body: body ?? this.body,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'draftTo': to,
    'draftSubject': subject,
    'draftBody': body,
  };

  static DraftState fromJson(Map<String, Object?> json) => DraftState(
    to: json['draftTo'] as String? ?? '',
    subject: json['draftSubject'] as String? ?? '',
    body: json['draftBody'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is DraftState &&
      other.to == to &&
      other.subject == subject &&
      other.body == body;

  @override
  int get hashCode => Object.hash(to, subject, body);
}
