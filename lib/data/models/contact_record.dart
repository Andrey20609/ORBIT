import 'package:flutter/foundation.dart';

@immutable
final class ContactRecord {
  const ContactRecord({
    required this.id,
    required this.workspaceId,
    required this.name,
    required this.email,
    this.phone,
    this.company,
    this.role,
    this.avatarUrl,
  });

  final String id;
  final String workspaceId;
  final String name;
  final String email;
  final String? phone;
  final String? company;
  final String? role;
  final String? avatarUrl;

  Map<String, Object?> toMap() => {
    'id': id,
    'workspace_id': workspaceId,
    'name': name,
    'email': email,
    'phone': phone,
    'company': company,
    'role': role,
    'avatar_url': avatarUrl,
  };

  factory ContactRecord.fromMap(Map<String, Object?> map) {
    return ContactRecord(
      id: map['id']! as String,
      workspaceId: (map['workspace_id'] as String?) ?? 'workspace-work',
      name: map['name']! as String,
      email: map['email']! as String,
      phone: map['phone'] as String?,
      company: map['company'] as String?,
      role: map['role'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  ContactRecord copyWith({
    String? workspaceId,
    String? name,
    String? email,
    String? phone,
    String? company,
    String? role,
    String? avatarUrl,
  }) {
    return ContactRecord(
      id: id,
      workspaceId: workspaceId ?? this.workspaceId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      company: company ?? this.company,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContactRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workspaceId == other.workspaceId &&
          name == other.name &&
          email == other.email &&
          company == other.company;

  @override
  int get hashCode => Object.hash(id, workspaceId, name, email, company);
}
