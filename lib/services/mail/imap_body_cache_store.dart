import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/database/orbit_database.dart';
import 'imap_readonly_client.dart';

/// MAIL-02C: кэшированное тело письма (sanitized plain-text) + метаданные
/// вложений. Идентификатор - детерминированный id MAIL-02A
/// (accountId:folder:uidValidity:uid); содержимое вложений никогда не
/// хранится.
@immutable
final class CachedEmailBody {
  const CachedEmailBody({
    required this.id,
    required this.accountId,
    required this.uidValidity,
    required this.uid,
    required this.bodyText,
    required this.truncated,
    required this.fullSize,
    required this.attachments,
    required this.fetchedAtMs,
    required this.fromCache,
  });

  final String id;
  final String accountId;
  final int uidValidity;
  final int uid;

  /// Sanitized plain-text (управляющие символы, кроме перевода строк,
  /// заменены; отображение - только Text, HTML не исполняется).
  final String bodyText;
  final bool truncated;
  final int fullSize;
  final List<ImapAttachmentMetadata> attachments;
  final int fetchedAtMs;

  /// false - только что загружено по сети; true - прочитано из кэша
  /// (повторный сетевой запрос не выполнялся).
  final bool fromCache;

  Map<String, Object?> toMap() => {
    'id': id,
    'account_id': accountId,
    'uid_validity': uidValidity,
    'uid': uid,
    'body_text': bodyText,
    'truncated': truncated ? 1 : 0,
    'full_size': fullSize,
    'attachments_json': jsonEncode(
      [for (final a in attachments) a.toMap()],
    ),
    'fetched_at': fetchedAtMs,
  };

  factory CachedEmailBody.fromRow(Map<String, Object?> row) {
    List<ImapAttachmentMetadata> attachments = const [];
    final rawJson = row['attachments_json'];
    if (rawJson is String && rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          attachments = decoded
              .whereType<Map<Object?, Object?>>()
              .map(
                (map) => ImapAttachmentMetadata(
                  fileName: (map['fileName'] as String?) ?? '',
                  sizeBytes: ((map['sizeBytes'] as num?) ?? 0).toInt(),
                  mimeType: (map['mimeType'] as String?) ?? '',
                ),
              )
              .toList();
        }
      } catch (_) {
        // Повреждённый JSON метаданных - не критичный путь.
      }
    }
    return CachedEmailBody(
      id: row['id']! as String,
      accountId: (row['account_id'] as String?) ?? '',
      uidValidity: ((row['uid_validity'] as num?) ?? 0).toInt(),
      uid: ((row['uid'] as num?) ?? 0).toInt(),
      bodyText: (row['body_text'] as String?) ?? '',
      truncated: (((row['truncated'] as num?) ?? 0).toInt()) == 1,
      fullSize: ((row['full_size'] as num?) ?? 0).toInt(),
      attachments: attachments,
      fetchedAtMs: ((row['fetched_at'] as num?) ?? 0).toInt(),
      fromCache: true,
    );
  }
}

extension _AttachmentMap on ImapAttachmentMetadata {
  Map<String, Object?> toMap() => {
    'fileName': fileName,
    'sizeBytes': sizeBytes,
    'mimeType': mimeType,
  };
}

/// MAIL-02C: персистентный кэш тел поверх ТОЙ ЖЕ production SQLite
/// (владелец файла - DriftLocalStateRepository; таблица создаётся
/// additively). Полная догрузка уже закэшированного письма не требует
/// сетевого запроса.
final class ImapBodyCacheStore {
  ImapBodyCacheStore(this._db);

  final OrbitDatabase _db;

  Future<CachedEmailBody?> byId(String id) async {
    final rows = await _db.query(
      'imap_body_cache',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedEmailBody.fromRow(rows.single);
  }

  Future<void> upsert(CachedEmailBody record) async {
    await _db.insert(
      'imap_body_cache',
      record.toMap(),
      replaceOnConflict: true,
    );
  }

  Future<void> deleteById(String id) async {
    await _db.delete('imap_body_cache', where: 'id = ?', whereArgs: [id]);
  }

  /// Санитизация для кэша и отображения: управляющие символы, КРОМЕ
  /// LF/CR/TAB, заменяются пробелом (внутри IMAP TEXT могут быть NUL и
  /// др.); полный рендеринг - Flutter Text (HTML/скрипты не исполняются
  /// по построению). Жёсткий cap по символам.
  static String sanitizeBodyText(String raw, {int maxChars = 262144}) {
    final builder = StringBuffer();
    for (final code in raw.codeUnits) {
      if (code == 10 || code == 13 || code == 9) {
        builder.writeCharCode(code);
      } else if (code < 32 || code == 127) {
        builder.write(' ');
      } else {
        builder.writeCharCode(code);
      }
    }
    final cleaned = builder.toString();
    if (cleaned.length <= maxChars) return cleaned;
    return cleaned.substring(0, maxChars);
  }
}
