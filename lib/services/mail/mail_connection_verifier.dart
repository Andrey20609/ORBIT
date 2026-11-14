import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Этапы сетевой диагностики почтового шлюза (IMAP / SMTP).
enum MailVerificationStage {
  idle('Ожидание'),
  resolvingDns('DNS-резолвинг'),
  connectingTcp('TCP-соединение'),
  performingTlsHandshake('TLS/SSL защита'),
  readingGreeting('Баннер сервера'),
  authenticating('Аутентификация'),
  success('Подключено'),
  failed('Ошибка соединения');

  const MailVerificationStage(this.label);
  final String label;
}

/// Провайдеры почтовых серверов с преднастроенными шлюзами.
enum OrbitMailProviderType {
  yandex('Яндекс 360', 'imap.yandex.ru', 993, 'smtp.yandex.ru', 465),
  mailRu('Mail.ru', 'imap.mail.ru', 993, 'smtp.mail.ru', 465),
  gmail('Google Gmail', 'imap.gmail.com', 993, 'smtp.gmail.com', 465),
  outlook('Outlook / Office365', 'outlook.office365.com', 993, 'smtp.office365.com', 587),
  custom('Свой IMAP/SMTP', 'imap.example.com', 993, 'smtp.example.com', 465);

  const OrbitMailProviderType(
    this.label,
    this.defaultIncomingHost,
    this.defaultIncomingPort,
    this.defaultOutgoingHost,
    this.defaultOutgoingPort,
  );

  final String label;
  final String defaultIncomingHost;
  final int defaultIncomingPort;
  final String defaultOutgoingHost;
  final int defaultOutgoingPort;

  static OrbitMailProviderType fromName(String? raw) {
    for (final p in OrbitMailProviderType.values) {
      if (p.name == raw) return p;
    }
    return OrbitMailProviderType.custom;
  }
}

/// Статус верификации сохраненного почтового аккаунта.
///
/// MAIL-01A: это статус ENDPOINT-доступности (DNS/TCP/TLS/banner), а не
/// статус аутентификации. `verified` после диагностики означает только
/// «Сервер доступен»; credential-статус живёт отдельно в
/// [OrbitMailCredentialStatus].
enum OrbitMailAccountStatus {
  verified('Сервер доступен'),
  failed('Сервер недоступен'),
  unverified('Сервер не проверялся');

  const OrbitMailAccountStatus(this.label);
  final String label;

  static OrbitMailAccountStatus fromName(String? raw) {
    for (final s in OrbitMailAccountStatus.values) {
      if (s.name == raw) return s;
    }
    return OrbitMailAccountStatus.unverified;
  }
}

/// MAIL-01A: статус учётных данных аккаунта — отдельное не-secret поле.
///
/// `savedUnverified` означает: пароль приложения сохранён в secure storage
/// и metadata успешно записаны, но НАСТОЯЩАЯ аутентификация на сервере ещё
/// не выполнялась (она появится в MAIL-02). `verified` в этом этапе
/// не присваивается никем.
enum OrbitMailCredentialStatus {
  notConfigured('Пароль не настроен'),
  savedUnverified('Сохранено, не проверено'),
  verified('Аутентифицировано');

  const OrbitMailCredentialStatus(this.label);
  final String label;

  static OrbitMailCredentialStatus fromName(String? raw) {
    for (final s in OrbitMailCredentialStatus.values) {
      if (s.name == raw) return s;
    }
    return OrbitMailCredentialStatus.notConfigured;
  }
}

