import 'dart:async';
import 'dart:convert';

import 'smtp_socket.dart';

/// Исключения SMTP-клиента. Сообщения sanitized: без паролей/токенов и
/// сырых ответов сервера.
class SmtpAuthException implements Exception {
  const SmtpAuthException(this.message);

  final String message;

  @override
  String toString() => 'SmtpAuthException: $message';
}

class SmtpRejectException implements Exception {
  const SmtpRejectException(this.message);

  final String message;

  @override
  String toString() => 'SmtpRejectException: $message';
}

/// MAIL-02B: контролируемый SMTP-клиент отправки.
///
/// Гарантии на уровне кода:
/// - единственные команды: EHLO / AUTH LOGIN / AUTH XOAUTH2 /
///   MAIL FROM / RCPT TO / DATA / QUIT / RSET; никаких других команд
///   клиент отправить не может (allowlist);
/// - только implicit TLS (SecureSmtpSocket, onBadCertificate => false);
/// - точка принятия: ответ 250 на завершение DATA - только после неё
///   письмо считается принятым сервером (used by outbox для sent);
/// - capturedCommands с redaction credentials - для protocol-тестов и
///   evidence;
/// - при любом сбое (timeout/соединение/отказ) соединение закрывается.
final class SmtpSendClient {
  /// Для тестов: готовый (уже подключённый) socket + чтение greeting
  /// (тот же стартовый шаг, что и в production connect).
  static Future<SmtpSendClient> forSocket(
    OrbitSmtpSocket socket, {
    Duration writeTimeout = defaultWriteTimeout,
  }) async {
    final client = SmtpSendClient._(socket, writeTimeout: writeTimeout);
    final greeting = await client._readLine();
    if (!greeting.startsWith('220')) {
      client.destroy();
      throw const SmtpRejectException('Некорректное приветствие SMTP-сервера');
    }
    return client;
  }

  SmtpSendClient._(this._socket, {this.writeTimeout = defaultWriteTimeout});

  final OrbitSmtpSocket _socket;

  /// ТЗ MAIL-02A/02B: write timeout на каждую команду.
  static const Duration defaultWriteTimeout = Duration(seconds: 15);
  final Duration writeTimeout;

  final List<String> _capturedCommands = <String>[];
  bool _closed = false;

  /// Захваченные команды (AUTH redacted) - для protocol-тестов/evidence.
  List<String> get capturedCommands =>
      List<String>.unmodifiable(_capturedCommands);

  static Future<SmtpSendClient> connect(
    String host,
    int port, {
    Duration connectTimeout = const Duration(seconds: 12),
    Duration readTimeout = const Duration(seconds: 15),
    Duration writeTimeout = defaultWriteTimeout,
  }) async {
    final socket = await SecureSmtpSocket.connect(
      host,
      port,
      connectTimeout: connectTimeout,
      readTimeout: readTimeout,
      writeTimeout: writeTimeout,
    );
    final client = SmtpSendClient._(socket, writeTimeout: writeTimeout);
    final greeting = await client._readLine();
    if (!greeting.startsWith('220')) {
      client.destroy();
      throw SmtpRejectException('Некорректное приветствие SMTP-сервера');
    }
    return client;
  }

  Future<void> _writeLine(String line) async {
    if (_closed) {
      throw const SmtpRejectException('Соединение уже закрыто');
    }
    try {
      await _socket.writeLine(line).timeout(writeTimeout);
    } on TimeoutException {
      destroy();
      throw const SmtpConnectionException('Таймаут записи в сокет');
    }
  }

  Future<String> _readLine() {
    return _socket.readLine();
  }

  String _redact(String command) {
    if (command.startsWith('AUTH ')) {
      return 'AUTH [credentials redacted]';
    }
    return command;
  }

  /// Читает multiline-ответ: строки, начинающиеся с кода+' ' или
  /// кода+'-' (например 250-...), до строки с кодом и пробелом.
  Future<String> _readResponse(int expectedPrefix) async {
    final first = await _readLine();
    if (!first.startsWith('$expectedPrefix')) {
      return first;
    }
    var last = first;
    while (last.length > 3 && last.codeUnitAt(3) == 45) {
      last = await _readLine();
    }
    return last;
  }

  Future<String> _command(String command, int expectedCode) async {
    _capturedCommands.add(_redact(command));
    await _writeLine(command);
    final response = await _readResponse(expectedCode);
    if (!response.startsWith('$expectedCode')) {
      _classifyAndThrow(response, command);
    }
    return response;
  }

