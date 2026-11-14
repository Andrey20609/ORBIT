import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'imap_socket.dart';

/// Исключения IMAP-клиента. Сообщения sanitized: без email/пароля/токенов
/// и без фрагментов raw-ответов сервера.
class ImapAuthException implements Exception {
  const ImapAuthException(this.message);

  final String message;

  @override
  String toString() => 'ImapAuthException: $message';
}

class ImapProtocolException implements Exception {
  const ImapProtocolException(this.message);

  final String message;

  @override
  String toString() => 'ImapProtocolException: $message';
}

/// Metadata одного реального письма (минимальный cache по ТЗ: sender,
/// subject, ограниченный preview, timestamp, flags; БЕЗ тела, HTML,
/// вложений).
@immutable
class ImapMessageMetadata {
  const ImapMessageMetadata({
    required this.uid,
    required this.uidValidity,
    required this.flags,
    required this.internalDateIso,
    required this.from,
    required this.subject,
    required this.preview,
  });

  final int uid;
  final int uidValidity;
  final List<String> flags;
  final String internalDateIso;
  final String from;
  final String subject;
  final String preview;

  /// Детерминированный id: accountId:folder:uidValidity:uid.
  String deterministicId(String accountId, String folder) =>
      '$accountId:$folder:$uidValidity:$uid';
}

/// Ответ одной untagged-строки: текст строки и, при наличии, IMAP literal.
final class _ImapResponsePiece {
  const _ImapResponsePiece.line(this.text)
    : isLiteral = false,
      literalContent = '';

  const _ImapResponsePiece.literal(this.literalContent)
    : isLiteral = true,
      text = '';

  final bool isLiteral;
  final String text;
  final String literalContent;
}

final class _LiteralSpan {
  const _LiteralSpan(this.start, this.content);

  final int start;
  final String content;
}

final class _CommandResult {
  const _CommandResult(this.taggedLine, this.untaggedResponses);

  final String taggedLine;
  final List<List<_ImapResponsePiece>> untaggedResponses;

  bool get isOk => taggedLine.contains(' OK');
}

/// MAIL-02A: настоящий read-only IMAP client (Yandex/Mail.ru/custom через
/// app password; Gmail/Outlook через XOAUTH2 с существующим refresh
/// lifecycle).
///
/// Гарантии read-only на уровне кода: единственные команды, которые этот
/// класс способен отправить - LOGIN / AUTHENTICATE XOAUTH2 / EXAMINE /
/// UID SEARCH / UID FETCH / LOGOUT. STORE, EXPUNGE, DELETE, MOVE, COPY,
/// APPEND, CREATE, RENAME и SMTP структурно недостижимы (allowlist).
/// EXAMINE (не SELECT) + BODY.PEEK (не RFC822) - серверное состояние,
/// включая флаг прочитанности, не изменяется.
///
/// TLS: только implicit TLS порт 993 через [OrbitImapSocketFactory]
/// (production - SecureImapSocket: SecureSocket с onBadCertificate =>
/// false); никакого plain/STARTTLS/insecure fallback. Credentials
/// передаются только ПОСЛЕ успешного TLS-handshake (внутри канала).
final class ImapReadOnlyClient {
  /// Для тестов: готовый (уже подключённый) socket.
  ImapReadOnlyClient.forSocket(
    this._socket, {
    this.writeTimeout = defaultWriteTimeout,
  });

  ImapReadOnlyClient._(this._socket, {this.writeTimeout = defaultWriteTimeout});

  final OrbitImapSocket _socket;

  /// ТЗ MAIL-02A §3: write timeout. Применяется к каждой командной
  /// записи; при таймауте соединение закрывается.
  static const Duration defaultWriteTimeout = Duration(seconds: 15);
  final Duration writeTimeout;

  int _commandCounter = 0;
  final List<String> _capturedCommands = <String>[];
  bool _closed = false;

  /// Захваченные команды (credentials redacted) - для protocol-тестов и
  /// evidence. Пароли/токены сюда не попадают никогда.
  List<String> get capturedCommands =>
      List<String>.unmodifiable(_capturedCommands);

