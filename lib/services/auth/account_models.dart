import 'package:flutter/foundation.dart';

enum EmailProviderType {
  google,
  yandex,
  mailru,
  outlook,
  imapSmtp,
}

enum AccountSyncStatus {
  idle,
  syncing,
  success,
  authRequired,
  error,
}

@immutable
final class UserAccountRecord {
  const UserAccountRecord({
    required this.id,
    required this.workspaceId,
    required this.email,
    required this.displayName,
    required this.providerType,
    this.syncStatus = AccountSyncStatus.idle,
    this.lastSyncAt,
    this.avatarUrl,
  });

  final String id;
  final String workspaceId;
  final String email;
  final String displayName;
  final EmailProviderType providerType;
  final AccountSyncStatus syncStatus;
  final DateTime? lastSyncAt;
  final String? avatarUrl;

  Map<String, Object?> toMap() => {
    'id': id,
    'workspace_id': workspaceId,
    'email': email,
    'display_name': displayName,
    'provider_type': providerType.name,
    'sync_status': syncStatus.name,
    'last_sync_at': lastSyncAt?.millisecondsSinceEpoch,
  };

  factory UserAccountRecord.fromMap(Map<String, Object?> map) {
    return UserAccountRecord(
      id: map['id']! as String,
      workspaceId: (map['workspace_id'] as String?) ?? 'workspace-work',
      email: map['email']! as String,
      displayName: (map['display_name'] as String?) ?? '',
      providerType: EmailProviderType.values.firstWhere(
        (p) => p.name == map['provider_type'],
        orElse: () => EmailProviderType.imapSmtp,
      ),
      syncStatus: AccountSyncStatus.values.firstWhere(
        (s) => s.name == map['sync_status'],
        orElse: () => AccountSyncStatus.idle,
      ),
      lastSyncAt: map['last_sync_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (map['last_sync_at'] as num).toInt(),
              isUtc: true,
            )
          : null,
    );
  }

  UserAccountRecord copyWith({
    String? workspaceId,
    String? email,
    String? displayName,
    EmailProviderType? providerType,
    AccountSyncStatus? syncStatus,
    DateTime? lastSyncAt,
    String? avatarUrl,
  }) {
    return UserAccountRecord(
      id: id,
      workspaceId: workspaceId ?? this.workspaceId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      providerType: providerType ?? this.providerType,
      syncStatus: syncStatus ?? this.syncStatus,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAccountRecord &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          workspaceId == other.workspaceId &&
          email == other.email &&
          providerType == other.providerType &&
          syncStatus == other.syncStatus;

  @override
  int get hashCode => Object.hash(
    id,
    workspaceId,
    email,
    providerType,
    syncStatus,
  );
}

@immutable
final class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  bool isExpired({Duration gracePeriod = const Duration(seconds: 30)}) {
    return DateTime.now().toUtc().isAfter(expiresAt.subtract(gracePeriod));
  }
}