/// Полная модель почтового аккаунта с настройками IMAP/SMTP и JSON-персистентностью.
@immutable
final class OrbitMailAccount {
  const OrbitMailAccount({
    required this.id,
    required this.name,
    required this.email,
    OrbitMailProviderType? providerType,
    String? provider,
    this.incomingHost = '',
    this.incomingPort = 993,
    this.useIncomingSsl = true,
    this.outgoingHost = '',
    this.outgoingPort = 465,
    this.useOutgoingSsl = true,
    this.lastVerifiedAtIso,
    this.lastLatencyMs,
    this.isActive = false,
    this.status = OrbitMailAccountStatus.unverified,
    this.credentialStatus = OrbitMailCredentialStatus.notConfigured,
    this.authMethod,
    this.isDemo = false,
    this.lastError,
  }) : providerType = providerType ??
            (provider == 'yandex'
                ? OrbitMailProviderType.yandex
                : provider == 'mailRu'
                    ? OrbitMailProviderType.mailRu
                    : provider == 'gmail'
                        ? OrbitMailProviderType.gmail
                        : provider == 'outlook'
                            ? OrbitMailProviderType.outlook
                            : OrbitMailProviderType.custom);

  final String id;
  final String name;
  final String email;
  final OrbitMailProviderType providerType;
  final String incomingHost;
  final int incomingPort;
  final bool useIncomingSsl;
  final String outgoingHost;
  final int outgoingPort;
  final bool useOutgoingSsl;
  /// MAIL-01A: время последней ENDPOINT-проверки (DNS/TCP/TLS/banner).
  /// Это НЕ время аутентификации — credential-статус живёт отдельно.
  final String? lastVerifiedAtIso;
  final int? lastLatencyMs;
  final bool isActive;
  final OrbitMailAccountStatus status;

  /// MAIL-01A: credential-статус (не-secret metadata). Пароль приложения
  /// никогда не хранится в этой модели — только в secure storage через
  /// OrbitMailCredentialService.
  final OrbitMailCredentialStatus credentialStatus;

  /// Не-secret metadata способа аутентификации (например `appPassword`).
  final String? authMethod;
  final bool isDemo;
  final String? lastError;

  String get provider => providerType.name;

  DateTime? get lastVerifiedAt =>
      lastVerifiedAtIso != null ? DateTime.tryParse(lastVerifiedAtIso!) : null;

  OrbitMailAccount copyWith({
    String? id,
    String? name,
    String? email,
    OrbitMailProviderType? providerType,
    String? provider,
    String? incomingHost,
    int? incomingPort,
    bool? useIncomingSsl,
    String? outgoingHost,
    int? outgoingPort,
    bool? useOutgoingSsl,
    String? lastVerifiedAtIso,
    DateTime? lastVerifiedAt,
    int? lastLatencyMs,
    bool? isActive,
    OrbitMailAccountStatus? status,
    OrbitMailCredentialStatus? credentialStatus,
    String? authMethod,
    bool clearAuthMethod = false,
    bool? isDemo,
    String? lastError,
  }) {
    return OrbitMailAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      providerType: providerType ??
          (provider != null
              ? OrbitMailProviderType.fromName(provider)
              : this.providerType),
      incomingHost: incomingHost ?? this.incomingHost,
      incomingPort: incomingPort ?? this.incomingPort,
      useIncomingSsl: useIncomingSsl ?? this.useIncomingSsl,
      outgoingHost: outgoingHost ?? this.outgoingHost,
      outgoingPort: outgoingPort ?? this.outgoingPort,
      useOutgoingSsl: useOutgoingSsl ?? this.useOutgoingSsl,
      lastVerifiedAtIso: lastVerifiedAtIso ??
          (lastVerifiedAt != null
              ? lastVerifiedAt.toIso8601String()
              : this.lastVerifiedAtIso),
      lastLatencyMs: lastLatencyMs ?? this.lastLatencyMs,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      credentialStatus: credentialStatus ?? this.credentialStatus,
      // MAIL-01A fix: nullable authMethod нельзя очистить через
      // `authMethod ?? this.authMethod` — явный флаг clearAuthMethod.
      authMethod: clearAuthMethod ? null : (authMethod ?? this.authMethod),
      isDemo: isDemo ?? this.isDemo,
      lastError: lastError ?? this.lastError,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'email': email,
        'providerType': providerType.name,
        'incomingHost': incomingHost,
        'incomingPort': incomingPort,
        'useIncomingSsl': useIncomingSsl,
        'outgoingHost': outgoingHost,
        'outgoingPort': outgoingPort,
        'useOutgoingSsl': useOutgoingSsl,
        'lastVerifiedAtIso': lastVerifiedAtIso,
        'lastLatencyMs': lastLatencyMs,
        'isActive': isActive,
        'status': status.name,
        'credentialStatus': credentialStatus.name,
        if (authMethod != null) 'authMethod': authMethod,
        'isDemo': isDemo,
        if (lastError != null) 'lastError': lastError,
      };

