import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/module_interfaces.dart';
import '../../data/database/orbit_database.dart';
import 'account_models.dart';

final class OrbitAccountManager extends ChangeNotifier {
  OrbitAccountManager({
    required OrbitDatabase database,
    required OrbitSecretStore secretStore,
  }) : _db = database,
       _secrets = secretStore;

  final OrbitDatabase _db;
  final OrbitSecretStore _secrets;
  final List<UserAccountRecord> _accounts = [];

  List<UserAccountRecord> get accounts => List.unmodifiable(_accounts);

  Future<void> loadAccounts() async {
    final rows = await _db.query(OrbitDatabaseSchema.tableAccounts);
    _accounts.clear();
    for (final row in rows) {
      _accounts.add(UserAccountRecord.fromMap(row));
    }
    notifyListeners();
  }

  List<UserAccountRecord> getAccountsForWorkspace(String workspaceId) {
    return _accounts.where((a) => a.workspaceId == workspaceId).toList();
  }

  UserAccountRecord? getAccount(String accountId) {
    for (final acc in _accounts) {
      if (acc.id == accountId) return acc;
    }
    return null;
  }

  Future<void> addAccount({
    required UserAccountRecord account,
    required AuthTokens tokens,
  }) async {
    await _db.insert(
      OrbitDatabaseSchema.tableAccounts,
      account.toMap(),
      replaceOnConflict: true,
    );

    // Securely store credentials in Android Keystore / encrypted secret store
    await _secrets.write('auth.${account.id}.access', tokens.accessToken);
    if (tokens.refreshToken != null) {
      await _secrets.write('auth.${account.id}.refresh', tokens.refreshToken!);
    }
    await _secrets.write(
      'auth.${account.id}.expiry',
      tokens.expiresAt.millisecondsSinceEpoch.toString(),
    );

    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx >= 0) {
      _accounts[idx] = account;
    } else {
      _accounts.add(account);
    }
    notifyListeners();
  }

  Future<void> removeAccount(String accountId) async {
    await _db.delete(
      OrbitDatabaseSchema.tableAccounts,
      where: 'id = ?',
      whereArgs: [accountId],
    );

    await _secrets.delete('auth.$accountId.access');
    await _secrets.delete('auth.$accountId.refresh');
    await _secrets.delete('auth.$accountId.expiry');

    _accounts.removeWhere((a) => a.id == accountId);
    notifyListeners();
  }

  Future<String?> getValidAccessToken(
    String accountId, {
    Future<AuthTokens> Function(String refreshToken)? refreshCallback,
  }) async {
    final access = await _secrets.read('auth.$accountId.access');
    final expiryRaw = await _secrets.read('auth.$accountId.expiry');

    if (access == null || expiryRaw == null) return null;

    final expiryMs = int.tryParse(expiryRaw);
    if (expiryMs == null) return null;

    final expiresAt = DateTime.fromMillisecondsSinceEpoch(expiryMs, isUtc: true);
    final now = DateTime.now().toUtc();

    // Check if token is expired or about to expire in the next 30 seconds
    if (now.isAfter(expiresAt.subtract(const Duration(seconds: 30)))) {
      final refresh = await _secrets.read('auth.$accountId.refresh');
      if (refresh != null && refreshCallback != null) {
        try {
          final newTokens = await refreshCallback(refresh);
          await _secrets.write('auth.$accountId.access', newTokens.accessToken);
          if (newTokens.refreshToken != null) {
            await _secrets.write('auth.$accountId.refresh', newTokens.refreshToken!);
          }
          await _secrets.write(
            'auth.$accountId.expiry',
            newTokens.expiresAt.millisecondsSinceEpoch.toString(),
          );
          return newTokens.accessToken;
        } catch (_) {
          // Refresh failed, token is invalid
          return null;
        }
      }
      return null;
    }

    return access;
  }
}
