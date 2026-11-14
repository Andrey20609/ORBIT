import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// MAIL-02B: минимальная абстракция line-oriented SMTP-сокета.
///
/// Позволяет подменять транспорт в тестах (protocol capture / timeouts)
/// при сохранении production-пути через [SecureSocket].
abstract interface class OrbitSmtpSocket {
  Future<void> writeLine(String line);

  /// Читает одну строку (без CRLF). Бросает при таймауте/закрытии.
  Future<String> readLine();

  void destroy();
}

/// MAIL-02B: фабрика соединений. Production создаёт ТОЛЬКО implicit TLS
/// (SecureSocket с SNI по host, порт из аккаунта - по умолчанию 465,
/// onBadCertificate => false; никакого plain/STARTTLS/insecure пути в
/// коде).
typedef OrbitSmtpSocketFactory = Future<OrbitSmtpSocket> Function(
  String host,
  int port,
);

final class SecureSmtpSocket implements OrbitSmtpSocket {
  SecureSmtpSocket._(this._socket, this._readTimeout, this._writeTimeout)
    : _iterator = StreamIterator<List<int>>(_socket);

  final SecureSocket _socket;
  final Duration _readTimeout;
  final Duration _writeTimeout;
  final StreamIterator<List<int>> _iterator;
  final BytesBuilder _buffer = BytesBuilder(copy: true);
  final List<int> _pending = <int>[];

  @override
  Future<void> writeLine(String line) async {
    try {
      _socket.add(utf8.encode(line));
      _socket.add(const [13, 10]);
      await _socket.flush().timeout(_writeTimeout);
    } on TimeoutException {
      _socket.destroy();
      throw const SmtpConnectionException('Таймаут записи в сокет');
    }
  }

  @override
  Future<String> readLine() async {
    final crlf = await _ensureCrlf();
    final line = smtpUtf8WithFallback(_pending.sublist(0, crlf));
    _pending.removeRange(0, crlf + 2);
    return line;
  }

  @override
  void destroy() {
    try {
      _iterator.cancel();
    } catch (_) {}
    _socket.destroy();
    _pending.clear();
    _buffer.clear();
  }

  /// Гарантирует, что в буфере есть CRLF-терминатор.
  Future<int> _ensureCrlf() async {
    while (_findCrlf() == null) {
      await _fillFromSocket();
    }
    return _findCrlf()!;
  }

  Future<void> _fillFromSocket() async {
    try {
      final hasData = await _iterator.moveNext().timeout(_readTimeout);
      if (!hasData) {
        throw const SmtpConnectionException('Соединение закрыто сервером');
      }
      _buffer.add(_iterator.current);
      _pending.addAll(_iterator.current);
    } on TimeoutException {
      throw const SmtpConnectionException('Таймаут чтения из сокета');
    }
  }

  int? _findCrlf() {
    for (var i = 0; i + 1 < _pending.length; i++) {
      if (_pending[i] == 13 && _pending[i + 1] == 10) return i;
    }
    return null;
  }

  static Future<SecureSmtpSocket> connect(
    String host,
    int port, {
    required Duration readTimeout,
    required Duration writeTimeout,
    required Duration connectTimeout,
  }) async {
    final socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (_) => false, // строгая проверка сертификата
      timeout: connectTimeout,
    );
    socket.setOption(SocketOption.tcpNoDelay, true);
    return SecureSmtpSocket._(socket, readTimeout, writeTimeout);
  }
}

class SmtpConnectionException implements Exception {
  const SmtpConnectionException(this.message);

  final String message;

  @override
  String toString() => 'SmtpConnectionException: $message';
}

/// UTF-8 с Latin-1 fallback для некорректных байтов (SMTP-ответы).
String smtpUtf8WithFallback(List<int> bytes) {
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } on FormatException {
    return bytes.map((b) => b & 0x7F).map(String.fromCharCode).join();
  }
}