  /// Production-подключение: ТОЛЬКО implicit TLS порт 993.
  static Future<ImapReadOnlyClient> connect(
    String host, {
    OrbitImapSocketFactory? socketFactory,
    Duration connectTimeout = const Duration(seconds: 12),
    Duration readTimeout = const Duration(seconds: 15),
    Duration writeTimeout = defaultWriteTimeout,
  }) async {
    final factory =
        socketFactory ??
        ((String h, int p) => SecureImapSocket.connect(
              h,
              p,
              connectTimeout: connectTimeout,
              readTimeout: readTimeout,
              writeTimeout: writeTimeout,
            ));
    final socket = await factory(host, 993); // только implicit TLS
    final client = ImapReadOnlyClient._(socket, writeTimeout: writeTimeout);
    // ТЗ §3: ЛЮБОЙ сбой чтения приветствия (timeout/соединение) закрывает
    // клиент — ни одного пути с незакрытым socket.
    final String greeting;
    try {
      greeting = await client._socket.readLine();
    } catch (_) {
      client.destroy();
      rethrow;
    }
    if (!greeting.startsWith('* OK') && !greeting.startsWith('* PREAUTH')) {
      client.destroy();
      throw const ImapProtocolException('Некорректное приветствие сервера');
    }
    return client;
  }

  String _nextTag() {
    _commandCounter++;
    return 'A$_commandCounter';
  }

  /// Запись команды с write timeout (ТЗ §3): при таймауте соединение
  /// закрывается, ошибка sanitized.
  Future<void> _writeLine(String line) async {
    try {
      await _socket.writeLine(line).timeout(writeTimeout);
    } on TimeoutException {
      destroy();
      throw const ImapConnectionException('Таймаут записи в сокет');
    }
  }

  /// Отправляет команду, собирает untagged-ответы (с literals) и
  /// tagged-итог. NO -> ImapAuthException; BAD -> ImapProtocolException.
  Future<_CommandResult> _sendCommand(String command) async {
    if (_closed) {
      throw const ImapProtocolException('Соединение уже закрыто');
    }
    final tag = _nextTag();
    _capturedCommands.add(_redact(tag, command));
    await _writeLine('$tag $command');
    final untagged = <List<_ImapResponsePiece>>[];
    var taggedLine = '';
    while (true) {
      final pieces = await _readResponsePieces();
      final head = pieces.first.text;
      if (head.startsWith('$tag ')) {
        taggedLine = head;
        break;
      }
      if (head.startsWith('+ ')) {
        // XOAUTH2 failure continuation: завершаем пустой строкой.
        await _writeLine('');
        continue;
      }
      untagged.add(pieces);
    }
    if (taggedLine.startsWith('$tag NO')) {
      throw const ImapAuthException('Сервер отклонил команду');
    }
    if (taggedLine.startsWith('$tag BAD')) {
      throw const ImapProtocolException('Сервер отклонил запрос (BAD)');
    }
    return _CommandResult(taggedLine, untagged);
  }

  /// Читает одну логическую строку с учётом IMAP literals: при
  /// завершении строки {n} содержимое читается побайтово через
  /// readUtf8Octets (multiline-заголовки не ломаются), затем читается
  /// остаток строки.
  Future<List<_ImapResponsePiece>> _readResponsePieces() async {
    final pieces = <_ImapResponsePiece>[];
    var line = await _socket.readLine();
    pieces.add(_ImapResponsePiece.line(line));
    var octets = _literalOctets(line);
    while (octets != null) {
      final content = await _socket.readUtf8Octets(octets);
      pieces.add(_ImapResponsePiece.literal(content));
      line = await _socket.readLine();
      pieces.add(_ImapResponsePiece.line(line));
      octets = _literalOctets(line);
    }
    return pieces;
  }

  /// Число octets, если строка завершается IMAP literal-индикатором {n}.
  int? _literalOctets(String line) {
    if (!line.endsWith('}')) return null;
    final open = line.lastIndexOf('{');
    if (open == -1) return null;
    final digits = line.substring(open + 1, line.length - 1);
    if (digits.isEmpty) return null;
    for (final code in digits.codeUnits) {
      if (code < 48 || code > 57) return null;
    }
    return int.parse(digits);
  }

  String _redact(String tag, String command) {
    if (command.startsWith('LOGIN ') || command.startsWith('AUTHENTICATE ')) {
      return '$tag LOGIN [credentials redacted]';
    }
    return command;
  }

  /// LOGIN внутри установленного TLS - app password (Yandex/Mail.ru/custom).
  Future<void> login(String email, String appPassword) async {
    final result = await _sendCommand(
      'LOGIN ${_quoteImapString(email)} ${_quoteImapString(appPassword)}',
    );
    if (!result.isOk) {
      throw const ImapAuthException('Аутентификация отклонена сервером');
    }
  }

  /// XOAUTH2 (Gmail/Outlook): base64 от строки user, NUL, auth=Bearer,
  /// NUL, NUL (RFC 4616 / XOAUTH2). NUL-байты строятся в рантайме.
  Future<void> authenticateXoauth2(String email, String accessToken) async {
    final nul = String.fromCharCode(0);
    final raw = 'user=$email${nul}auth=Bearer $accessToken$nul$nul';
    final encoded = base64.encode(utf8.encode(raw));
    final result = await _sendCommand('AUTHENTICATE XOAUTH2 $encoded');
    if (!result.isOk) {
      throw const ImapAuthException('Аутентификация отклонена сервером');
    }
  }