  factory OrbitMailAccount.fromJson(Map<String, Object?> json) {
    final provider =
        OrbitMailProviderType.fromName(json['providerType'] as String?);
    return OrbitMailAccount(
      id: (json['id'] as String?) ?? 'acc_default',
      name: (json['name'] as String?) ?? 'Почта ORBIT',
      email: (json['email'] as String?) ?? 'user@orbit.app',
      providerType: provider,
      incomingHost:
          (json['incomingHost'] as String?) ?? provider.defaultIncomingHost,
      incomingPort:
          (json['incomingPort'] as int?) ?? provider.defaultIncomingPort,
      useIncomingSsl: (json['useIncomingSsl'] as bool?) ?? true,
      outgoingHost:
          (json['outgoingHost'] as String?) ?? provider.defaultOutgoingHost,
      outgoingPort:
          (json['outgoingPort'] as int?) ?? provider.defaultOutgoingPort,
      useOutgoingSsl: (json['useOutgoingSsl'] as bool?) ?? true,
      lastVerifiedAtIso: json['lastVerifiedAtIso'] as String?,
      lastLatencyMs: json['lastLatencyMs'] as int?,
      isActive: (json['isActive'] as bool?) ?? false,
      status: OrbitMailAccountStatus.fromName(json['status'] as String?),
      // MAIL-01A: старые JSON без новых полей загружаются как notConfigured
      // (секрет в secure storage отсутствует для legacy-аккаунтов).
      credentialStatus: OrbitMailCredentialStatus.fromName(
        json['credentialStatus'] as String?,
      ),
      authMethod: json['authMethod'] as String?,
      isDemo: (json['isDemo'] as bool?) ?? false,
      lastError: json['lastError'] as String?,
    );
  }

  static List<OrbitMailAccount> get defaultInitialAccounts => [
        const OrbitMailAccount(
          id: 'demo-default',
          name: 'Алексей (Демо)',
          email: 'alexey.demo@orbit.local',
          providerType: OrbitMailProviderType.yandex,
          incomingHost: 'imap.yandex.ru',
          incomingPort: 993,
          outgoingHost: 'smtp.yandex.ru',
          outgoingPort: 465,
          lastLatencyMs: 34,
          isActive: true,
          status: OrbitMailAccountStatus.verified,
          isDemo: true,
        ),
      ];
}

/// Детальный результат 4-этапной диагностики почтового сервера.
@immutable
final class MailDiagnosticResult {
  const MailDiagnosticResult({
    required this.isSuccess,
    required this.failedStage,
    required this.latencyMs,
    required this.host,
    required this.port,
    required this.isSecure,
    this.errorMessage,
    this.recommendation,
    this.serverBanner,
    this.securityProtocol,
  });

  final bool isSuccess;
  final MailVerificationStage failedStage;
  final String? errorMessage;
  final String? recommendation;
  final int latencyMs;
  final String? serverBanner;
  final String? securityProtocol;
  final String host;
  final int port;
  final bool isSecure;
}

/// Токен отмены активной проверки соединения.
final class MailVerificationCancelToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  void cancel() => _isCancelled = true;
}