  /// Классификация отказа по SMTP-коду: 5xx на AUTH - аутентификация,
  /// остальные 5xx - постоянный отказ сервера, 4xx - временный (retry
  /// допустим). Никогда не содержит сырой ответ сервера.
  Never _classifyAndThrow(String response, String command) {
    final code = response.length >= 3 ? response.substring(0, 3) : '';
    final isAuthCommand = command.startsWith('AUTH');
    if (code.startsWith('4')) {
      throw const SmtpConnectionException(
        'Сервер временно не принял команду (4xx)',
      );
    }
    if (isAuthCommand || code.startsWith('535')) {
      throw const SmtpAuthException('Сервер отклонил аутентификацию');
    }
    throw const SmtpRejectException('Сервер отклонил команду (5xx)');
  }

  /// EHLO - единственное приветствие (implicit TLS порт 465; STARTTLS
  /// не используется).
  Future<void> ehlo(String clientName) async {
    await _command('EHLO $clientName', 250);
  }

  /// AUTH LOGIN (app password Yandex/Mail.ru/custom) внутри TLS.
  Future<void> authLogin(String email, String appPassword) async {
    _capturedCommands.add('AUTH [credentials redacted]');
    await _writeLine('AUTH LOGIN');
    var prompt = await _readLine();
    if (!prompt.startsWith('334')) {
      _classifyAndThrow(prompt, 'AUTH LOGIN');
    }
    await _writeLine(base64.encode(utf8.encode(email)));
    prompt = await _readLine();
    if (!prompt.startsWith('334')) {
      _classifyAndThrow(prompt, 'AUTH LOGIN username');
    }
    await _writeLine(base64.encode(utf8.encode(appPassword)));
    final result = await _readLine();
    if (!result.startsWith('235')) {
      _classifyAndThrow(result, 'AUTH LOGIN password');
    }
  }

  /// AUTH XOAUTH2 (Gmail/Outlook): base64(user NUL auth=Bearer NUL NUL).
  Future<void> authXoauth2(String email, String accessToken) async {
    final nul = String.fromCharCode(0);
    final payload = base64.encode(
      utf8.encode('user=$email${nul}auth=Bearer $accessToken$nul$nul'),
    );
    _capturedCommands.add('AUTH [credentials redacted]');
    await _writeLine('AUTH XOAUTH2 $payload');
    var response = await _readLine();
    if (response.startsWith('334')) {
      // Failure continuation: пустая строка, затем финальный код.
      await _writeLine('');
      response = await _readLine();
    }
    if (!response.startsWith('235')) {
      _classifyAndThrow(response, 'AUTH XOAUTH2');
    }
  }

  /// MAIL FROM - адрес аккаунта.
  Future<void> mailFrom(String senderEmail) async {
    await _command('MAIL FROM:<$senderEmail>', 250);
  }

  /// RCPT TO - строго контролируемый получатель (проверка allowlist
  /// выполняется транспортом ДО вызова).
  Future<void> rcptTo(String recipient) async {
    await _command('RCPT TO:<$recipient>', 250);
  }

  /// DATA: возвращает true ТОЛЬКО при 250 после полного тела - это
  /// единственная точка принятия письма сервером.
  Future<bool> data(String subject, String body) async {
    await _command('DATA', 354);
    final content = _dotStuffedMessage(subject, body);
    await _writeLine(content);
    final response = await _readLine();
    if (!response.startsWith('250')) {
      _classifyAndThrow(response, 'DATA content');
    }
    return true;
  }

  Future<void> quit() async {
    try {
      await _command('QUIT', 221);
    } finally {
      destroy();
    }
  }

  void destroy() {
    if (_closed) return;
    _closed = true;
    _socket.destroy();
  }

  /// Dot-stuffing: строки, начинающиеся с точки, удваиваются
  /// (RFC 5321); завершающая точка сигнализирует конец данных.
  static String _dotStuffedMessage(String subject, String body) {
    final normalized = 'Subject: $subject'
        '${String.fromCharCode(13)}${String.fromCharCode(10)}'
        '${String.fromCharCode(13)}${String.fromCharCode(10)}'
        '$body';
    final lines = normalized.split(
      String.fromCharCode(13) + String.fromCharCode(10),
    );
    final safe = <String>[];
    for (final line in lines) {
      if (line.startsWith('.')) {
        safe.add('.$line');
      } else {
        safe.add(line);
      }
    }
    safe.add('.');
    return safe.join(
      String.fromCharCode(13) + String.fromCharCode(10),
    );
  }
}