  /// EXAMINE - read-only выбор INBOX; возвращает UIDVALIDITY.
  Future<int> examineInbox() async {
    final result = await _sendCommand('EXAMINE "INBOX"');
    for (final pieces in result.untaggedResponses) {
      for (final piece in pieces) {
        if (piece.isLiteral) continue;
        final match = RegExp('UIDVALIDITY ([0-9]+)').firstMatch(piece.text);
        if (match != null) return int.parse(match.group(1)!);
      }
    }
    throw const ImapProtocolException('UIDVALIDITY не получен');
  }

  /// UID SEARCH ALL - список UIDs (read-only поиск).
  Future<List<int>> uidSearchAll() async {
    final result = await _sendCommand('UID SEARCH ALL');
    final uids = <int>[];
    for (final pieces in result.untaggedResponses) {
      final head = pieces.first.text;
      if (!head.startsWith('* SEARCH')) continue;
      final tail = head.substring('* SEARCH'.length).trim();
      if (tail.isNotEmpty) {
        for (final token in tail.split(' ')) {
          if (token.trim().isNotEmpty) uids.add(int.parse(token.trim()));
        }
      }
    }
    return uids;
  }

  /// UID FETCH последних [limit] UIDs - только metadata через BODY.PEEK:
  /// заголовки FROM/SUBJECT/DATE и первые octets TEXT для preview. Тело
  /// НЕ помечается прочитанным; полное содержимое не запрашивается.
  Future<List<ImapMessageMetadata>> fetchRecentMetadata({
    required int uidValidity,
    required List<int> uids,
    int limit = 20,
    int previewOctets = 512,
  }) async {
    final sorted = [...uids]..sort();
    if (sorted.isEmpty) return const <ImapMessageMetadata>[];
    final effective = sorted.length > limit
        ? sorted.sublist(sorted.length - limit)
        : sorted;
    final range = effective.first == effective.last
        ? '${effective.first}'
        : '${effective.first}:${effective.last}';
    final result = await _sendCommand(
      'UID FETCH $range (UID FLAGS INTERNALDATE '
      'BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)] '
      'BODY.PEEK[TEXT]<0.$previewOctets>)',
    );
    return _parseFetch(result.untaggedResponses, uidValidity, previewOctets);
  }

  Future<void> logout() async {
    try {
      await _sendCommand('LOGOUT');
    } finally {
      destroy();
    }
  }

  void destroy() {
    if (_closed) return;
    _closed = true;
    _socket.destroy();
  }

  // ===== Парсинг FETCH-ответов =====
  //
  // Записи склеиваются по литерал-span'ам: позиция содержимого литерала
  // в собранном тексте фиксируется, чтобы служебные поля (UID, FLAGS)
  // не были перепутаны с текстом внутри литералов (subject может
  // содержать любые строки).

  List<ImapMessageMetadata> _parseFetch(
    List<List<_ImapResponsePiece>> responses,
    int uidValidity,
    int previewOctets,
  ) {
    final messages = <ImapMessageMetadata>[];
    final record = <_ImapResponsePiece>[];
    var recordOpen = false;
    for (final pieces in responses) {
      final head = pieces.first.text;
      if (!recordOpen) {
        if (!RegExp('[*] [0-9]+ FETCH [(]').hasMatch(head)) continue;
        recordOpen = true;
      }
      record.addAll(pieces);
      final lastLine = pieces.last.text;
      if (!pieces.last.isLiteral && lastLine.endsWith(')')) {
        messages.add(_parseSingleFetch(record, uidValidity, previewOctets));
        record.clear();
        recordOpen = false;
      }
    }
    return messages;
  }