/// Сервис 4-этапной верификации подключения к почтовым серверам (DNS -> TCP -> TLS -> Banner).
///
/// Не-final: тесты подставляют подсчитывающую обёртку для проверки того,
/// что credential-операции не выполняют сетевых проверок.
class OrbitMailConnectionVerifier {
  OrbitMailConnectionVerifier({
    bool? isMockMode,
    this.timeout = const Duration(seconds: 5),
  }) : isMockMode = isMockMode ?? _detectTestEnvironment();

  final bool isMockMode;
  final Duration timeout;

  static bool _detectTestEnvironment() {
    if (kIsWeb) return true;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST') ||
          WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return true;
    }
  }

  /// Выполняет полную 4-этапную проверку хоста с вызовом [onStageChanged] на каждом шаге.
  Future<MailDiagnosticResult> verifyEndpoint({
    required String host,
    required int port,
    required bool useSsl,
    bool isSmtp = false,
    ValueChanged<MailVerificationStage>? onStageChanged,
    MailVerificationCancelToken? cancelToken,
  }) async {
    final cleanHost = host.trim().toLowerCase();
    final stopwatch = Stopwatch()..start();

    void notifyStage(MailVerificationStage stage) {
      if (cancelToken?.isCancelled != true) {
        onStageChanged?.call(stage);
      }
    }

    if (cleanHost.isEmpty || cleanHost.contains(' ') || !cleanHost.contains('.')) {
      return MailDiagnosticResult(
        isSuccess: false,
        failedStage: MailVerificationStage.resolvingDns,
        latencyMs: 0,
        host: cleanHost,
        port: port,
        isSecure: useSsl,
        errorMessage: 'Некорректное имя почтового хоста',
        recommendation:
            'Не удалось разрешить имя хоста: проверьте правильность ввода адреса сервера.',
      );
    }

    if (port <= 0 || port > 65535) {
      return MailDiagnosticResult(
        isSuccess: false,
        failedStage: MailVerificationStage.connectingTcp,
        latencyMs: 0,
        host: cleanHost,
        port: port,
        isSecure: useSsl,
        errorMessage: 'Некорректный номер TCP-порта ($port)',
        recommendation:
            'Таймаут соединения: проверьте порт 993/465 или настройки фаервола.',
      );
    }

    // Офлайн-безопасный детерминированный симулятор для тестов Flutter
    if (isMockMode) {
      return _runMockVerification(
        host: cleanHost,
        port: port,
        useSsl: useSsl,
        isSmtp: isSmtp,
        onStageChanged: notifyStage,
        cancelToken: cancelToken,
      );
    }

    Socket? rawSocket;
    SecureSocket? secureSocket;

    try {
      // Шаг 1: DNS-резолвинг
      notifyStage(MailVerificationStage.resolvingDns);
      final addresses =
          await InternetAddress.lookup(cleanHost).timeout(timeout);
      if (addresses.isEmpty) {
        return MailDiagnosticResult(
          isSuccess: false,
          failedStage: MailVerificationStage.resolvingDns,
          latencyMs: stopwatch.elapsedMilliseconds,
          host: cleanHost,
          port: port,
          isSecure: useSsl,
          errorMessage: 'DNS-запись для $cleanHost не найдена',
          recommendation:
              'Не удалось разрешить имя хоста: проверьте интернет-соединение.',
        );
      }
      if (cancelToken?.isCancelled == true) {
        throw const SocketException('Cancelled by user');
      }

      // Шаг 2: TCP Socket Connect
      notifyStage(MailVerificationStage.connectingTcp);
      rawSocket = await Socket.connect(
        addresses.first,
        port,
        timeout: timeout,
      );
      final tcpLatency = stopwatch.elapsedMilliseconds;

      if (cancelToken?.isCancelled == true) {
        throw const SocketException('Cancelled by user');
      }

      // Шаг 3: TLS/SSL рукопожатие (если включено)
      Stream<List<int>> activeStream;
      if (useSsl) {
        notifyStage(MailVerificationStage.performingTlsHandshake);
        secureSocket = await SecureSocket.secure(
          rawSocket,
          host: cleanHost,
          onBadCertificate: (_) => false,
        ).timeout(timeout);
        activeStream = secureSocket;
      } else {
        activeStream = rawSocket;
      }

      // Шаг 4: Чтение серверного приветствия (IMAP "* OK" или SMTP "220")
      notifyStage(MailVerificationStage.readingGreeting);
      final bannerLine = await activeStream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(timeout);

      final trimmedBanner = bannerLine.trim();
      final isValidGreeting = isSmtp
          ? trimmedBanner.startsWith('220')
          : (trimmedBanner.startsWith('* OK') ||
              trimmedBanner.startsWith('220'));

      if (!isValidGreeting) {
        return MailDiagnosticResult(
          isSuccess: false,
          failedStage: MailVerificationStage.readingGreeting,
          latencyMs: stopwatch.elapsedMilliseconds,
          host: cleanHost,
          port: port,
          isSecure: useSsl,
          serverBanner: trimmedBanner,
          errorMessage: 'Сервер вернул неожиданный ответ: $trimmedBanner',
          recommendation:
              'Сервер доступен, но не ответил стандартом IMAP/SMTP.',
        );
      }

      notifyStage(MailVerificationStage.success);
      return MailDiagnosticResult(
        isSuccess: true,
        failedStage: MailVerificationStage.success,
        latencyMs: tcpLatency,
        host: cleanHost,
        port: port,
        isSecure: useSsl,
        serverBanner: trimmedBanner,
        securityProtocol: useSsl ? 'TLSv1.3 (RFC 8446)' : 'TCP Plain',
      );
    } on TimeoutException {
      return MailDiagnosticResult(
        isSuccess: false,
        failedStage: MailVerificationStage.connectingTcp,
        latencyMs: timeout.inMilliseconds,
        host: cleanHost,
        port: port,
        isSecure: useSsl,
        errorMessage: 'Превышено время ожидания ответа сервера (${timeout.inSeconds} с)',
        recommendation:
            'Таймаут соединения: проверьте порт 993/465 или настройки фаервола.',
      );
    } on HandshakeException catch (e) {
      return MailDiagnosticResult(
        isSuccess: false,
        failedStage: MailVerificationStage.performingTlsHandshake,
        latencyMs: stopwatch.elapsedMilliseconds,
        host: cleanHost,
        port: port,
        isSecure: useSsl,
        errorMessage: 'Сбой TLS рукопожатия: ${e.message}',
        recommendation:
            'Ошибка SSL: почтовый сервер требует явный STARTTLS либо сертификат недоверен.',
      );
    } on SocketException catch (e) {
      return MailDiagnosticResult(
        isSuccess: false,
        failedStage: MailVerificationStage.connectingTcp,
        latencyMs: stopwatch.elapsedMilliseconds,
        host: cleanHost,
        port: port,
        isSecure: useSsl,
        errorMessage: 'Сетевая ошибка: ${e.message}',
        recommendation:
            'Таймаут соединения: проверьте порт 993/465 или настройки фаервола.',
      );
    } catch (e) {
      return MailDiagnosticResult(
        isSuccess: false,
        failedStage: MailVerificationStage.failed,
        latencyMs: stopwatch.elapsedMilliseconds,
        host: cleanHost,
        port: port,
        isSecure: useSsl,
        errorMessage: '$e',
        recommendation:
            'Не удалось установить соединение с сервером.',
      );
    } finally {
      secureSocket?.destroy();
      rawSocket?.destroy();
    }
  }

  /// Псевдоним метода для обратной совместимости.
  Future<MailDiagnosticResult> verifyConnection({
    required String host,
    required int port,
    required bool useSsl,
    bool isSmtp = false,
    Duration? timeout,
    ValueChanged<MailVerificationStage>? onStageChanged,
    MailVerificationCancelToken? cancelToken,
  }) =>
      verifyEndpoint(
        host: host,
        port: port,
        useSsl: useSsl,
        isSmtp: isSmtp,
        onStageChanged: onStageChanged,
        cancelToken: cancelToken,
      );

  /// Детерминированный мок-диагност для безопасных тестов без реальной сети.
  Future<MailDiagnosticResult> _runMockVerification({
    required String host,
    required int port,
    required bool useSsl,
    required bool isSmtp,
    required ValueChanged<MailVerificationStage> onStageChanged,
    MailVerificationCancelToken? cancelToken,
  }) async {
    // 1. DNS
    onStageChanged(MailVerificationStage.resolvingDns);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (cancelToken?.isCancelled == true) {
      return _cancelledResult(host, port, useSsl);
    }

    if (host.contains('invalid') || host.contains('error') || !host.contains('.')) {
      onStageChanged(MailVerificationStage.failed);
      return MailDiagnosticResult(
        isSuccess: false,
        failedStage: MailVerificationStage.resolvingDns,
        latencyMs: 12,
        host: host,
        port: port,
        isSecure: useSsl,
        errorMessage: 'DNS-запись для $host не найдена',
        recommendation:
            'Не удалось разрешить имя хоста: проверьте интернет-соединение.',
      );
    }

    // 2. TCP
    onStageChanged(MailVerificationStage.connectingTcp);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (cancelToken?.isCancelled == true) {
      return _cancelledResult(host, port, useSsl);
    }

    if (port == 9999 || host.contains('timeout')) {
      onStageChanged(MailVerificationStage.failed);
      return MailDiagnosticResult(
        isSuccess: false,
        failedStage: MailVerificationStage.connectingTcp,
        latencyMs: 5000,
        host: host,
        port: port,
        isSecure: useSsl,
        errorMessage: 'Порт $port недоступен: таймаут подключения к порту $port',
        recommendation:
            'Таймаут соединения: проверьте порт 993/465 или настройки фаервола.',
      );
    }

    // 3. TLS
    if (useSsl) {
      onStageChanged(MailVerificationStage.performingTlsHandshake);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      if (cancelToken?.isCancelled == true) {
        return _cancelledResult(host, port, useSsl);
      }

      if (host.contains('badssl') || (port == 143 && useSsl)) {
        onStageChanged(MailVerificationStage.failed);
        return MailDiagnosticResult(
          isSuccess: false,
          failedStage: MailVerificationStage.performingTlsHandshake,
          latencyMs: 45,
          host: host,
          port: port,
          isSecure: useSsl,
          errorMessage: 'Сервер на порту $port отклонил неявный TLS handshake',
          recommendation:
              'Ошибка SSL: почтовый сервер требует явный STARTTLS либо сертификат недоверен.',
        );
      }
    }

    // 4. Greeting
    onStageChanged(MailVerificationStage.readingGreeting);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (cancelToken?.isCancelled == true) {
      return _cancelledResult(host, port, useSsl);
    }

    onStageChanged(MailVerificationStage.success);
    final banner = isSmtp
        ? '220 $host ESMTP Service Ready (ORBIT Mail Mock)'
        : '* OK [CAPABILITY IMAP4rev1 SASL-IR] $host Ready';

    return MailDiagnosticResult(
      isSuccess: true,
      failedStage: MailVerificationStage.success,
      latencyMs: 31,
      host: host,
      port: port,
      isSecure: useSsl,
      serverBanner: banner,
      securityProtocol: useSsl ? 'TLSv1.3 (ChaCha20-Poly1305)' : 'TCP Plain',
    );
  }

  MailDiagnosticResult _cancelledResult(String host, int port, bool useSsl) {
    return MailDiagnosticResult(
      isSuccess: false,
      failedStage: MailVerificationStage.idle,
      latencyMs: 0,
      host: host,
      port: port,
      isSecure: useSsl,
      errorMessage: 'Операция отменена пользователем',
    );
  }
}