  ImapMessageMetadata _parseSingleFetch(
    List<_ImapResponsePiece> pieces,
    int uidValidity,
    int previewOctets,
  ) {
    final spans = <_LiteralSpan>[];
    final builder = StringBuffer();
    for (final piece in pieces) {
      if (piece.isLiteral) {
        spans.add(_LiteralSpan(builder.length, piece.literalContent));
        builder.write(piece.literalContent);
      } else {
        builder.write(piece.text);
      }
    }
    final body = builder.toString();

    var uid = 0;
    final uidMatch = _firstMatchOutsideLiterals(
      body,
      spans,
      RegExp('UID ([0-9]+)'),
    );
    if (uidMatch != null) uid = int.parse(uidMatch.group(1)!);

    var flags = const <String>[];
    final flagsMatch = _firstMatchOutsideLiterals(
      body,
      spans,
      RegExp('FLAGS [(]([^)]*)[)]'),
    );
    if (flagsMatch != null) {
      flags = flagsMatch
          .group(1)!
          .split(' ')
          .map((flag) => flag.trim())
          .where((flag) => flag.isNotEmpty)
          .toList();
    }

    var internalDateIso = '';
    final dateMatch = _firstMatchOutsideLiterals(
      body,
      spans,
      RegExp('INTERNALDATE "([^"]*)"'),
    );
    if (dateMatch != null) internalDateIso = dateMatch.group(1)!;

    var from = '';
    var subject = '';
    final headerStart = _literalContentStartAfter(
      body,
      spans,
      'BODY[HEADER.FIELDS',
    );
    if (headerStart != null) {
      final headerSpan = _spanAt(spans, headerStart);
      if (headerSpan != null) {
        from = _headerValue(headerSpan.content, 'From') ?? '';
        subject = _headerValue(headerSpan.content, 'Subject') ?? '';
      }
    }

    var preview = '';
    final textStart = _literalContentStartAfter(body, spans, 'BODY[TEXT]');
    if (textStart != null) {
      final textSpan = _spanAt(spans, textStart);
      if (textSpan != null) {
        preview = _sanitizePreview(textSpan.content, previewOctets);
      }
    }

    return ImapMessageMetadata(
      uid: uid,
      uidValidity: uidValidity,
      flags: flags,
      internalDateIso: internalDateIso,
      from: from,
      subject: subject,
      preview: preview,
    );
  }

  /// Позиция содержимого литерала, следующего за литерал-индикатором
  /// после [marker] (вне литералов). Возвращает null, если маркер или
  /// literal-индикатор не найден.
  int? _literalContentStartAfter(
    String body,
    List<_LiteralSpan> spans,
    String marker,
  ) {
    var searchFrom = 0;
    while (true) {
      final markerIdx = body.indexOf(marker, searchFrom);
      if (markerIdx == -1) return null;
      if (!_insideAnySpan(spans, markerIdx)) {
        final braceOpen = body.indexOf('{', markerIdx + marker.length);
        if (braceOpen == -1) return null;
        final braceClose = body.indexOf('}', braceOpen + 1);
        if (braceClose == -1) return null;
        final contentStart = braceClose + 1;
        if (_spanAt(spans, contentStart) != null) return contentStart;
        return null;
      }
      searchFrom = markerIdx + marker.length;
    }
  }

  bool _insideAnySpan(List<_LiteralSpan> spans, int position) {
    for (final span in spans) {
      final end = span.start + span.content.length;
      if (position >= span.start && position < end) return true;
    }
    return false;
  }

  _LiteralSpan? _spanAt(List<_LiteralSpan> spans, int position) {
    for (final span in spans) {
      if (span.start == position) return span;
    }
    return null;
  }

  RegExpMatch? _firstMatchOutsideLiterals(
    String body,
    List<_LiteralSpan> spans,
    RegExp pattern,
  ) {
    for (final match in pattern.allMatches(body)) {
      if (!_insideAnySpan(spans, match.start)) return match;
    }
    return null;
  }

  /// Значение заголовка из блока (первая строка name: value).
  String? _headerValue(String headerBlock, String name) {
    for (final line in LineSplitter().convert(headerBlock)) {
      final idx = line.indexOf(':');
      if (idx > 0) {
        final key = line.substring(0, idx).trim();
        if (key.toLowerCase() == name.toLowerCase()) {
          return line.substring(idx + 1).trim();
        }
      }
    }
    return null;
  }

  /// Preview: управляющие символы (коды 0..31 и 127) заменяются пробелом,
  /// повторы пробелов сжимаются, длина ограничивается [maxChars].
  String _sanitizePreview(String raw, int maxChars) {
    final builder = StringBuffer();
    for (final code in raw.codeUnits) {
      if (code < 32 || code == 127) {
        builder.write(' ');
      } else {
        builder.writeCharCode(code);
      }
    }
    final flat = builder
        .toString()
        .split(' ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join(' ');
    if (flat.length <= maxChars) return flat;
    return flat.substring(0, maxChars);
  }

  /// IMAP quoted string: backslash и кавычка экранируются (backslash
  /// строится в рантайме через fromCharCode, без escape в исходнике).
  static String _quoteImapString(String value) {
    final bs = String.fromCharCode(92);
    final doubled = value.replaceAll(bs, '$bs$bs');
    final escaped = doubled.replaceAll('"', '$bs"');
    return '"$escaped"';
  }
}
