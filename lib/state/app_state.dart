import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';

import '../core/module_interfaces.dart';
import '../data/demo_data.dart';
import '../data/drift_local_state_repository.dart';
import '../data/orbit_corrupt_data.dart';
import '../data/orbit_load_status.dart';
import '../data/orbit_local_state_codec.dart';
import '../data/orbit_local_state_repository.dart';
import '../data/orbit_secure_store.dart';
import '../services/brain/gemini_brain_engine.dart';
import '../services/mail/imap_mail_transport.dart';
import '../services/mail/mail_connection_verifier.dart';
import '../services/mail/mail_models.dart';
import '../services/mail/orbit_mail_credential_service.dart';
import '../services/mail/orbit_mail_oauth_service.dart';
import 'draft_state.dart';

final class OrbitAppState extends ChangeNotifier {
  OrbitAppState([
    OrbitLocalStateRepository? repository,
    OrbitSecretStore? secretStore,
    OrbitOAuthClient? oauthClient,
    OrbitMailOAuthConfigOverride? oauthConfigOverride,
  ]) : _repository = repository ?? MemoryLocalStateRepository(),
       // MAIL-01A: production по умолчанию использует secure storage
       // (FlutterOrbitSecretStore); тесты подставляют MemoryOrbitSecretStore.
       _credentials = OrbitMailCredentialService(
         store: secretStore ?? const FlutterOrbitSecretStore(),
       ),
       // MAIL-01B: production использует AppAuth (системный browser);
       // тесты подставляют mock double.
       _oauthClient = oauthClient ?? const AppAuthOAuthClient(),
       _oauthConfigOverride = oauthConfigOverride {
    unawaited(load());
  }

  final OrbitLocalStateRepository _repository;
  final OrbitMailCredentialService _credentials;
  final OrbitOAuthClient _oauthClient;
  final OrbitMailOAuthConfigOverride? _oauthConfigOverride;
  bool _oauthFlowInProgress = false;

  /// MAIL-01A: credential-сервис доступен только чтению состояния — сам
  /// секрет наружу (UI/модель/снапшот) не отдаётся.
  @visibleForTesting
  OrbitMailCredentialService get mailCredentialService => _credentials;

  /// MAIL-01B: идёт ли сейчас OAuth-браузер flow (защита от двойного
  /// запуска).
  @visibleForTesting
  bool get isMailOAuthFlowInProgress => _oauthFlowInProgress;

  /// MAIL-01A: test hook — подсчитывающая обёртка верификатора для проверки
  /// «credential-операции не выполняют сетевых проверок».
  @visibleForTesting
  set debugMailVerifierForTest(OrbitMailConnectionVerifier verifier) {
    _mailVerifier = verifier;
  }
  List<DemoTask> _tasks = List.of(initialTasks);
  List<DemoEvent> _events = List.of(demoEvents);
  final Set<String> _readEmails = <String>{};
  final Set<String> _deletedEmails = <String>{};
  final Set<String> _starredEmails = <String>{};
  final Set<String> _unstarredEmails = <String>{};
  OrbitMailFolder _currentMailFolder = OrbitMailFolder.inbox;
  final Set<String> _trashEmails = <String>{};
  final Set<String> _spamEmails = <String>{};
  final Set<String> _archiveEmails = <String>{};
  final Set<String> _outboxEmails = <String>{};
  final Set<String> _permanentlyDeletedEmails = <String>{};
  final List<OrbitSentMailEntry> _sentEmails = <OrbitSentMailEntry>[];
  final List<OrbitMailAccount> _mailAccounts = List.of(initialMailAccounts);
  final List<BrainChatMessage> _brainChatHistory = <BrainChatMessage>[];
  OrbitMailConnectionVerifier _mailVerifier = OrbitMailConnectionVerifier();
  int _quickActionCounter = 0;
  DraftState _draft = const DraftState();
  DraftState _lastSavedDraft = const DraftState();
  Object? lastPersistenceError;
  Object? lastLoadError;
  OrbitLoadStatus _loadStatus = OrbitLoadStatus.unloaded;
  int _editRevision = 0;
  int _dataRevision = 0;
  Map<String, Object?>? _pendingSnapshot;
  Future<void> _saveQueue = Future<void>.value();
  Future<void> _lastSave = Future<void>.value();

  int get dataRevision => _dataRevision;
  void _notify() {
    _dataRevision++;
    notifyListeners();
  }

  OrbitLocalStateRepository get repository => _repository;
  List<DemoTask> get tasks => List.unmodifiable(_tasks);
  List<DemoEvent> get events => List.unmodifiable(_events);
  int get quickActionCounter => _quickActionCounter;
  int get completedTasks => _tasks.where((task) => task.done).length;
  OrbitLoadStatus get loadStatus => _loadStatus;
  bool get _canEdit => _loadStatus == OrbitLoadStatus.loaded;
  DraftState get draft => _draft;
  DraftState get lastSavedDraft => _lastSavedDraft;
  bool get hasUnsavedDraftChanges => _draft != _lastSavedDraft;
  String get draftTo => _draft.to;
  String get draftSubject => _draft.subject;
  String get draftBody => _draft.body;
  int unreadCount(List<DemoEmail> emails) => emails
      .where((email) => email.unread && !_readEmails.contains(email.id))
      .length;

  DemoTask? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  DemoEvent? eventById(String id) {
    for (final event in _events) {
      if (event.id == id) return event;
    }
    return null;
  }

  bool isRead(DemoEmail email) =>
      !email.unread || _readEmails.contains(email.id);

  bool isDeleted(String id) => _deletedEmails.contains(id);

  bool isStarred(DemoEmail email) {
    if (_starredEmails.contains(email.id)) return true;
    if (_unstarredEmails.contains(email.id)) return false;
    return email.starred;
  }

  bool toggleStarred(String id, bool defaultStarred) {
    final currentlyStarred = _starredEmails.contains(id) ||
        (defaultStarred && !_unstarredEmails.contains(id));
    if (currentlyStarred) {
      _starredEmails.remove(id);
      _unstarredEmails.add(id);
    } else {
      _unstarredEmails.remove(id);
      _starredEmails.add(id);
    }
    _changed();
    return !currentlyStarred;
  }

  OrbitMailFolder get currentMailFolder => _currentMailFolder;
  Set<String> get trashEmails => Set<String>.unmodifiable(_trashEmails);
  Set<String> get spamEmails => Set<String>.unmodifiable(_spamEmails);
  Set<String> get archiveEmails => Set<String>.unmodifiable(_archiveEmails);
  Set<String> get outboxEmails => Set<String>.unmodifiable(_outboxEmails);
  Set<String> get permanentlyDeletedEmails =>
      Set<String>.unmodifiable(_permanentlyDeletedEmails);
  List<OrbitSentMailEntry> get sentEmails =>
      List<OrbitSentMailEntry>.unmodifiable(_sentEmails);
  List<OrbitMailAccount> get mailAccounts =>
      List<OrbitMailAccount>.unmodifiable(_mailAccounts);
  OrbitMailAccount get activeMailAccount => _mailAccounts.firstWhere(
        (a) => a.isActive,
        orElse: () => _mailAccounts.isNotEmpty
            ? _mailAccounts.first
            : initialMailAccounts.first,
      );

  void addMailAccount(OrbitMailAccount account) {
    if (account.isActive) {
      for (var i = 0; i < _mailAccounts.length; i++) {
        _mailAccounts[i] = _mailAccounts[i].copyWith(isActive: false);
      }
    }
    _mailAccounts.add(account);
    _changed();
  }


  void setActiveMailAccount(String id) {
    var found = false;
    for (var i = 0; i < _mailAccounts.length; i++) {
      if (_mailAccounts[i].id == id) {
        _mailAccounts[i] = _mailAccounts[i].copyWith(isActive: true);
        found = true;
      } else if (_mailAccounts[i].isActive) {
        _mailAccounts[i] = _mailAccounts[i].copyWith(isActive: false);
      }
    }
    if (found) _changed();
  }

  void updateMailAccount(OrbitMailAccount account) {
    final index = _mailAccounts.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      _mailAccounts[index] = account;
      _changed();
    }
  }

  /// MAIL-01A: сохранить/обновить аккаунт вместе с app password.
  ///
  /// Секрет пишется ТОЛЬКО в secure storage (через credential service);
  /// metadata — через обычный save queue. Компенсация ошибок (fail-closed):
  /// - падение записи секрета → metadata вообще не трогается;
  /// - падение metadata save → откат metadata в памяти + удаление нового
  ///   секрета (или восстановление прежнего из локального backup, который
  ///   живёт только внутри метода и не попадает в persistent state/логи);
  /// - успешный результат даёт `credentialStatus = savedUnverified`
  ///   (настоящая аутентификация появится только в MAIL-02).
  Future<void> saveMailAccountWithCredentials(
    OrbitMailAccount account, {
    String? appPassword,
    OrbitOAuthTokenSet? oauthTokens,
  }) async {
    if (account.id.trim().isEmpty) {
      throw const OrbitMailCredentialException(
        'Некорректный идентификатор аккаунта',
      );
    }
    final index = _mailAccounts.indexWhere((a) => a.id == account.id);
    final isNew = index == -1;
    final previous = isNew ? null : _mailAccounts[index];
    final trimmedPassword = (appPassword ?? '').trim();
    final replacingPassword = trimmedPassword.isNotEmpty;
    final savingOAuth = oauthTokens != null;
    final replacingSecret = replacingPassword || savingOAuth;

    if (isNew && !replacingSecret) {
      throw const OrbitMailCredentialException(
        'Для нового аккаунта нужен пароль приложения или OAuth-вход',
      );
    }
    if (replacingPassword && savingOAuth) {
      throw const OrbitMailCredentialException(
        'Нельзя сохранять одновременно пароль приложения и OAuth-токены',
      );
    }

    // Локальный (только в методе) backup прежнего секрета для отката замены.
    String? previousAppPassword;
    OrbitOAuthTokenSet? previousOAuthTokens;
    if (!isNew) {
      if (replacingPassword) {
        previousAppPassword = await _credentials.readAppPasswordForTransport(
          account.id,
        );
      }
      if (savingOAuth) {
        previousOAuthTokens = await _credentials.readOAuthTokens(account.id);
      }
    }

    // 1. Секрет — только при явной записи нового.
    if (replacingPassword) {
      await _credentials.saveAppPassword(
        accountId: account.id,
        appPassword: trimmedPassword,
      );
    }
    if (savingOAuth) {
      await _credentials.saveOAuthTokens(
        accountId: account.id,
        tokens: oauthTokens,
      );
    }

    // 2. Metadata с не-secret credential-статусом.
    final hasSecret =
        replacingSecret ||
        (!isNew && await _credentials.hasAccountSecret(account.id));
    final effective = account.copyWith(
      credentialStatus: hasSecret
          ? OrbitMailCredentialStatus.savedUnverified
          : OrbitMailCredentialStatus.notConfigured,
      authMethod: hasSecret
          ? (savingOAuth ? 'oauth' : 'appPassword')
          : null,
    );
    if (isNew) {
      if (effective.isActive) {
        for (var i = 0; i < _mailAccounts.length; i++) {
          _mailAccounts[i] = _mailAccounts[i].copyWith(isActive: false);
        }
      }
      _mailAccounts.add(effective);
    } else {
      _mailAccounts[index] = effective;
    }
    _changed();
    try {
      await flush();
    } catch (_) {
      // 3. Компенсация: metadata не записались — откатываем память и
      // возвращаем secure storage в прежнее состояние (по типу секрета).
      if (isNew) {
        _mailAccounts.removeWhere((a) => a.id == effective.id);
      } else if (previous != null) {
        _mailAccounts[index] = previous;
      }
      _notify();
      if (replacingSecret) {
        try {
          if (replacingPassword) {
            if (previousAppPassword != null) {
              await _credentials.saveAppPassword(
                accountId: account.id,
                appPassword: previousAppPassword,
              );
            } else {
              await _credentials.deleteAppPassword(account.id);
            }
          } else {
            if (previousOAuthTokens != null) {
              await _credentials.saveOAuthTokens(
                accountId: account.id,
                tokens: previousOAuthTokens,
              );
            } else {
              await _credentials.deleteOAuthTokens(account.id);
            }
          }
        } on OrbitMailCredentialException {
          throw const OrbitMailCredentialException(
            'Не удалось сохранить аккаунт; дополнительно не удалось '
            'восстановить прежнее состояние секрета — повторите попытку',
          );
        }
      }
      throw const OrbitMailCredentialException(
        'Не удалось сохранить аккаунт; изменения отменены',
      );
    }
  }

  /// MAIL-01A: удалить аккаунт с гарантиями против orphan-секретов.
  ///
  /// - удаление из памяти применяется синхронно (UI отражает сразу), но
  ///   PERSIST откладывается до успешного secure delete: крах между шагами
  ///   оставляет аккаунт в snapshot (без orphan-секрета) и load()
  ///   приводит metadata к согласованному состоянию;
  /// - secure delete падает → metadata восстанавливается без изменений,
  ///   sanitized error;
  /// - секрет удалён, metadata delete упал → секрет НЕ восстанавливается
  ///   (orphan secret не создаётся); скомпенсированное `notConfigured` +
  ///   `authMethod = null` сохраняется в память И в snapshot (повторная
  ///   ошибка сохранения допускается — согласованность гарантирует
  ///   reconciliation при следующем load, см. load()).
  Future<void> removeMailAccountSecurely(String id) async {
    final index = _mailAccounts.indexWhere((a) => a.id == id);
    if (index == -1) return;
    final removed = _mailAccounts[index];
    final wasActive = removed.isActive;

    // 1. Синхронное удаление из памяти (без persist).
    _mailAccounts.removeAt(index);
    if (wasActive && _mailAccounts.isNotEmpty) {
      _mailAccounts[0] = _mailAccounts[0].copyWith(isActive: true);
    }
    _notify();

    // 2. Secure delete. Падение → metadata восстанавливается как была.
    try {
      await _credentials.deleteAppPassword(id);
    } on OrbitMailCredentialException {
      _mailAccounts.insert(
        index.clamp(0, _mailAccounts.length),
        removed,
      );
      if (!_mailAccounts.any((a) => a.isActive) && _mailAccounts.isNotEmpty) {
        _mailAccounts[0] = _mailAccounts[0].copyWith(isActive: true);
      }
      _notify();
      rethrow;
    }

    // 3. Persist удаления.
    _changed();
    try {
      await flush();
    } catch (_) {
      // 4. Metadata delete упал, секрет уже удалён: приводим metadata к
      // согласованному состоянию (notConfigured, authMethod = null) в
      // памяти И пытаемся сохранить это в snapshot; повторная ошибка
      // сохранения допускается — load() пересчитывает effective status
      // по фактическому наличию секрета.
      final restoredIndex = index.clamp(0, _mailAccounts.length);
      _mailAccounts.insert(
        restoredIndex,
        removed.copyWith(
          credentialStatus: OrbitMailCredentialStatus.notConfigured,
          clearAuthMethod: true,
        ),
      );
      if (!_mailAccounts.any((a) => a.isActive) && _mailAccounts.isNotEmpty) {
        _mailAccounts[0] = _mailAccounts[0].copyWith(isActive: true);
      }
      _changed();
      try {
        await flush();
      } catch (_) {
        // Повторная ошибка: рассогласование на диске устранит
        // reconciliation при следующем load.
      }
      throw const OrbitMailCredentialException(
        'Не удалось удалить аккаунт из локальных данных. Пароль приложения '
        'уже удалён; аккаунт помечен как «Пароль не настроен»',
      );
    }
  }

  // ===== MAIL-01B: OAuth Authorization Code + PKCE (Gmail/Outlook) =====

  /// Конфигурация провайдера для OAuth (issuer/clientId/scopes) либо
  /// [OrbitOAuthConfigRequiredException] ДО открытия browser.
  ({String issuer, String clientId, List<String> scopes, String redirectUri})
      _oauthConfigFor(OrbitMailProviderType providerType) {
    final override = _oauthConfigOverride;
    final googleClientId = override?.googleClientId ??
        (OrbitMailOAuthConfig.hasGoogleClientId
            ? OrbitMailOAuthConfig.googleClientId
            : '');
    final outlookClientId = override?.outlookClientId ??
        (OrbitMailOAuthConfig.hasOutlookClientId
            ? OrbitMailOAuthConfig.outlookClientId
            : '');
    final outlookTenant =
        override?.outlookTenant ?? OrbitMailOAuthConfig.outlookTenant;
    final redirectUri =
        override?.redirectUri ?? OrbitMailOAuthConfig.redirectUri;
    switch (providerType) {
      case OrbitMailProviderType.gmail:
        if (googleClientId.isEmpty) {
          throw const OrbitOAuthConfigRequiredException(
            'CONFIG_REQUIRED: для входа через Google приложение должно быть '
            'зарегистрировано (client ID) и передано через ORBIT_GOOGLE_CLIENT_ID',
          );
        }
        return (
          issuer: OrbitOAuthProvider.google.issuer,
          clientId: googleClientId,
          scopes: OrbitOAuthProvider.google.scopes,
          redirectUri: redirectUri,
        );
      case OrbitMailProviderType.outlook:
        if (outlookClientId.isEmpty) {
          throw const OrbitOAuthConfigRequiredException(
            'CONFIG_REQUIRED: для входа через Microsoft приложение должно '
            'быть зарегистрировано (client ID) и передано через '
            'ORBIT_OUTLOOK_CLIENT_ID',
          );
        }
        return (
          issuer: OrbitOAuthProvider.outlook.issuerFor(outlookTenant),
          clientId: outlookClientId,
          scopes: OrbitOAuthProvider.outlook.scopes,
          redirectUri: redirectUri,
        );
      default:
        throw const OrbitOAuthConfigRequiredException(
          'OAuth для этого провайдера не поддерживается',
        );
    }
  }

  /// MAIL-01B: OAuth Authorization Code + PKCE вход для Gmail/Outlook.
  ///
  /// - отсутствие config → [OrbitMailOAuthUiStatus.configRequired] ДО
  ///   открытия browser (никакой имитации live OAuth);
  /// - системный browser/Custom Tabs через AppAuth (PKCE/state/nonce
  ///   генерирует AppAuth); двойной запуск заблокирован pending-флагом;
  /// - user cancellation → прежнее состояние, без ошибки и токенов;
  /// - токены — только secure storage; metadata — только `savedUnverified`
  ///   (настоящая аутентификация IMAP появится в MAIL-02);
  /// - authorization code / tokens не попадают в логи/снапшот.
  Future<OrbitMailOAuthUiOutcome> signInMailAccountWithOAuth({
    required OrbitMailProviderType providerType,
    required String accountName,
    required String accountEmail,
  }) async {
    if (_oauthFlowInProgress) {
      return const OrbitMailOAuthUiOutcome.error(
        'OAuth-вход уже выполняется — подождите завершения',
      );
    }
    final name = accountName.trim().isEmpty
        ? providerType.label
        : accountName.trim();
    final email = accountEmail.trim();

    ({String issuer, String clientId, List<String> scopes, String redirectUri})
        config;
    try {
      config = _oauthConfigFor(providerType);
    } on OrbitOAuthConfigRequiredException catch (error) {
      return OrbitMailOAuthUiOutcome.configRequired(error.toString());
    }

    _oauthFlowInProgress = true;
    _notify();
    final OrbitOAuthTokenSet tokens;
    try {
      tokens = await _oauthClient.authorize(
        issuer: config.issuer,
        clientId: config.clientId,
        scopes: config.scopes,
        redirectUri: config.redirectUri,
      );
    } on OrbitOAuthUserCancelledException {
      _oauthFlowInProgress = false;
      _notify();
      // Отмена: прежнее состояние, без ошибки и токенов.
      return const OrbitMailOAuthUiOutcome.cancelled();
    } on OrbitOAuthConfigRequiredException catch (error) {
      _oauthFlowInProgress = false;
      _notify();
      return OrbitMailOAuthUiOutcome.configRequired(error.toString());
    } on OrbitOAuthInvalidGrantException {
      _oauthFlowInProgress = false;
      _notify();
      return const OrbitMailOAuthUiOutcome.invalidGrant(
        'Сервер отклонил вход (invalid_grant) — повторите вход',
      );
    } on OrbitOAuthTransientException catch (error) {
      _oauthFlowInProgress = false;
      _notify();
      return OrbitMailOAuthUiOutcome.error(
        'Временная ошибка входа: ${error.runtimeType.toString().isEmpty ? "повторите попытку" : "повторите попытку"}',
      );
    } catch (_) {
      _oauthFlowInProgress = false;
      _notify();
      return const OrbitMailOAuthUiOutcome.error('Вход не выполнен');
    }
    _oauthFlowInProgress = false;

    final account = OrbitMailAccount(
      id: 'acc_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      email: email.isEmpty ? 'oauth@${providerType.name}' : email,
      providerType: providerType,
      isActive: true,
    );
    try {
      await saveMailAccountWithCredentials(account, oauthTokens: tokens);
    } on OrbitMailCredentialException catch (error) {
      return OrbitMailOAuthUiOutcome.error(error.toString());
    } catch (_) {
      return const OrbitMailOAuthUiOutcome.error(
        'Не удалось сохранить аккаунт',
      );
    }
    // Возвращаем сохранённый effective-аккаунт (savedUnverified), а не
    // исходный without-credential-статус.
    final saved = _mailAccounts.firstWhere((a) => a.id == account.id);
    return OrbitMailOAuthUiOutcome.success(saved);
  }

  /// MAIL-01B: действующий access token аккаунта (для будущего mail
  /// транспорта); refresh/rotation/invalid_grant по ТЗ §7. Metadata
  /// обновляется согласно исходу refresh.
  Future<String?> getValidOAuthAccessToken(String accountId) async {
    final index = _mailAccounts.indexWhere((a) => a.id == accountId);
    if (index == -1) return null;
    final account = _mailAccounts[index];

    String? accessToken;
    try {
      accessToken = await _credentials.getValidAccessToken(
        accountId,
        refreshCallback: (refreshToken) async {
          final config = _oauthConfigFor(account.providerType);
          try {
            final tokens = await _oauthClient.refresh(
              issuer: config.issuer,
              clientId: config.clientId,
              scopes: config.scopes,
              redirectUri: config.redirectUri,
              refreshToken: refreshToken,
            );
            return OrbitAccessTokenRefreshed(tokens);
          } on OrbitOAuthInvalidGrantException {
            return const OrbitAccessTokenRefreshInvalidGrant();
          } on OrbitOAuthConfigRequiredException {
            // Конфигурация отсутствует: токены сохранены, retry после
            // настройки — не invalid_grant.
            return const OrbitAccessTokenRefreshTransient();
          } on OrbitOAuthUserCancelledException {
            return const OrbitAccessTokenRefreshTransient();
          } on OrbitOAuthTransientException {
            return const OrbitAccessTokenRefreshTransient();
          } catch (_) {
            return const OrbitAccessTokenRefreshTransient();
          }
        },
      );
    } on OrbitMailCredentialException {
      // secure storage недоступен: без ложных статусов.
      return null;
    }

    final idx = _mailAccounts.indexWhere((a) => a.id == accountId);
    if (idx == -1) return accessToken;
    if (accessToken != null) {
      // Успешный refresh/valid: статус остаётся savedUnverified (настоящая
      // аутентификация IMAP — MAIL-02).
      if (_mailAccounts[idx].credentialStatus !=
          OrbitMailCredentialStatus.savedUnverified) {
        _mailAccounts[idx] = _mailAccounts[idx].copyWith(
          credentialStatus: OrbitMailCredentialStatus.savedUnverified,
          authMethod: 'oauth',
        );
        _changed();
      }
      return accessToken;
    }
    // null: либо transient (токены сохранены), либо invalid_grant
    // (токены удалены сервисом). Сверяем факт наличия и синхронизируем
    // metadata.
    final bool hasTokens;
    try {
      hasTokens = await _credentials.hasOAuthTokens(accountId);
    } on OrbitMailCredentialException {
      return null;
    }
    if (!hasTokens) {
      // invalid_grant / пустой набор: notConfigured + без authMethod.
      if (_mailAccounts[idx].credentialStatus !=
          OrbitMailCredentialStatus.notConfigured) {
        _mailAccounts[idx] = _mailAccounts[idx].copyWith(
          credentialStatus: OrbitMailCredentialStatus.notConfigured,
          clearAuthMethod: true,
        );
        _changed();
        await flush();
      }
    }
    return null;
  }

  // ===== MAIL-02A: настоящая read-only IMAP-синхронизация =====

  ImapMailTransport? _imapTransportOverride;
  bool _realInboxSyncing = false;
  String? _lastRealInboxSyncError;
  final List<UserInboxEntry> _userInboxEntries = <UserInboxEntry>[];

  /// MAIL-02A: test hook — подмена IMAP-транспорта (fake socket с
  /// protocol capture). Production использует ImapReadOnlyClient.connect
  /// (implicit TLS 993).
  @visibleForTesting
  void debugImapTransportForTest(ImapMailTransport transport) {
    _imapTransportOverride = transport;
  }

  /// Metadata реальных писем (source_type='user') для read-only view.
  /// Отдельно от DEMO (demoEmails); без тела/HTML/вложений.
  List<UserInboxEntry> get userInboxEntries =>
      List<UserInboxEntry>.unmodifiable(_userInboxEntries);

  bool get isRealInboxSyncing => _realInboxSyncing;

  /// Sanitized сообщение последней неудачной синхронизации (без email/
  /// паролей/токенов/сырых ответов сервера).
  String? get lastRealInboxSyncError => _lastRealInboxSyncError;

  /// Настоящая IMAP-синхронизация INBOX аккаунта (ТЗ MAIL-02A §5/§9):
  /// - EXAMINE + BODY.PEEK + UID FETCH, максимум 20 писем; команды
  ///   STORE/EXPUNGE/DELETE/MOVE/COPY/APPEND в транспорте отсутствуют;
  /// - записи пишутся в production SQLite через engine над тем же файлом
  ///   (source_type='user', детерминированный id — идемпотентно);
  /// - credentialStatus -> verified ТОЛЬКО после фактического успеха
  ///   (реальная аутентификация на сервере);
  /// - отклонение аутентификации (NO от сервера / явно не настроенный
  ///   секрет): ПЕРСИСТЕНТНО notConfigured, authMethod очищается, БЕЗ
  ///   автоматического цикла повторов — guard notConfigured блокирует
  ///   sync до обновления credentials пользователем (секрет не удаляется:
  ///   форма обновления перезапишет его);
  /// - transient-ошибка (сеть/сервер/протокол, включая transient refresh):
  ///   ПЕРСИСТЕНТНО savedUnverified (в т.ч. понижение verified), секреты
  ///   сохранены, retry доступен; sanitized-сообщение пользователю.
  Future<bool> syncRealInbox(String accountId) async {
    if (_realInboxSyncing) {
      _lastRealInboxSyncError = 'Синхронизация уже выполняется';
      _notify();
      return false;
    }
    final index = _mailAccounts.indexWhere((a) => a.id == accountId);
    if (index == -1) {
      _lastRealInboxSyncError = 'Аккаунт не найден';
      _notify();
      return false;
    }
    final account = _mailAccounts[index];
    if (account.isDemo) {
      _lastRealInboxSyncError = 'Демо-аккаунт не синхронизируется по IMAP';
      _notify();
      return false;
    }
    if (account.credentialStatus == OrbitMailCredentialStatus.notConfigured) {
      _lastRealInboxSyncError = 'Учётные данные не настроены';
      _notify();
      return false;
    }
    final repository = _repository;
    if (repository is! DriftLocalStateRepository) {
      _lastRealInboxSyncError = 'Реальная почта требует production-хранилища';
      _notify();
      return false;
    }
    _realInboxSyncing = true;
    _lastRealInboxSyncError = null;
    _notify();
    try {
      final engine = await repository.mailDataEngine();
      final transport =
          _imapTransportOverride ??
          ImapMailTransport(
            resolveAccount: (id) async {
              final i = _mailAccounts.indexWhere((a) => a.id == id);
              return i == -1 ? null : _mailAccounts[i];
            },
            resolveAccessToken: (target) =>
                getValidOAuthAccessToken(target.id),
            credentialService: _credentials,
          );
      final emails = await transport.fetchEmails(
        folder: 'inbox',
        accountId: accountId,
      );
      for (final email in emails) {
        await engine.saveEmail(
          email.copyWith(workspaceId: engine.activeWorkspaceId),
        );
      }
      // Фактический IMAP-успех: только теперь credentialStatus = verified.
      final idx = _mailAccounts.indexWhere((a) => a.id == accountId);
      if (idx != -1 &&
          _mailAccounts[idx].credentialStatus !=
              OrbitMailCredentialStatus.verified) {
        _mailAccounts[idx] = _mailAccounts[idx].copyWith(
          credentialStatus: OrbitMailCredentialStatus.verified,
        );
        _changed();
        await flush();
      }
      await refreshUserInboxEntries();
      return true;
    } on ImapTransportException catch (error) {
      return _handleRealInboxFailure(accountId, error);
    } catch (_) {
      // Sanitized: детали (включая сырые ответы) не раскрываются.
      // Неизвестная ошибка трактуется как transient (не как отказ
      // аутентификации): savedUnverified, retry доступен.
      return _handleRealInboxTransient(accountId, 'Синхронизация не выполнена');
    } finally {
      _realInboxSyncing = false;
      _notify();
    }
  }

  /// Разделение исходов по ТЗ §5/§9.9: auth rejection -> персистентно
  /// notConfigured без цикла повторов; transient -> персистентно
  /// savedUnverified (в т.ч. понижение verified), retry доступен.
  Future<bool> _handleRealInboxFailure(
    String accountId,
    ImapTransportException error,
  ) {
    if (error.isAuthRelated) {
      return _handleRealInboxAuthRejected(accountId, error.message);
    }
    return _handleRealInboxTransient(accountId, error.message);
  }

  Future<bool> _handleRealInboxAuthRejected(
    String accountId,
    String sanitizedMessage,
  ) async {
    final idx = _mailAccounts.indexWhere((a) => a.id == accountId);
    if (idx != -1 &&
        _mailAccounts[idx].credentialStatus !=
            OrbitMailCredentialStatus.notConfigured) {
      _mailAccounts[idx] = _mailAccounts[idx].copyWith(
        credentialStatus: OrbitMailCredentialStatus.notConfigured,
        clearAuthMethod: true,
      );
      _changed();
      await flush();
    }
    _lastRealInboxSyncError = sanitizedMessage;
    return false;
  }

  Future<bool> _handleRealInboxTransient(
    String accountId,
    String sanitizedMessage,
  ) async {
    final idx = _mailAccounts.indexWhere((a) => a.id == accountId);
    if (idx != -1 &&
        _mailAccounts[idx].credentialStatus ==
            OrbitMailCredentialStatus.verified) {
      _mailAccounts[idx] = _mailAccounts[idx].copyWith(
        credentialStatus: OrbitMailCredentialStatus.savedUnverified,
      );
      _changed();
      await flush();
    }
    _lastRealInboxSyncError = sanitizedMessage;
    return false;
  }

  /// Перечитывает metadata реальных писем (source_type='user') из
  /// production SQLite. Вызывается после синхронизации и при открытии
  /// real-inbox view.
  Future<void> refreshUserInboxEntries() async {
    final repository = _repository;
    if (repository is! DriftLocalStateRepository) return;
    final engine = await repository.mailDataEngine();
    final rows = await engine.getUserMailRows(folder: 'inbox');
    _userInboxEntries
      ..clear()
      ..addAll(rows.map(UserInboxEntry.fromRow));
    _notify();
  }

  List<BrainChatMessage> get brainChatHistory =>
      List<BrainChatMessage>.unmodifiable(_brainChatHistory);

  void updateBrainChatHistory(List<BrainChatMessage> messages) {
    _brainChatHistory
      ..clear()
      ..addAll(messages);
    _changed();
  }

  Future<MailDiagnosticResult> verifyAccountConnection(
    OrbitMailAccount account, {
    ValueChanged<MailVerificationStage>? onStageChanged,
  }) async {
    final result = await _mailVerifier.verifyEndpoint(
      host: account.incomingHost,
      port: account.incomingPort,
      useSsl: account.useIncomingSsl,
      onStageChanged: onStageChanged,
    );

    final idx = _mailAccounts.indexWhere((a) => a.id == account.id);
    if (idx != -1) {
      _mailAccounts[idx] = _mailAccounts[idx].copyWith(
        lastLatencyMs: result.latencyMs,
        lastVerifiedAtIso: DateTime.now().toIso8601String(),
        status: result.isSuccess
            ? OrbitMailAccountStatus.verified
            : OrbitMailAccountStatus.failed,
      );
      _changed();
    }
    return result;
  }

  void selectMailFolder(OrbitMailFolder folder) {
    if (_currentMailFolder == folder) return;
    _currentMailFolder = folder;
    _changed();
  }

  OrbitMailFolder folderForEmail(String emailId) {
    if (_trashEmails.contains(emailId)) return OrbitMailFolder.trash;
    if (_spamEmails.contains(emailId)) return OrbitMailFolder.spam;
    if (_archiveEmails.contains(emailId)) return OrbitMailFolder.archive;
    if (_outboxEmails.contains(emailId)) return OrbitMailFolder.outbox;
    if (_sentEmails.any((e) => e.id == emailId)) return OrbitMailFolder.sent;
    return OrbitMailFolder.inbox;
  }

  bool isEmailInInbox(String emailId) {
    return !_permanentlyDeletedEmails.contains(emailId) &&
        !_trashEmails.contains(emailId) &&
        !_spamEmails.contains(emailId) &&
        !_archiveEmails.contains(emailId) &&
        !_outboxEmails.contains(emailId);
  }

  void moveToFolder(String emailId, OrbitMailFolder targetFolder) {
    _trashEmails.remove(emailId);
    _spamEmails.remove(emailId);
    _archiveEmails.remove(emailId);
    _outboxEmails.remove(emailId);
    _deletedEmails.remove(emailId);

    switch (targetFolder) {
      case OrbitMailFolder.trash:
        _trashEmails.add(emailId);
        _deletedEmails.add(emailId);
      case OrbitMailFolder.spam:
        _spamEmails.add(emailId);
      case OrbitMailFolder.archive:
        _archiveEmails.add(emailId);
      case OrbitMailFolder.outbox:
        _outboxEmails.add(emailId);
      case OrbitMailFolder.inbox:
      case OrbitMailFolder.sent:
      case OrbitMailFolder.drafts:
        break;
    }
    _changed();
  }

  void deleteEmail(String emailId) {
    if (_trashEmails.contains(emailId)) {
      _trashEmails.remove(emailId);
      _permanentlyDeletedEmails.add(emailId);
      _sentEmails.removeWhere((e) => e.id == emailId);
    } else {
      _trashEmails.add(emailId);
      _deletedEmails.add(emailId);
      _spamEmails.remove(emailId);
      _archiveEmails.remove(emailId);
    }
    _changed();
  }

  void restoreFromTrash(String emailId) {
    _trashEmails.remove(emailId);
    _deletedEmails.remove(emailId);
    _changed();
  }

  void restoreEmail(String emailId) => restoreFromTrash(emailId);

  void emptyTrash() {
    if (_trashEmails.isEmpty) return;
    _permanentlyDeletedEmails.addAll(_trashEmails);
    _sentEmails.removeWhere((e) => _trashEmails.contains(e.id));
    _trashEmails.clear();
    _changed();
  }

  OrbitSentMailEntry sendEmail(DraftState draft) {
    final entry = OrbitSentMailEntry(
      id: 'sent_${DateTime.now().microsecondsSinceEpoch}',
      recipient: draft.to.trim().isEmpty ? 'team@orbit.app' : draft.to.trim(),
      subject:
          draft.subject.trim().isEmpty ? 'Без темы' : draft.subject.trim(),
      body: draft.body.trim(),
      sentAtIso: DateTime.now().toIso8601String(),
    );
    _sentEmails.insert(0, entry);
    clearDraft();
    _changed();
    return entry;
  }

  void clearDraft() {
    _draft = const DraftState();
    _changed();
  }

  int badgeCountForFolder(
    OrbitMailFolder folder, {
    List<String>? allInboxIds,
    bool Function(String id)? isUnread,
    bool? hasActiveDraft,
  }) {
    final effectiveInboxIds = allInboxIds ?? demoEmails.map((e) => e.id).toList();
    final effectiveIsUnread = isUnread ?? (id) {
      final email = demoEmails.cast<DemoEmail?>().firstWhere(
            (e) => e?.id == id,
            orElse: () => null,
          );
      return email != null && !isRead(email);
    };
    final effectiveHasDraft = hasActiveDraft ??
        (draft.subject.isNotEmpty || draft.body.isNotEmpty || draft.to.isNotEmpty);

    return switch (folder) {
      OrbitMailFolder.inbox => effectiveInboxIds
          .where((id) => isEmailInInbox(id) && effectiveIsUnread(id))
          .length,
      OrbitMailFolder.sent => _sentEmails
          .where((e) => !_trashEmails.contains(e.id))
          .length,
      OrbitMailFolder.drafts => effectiveHasDraft ? 1 : 0,
      OrbitMailFolder.outbox => _outboxEmails.length,
      OrbitMailFolder.archive => _archiveEmails.length,
      OrbitMailFolder.trash => _trashEmails.length,
      OrbitMailFolder.spam => _spamEmails.length,
    };
  }

  List<DemoEvent> eventsOn(DateTime day) {
    return _events
        .where((event) {
          final date = event.date;
          if (date != null) return DateUtils.isSameDay(date, day);
          final demoIndex = switch (event.id) {
            'review' => 0,
            'audit' => 1,
            'report' => 2,
            _ => -1,
          };
          return demoIndex >= 0 &&
              DateUtils.isSameDay(
                clock.now().add(Duration(days: demoIndex)),
                day,
              );
        })
        .toList(growable: false);
  }

  void setLoadError(Object? error) {
    _loadStatus = error == null
        ? OrbitLoadStatus.unloaded
        : OrbitLoadStatus.transientFailure;
    lastLoadError = error;
    _notify();
  }

  Future<void> load() async {
    if (_loadStatus == OrbitLoadStatus.loaded) return;
    _loadStatus = OrbitLoadStatus.loading;
    final revision = _editRevision;
    try {
      final state = await _repository.load();
      OrbitLocalStateCodec.validate(state);
      final tasks = state['tasks'] == null
          ? List<DemoTask>.of(initialTasks)
          : <DemoTask>[
              for (final item in state['tasks']! as List<Object?>)
                DemoTask.fromJson(item! as Map<String, Object?>),
            ];
      final events = state['events'] == null
          ? List<DemoEvent>.of(demoEvents)
          : <DemoEvent>[
              for (final item in state['events']! as List<Object?>)
                DemoEvent.fromJson(item! as Map<String, Object?>),
            ];
      final readEmails = <String>{
        for (final item in state['readEmails'] as List<Object?>? ?? const [])
          item as String,
      };
      final deletedEmails = <String>{
        for (final item in state['deletedEmails'] as List<Object?>? ?? const [])
          item as String,
      };
      final starredEmails = <String>{
        for (final item in state['starredEmails'] as List<Object?>? ?? const [])
          item as String,
      };
      final unstarredEmails = <String>{
        for (final item in state['unstarredEmails'] as List<Object?>? ?? const [])
          item as String,
      };
      final draft = DraftState.fromJson(state);
      if (_loadStatus == OrbitLoadStatus.loaded) return;
      if (revision != _editRevision) {
        _loadStatus = OrbitLoadStatus.loaded;
        lastLoadError = null;
        if (_pendingSnapshot != null) _persist();
        return;
      }
      _tasks = tasks;
      _events = events;
      _readEmails
        ..clear()
        ..addAll(readEmails);
      _deletedEmails
        ..clear()
        ..addAll(deletedEmails);
      _starredEmails
        ..clear()
        ..addAll(starredEmails);
      _unstarredEmails
        ..clear()
        ..addAll(unstarredEmails);
      _currentMailFolder =
          OrbitMailFolder.fromName(state['currentMailFolder'] as String?);
      _trashEmails
        ..clear()
        ..addAll((state['trashEmails'] as List<Object?>? ?? const [])
            .whereType<String>());
      _spamEmails
        ..clear()
        ..addAll((state['spamEmails'] as List<Object?>? ?? const [])
            .whereType<String>());
      _archiveEmails
        ..clear()
        ..addAll((state['archiveEmails'] as List<Object?>? ?? const [])
            .whereType<String>());
      _outboxEmails
        ..clear()
        ..addAll((state['outboxEmails'] as List<Object?>? ?? const [])
            .whereType<String>());
      _permanentlyDeletedEmails
        ..clear()
        ..addAll((state['permanentlyDeletedEmails'] as List<Object?>? ?? const [])
            .whereType<String>());
      _sentEmails
        ..clear()
        ..addAll(
          (state['sentEmails'] as List<Object?>? ?? const [])
              .whereType<Map<String, Object?>>()
              .map(OrbitSentMailEntry.fromJson),
        );
      final mailAccountsRaw = (state['mailAccounts'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(OrbitMailAccount.fromJson)
          .toList();
      _mailAccounts
        ..clear()
        ..addAll(mailAccountsRaw.isNotEmpty ? mailAccountsRaw : initialMailAccounts);
      // MAIL-01A fix: reconcile credential metadata against the ACTUAL
      // secret presence in secure storage. A stale snapshot (e.g. after a
      // metadata-delete failure) must never resurrect «savedUnverified»
      // without a secret; a secure-storage read error is handled
      // explicitly — no false states, reconciliation retries on the next
      // successful load.
      var credentialsReconciled = false;
      for (var i = 0; i < _mailAccounts.length; i++) {
        final account = _mailAccounts[i];
        if (account.isDemo ||
            account.credentialStatus ==
                OrbitMailCredentialStatus.notConfigured) {
          continue;
        }
        final bool hasSecret;
        try {
          hasSecret = await _credentials.hasAccountSecret(account.id);
        } on OrbitMailCredentialException {
          continue;
        }
        if (!hasSecret) {
          _mailAccounts[i] = account.copyWith(
            credentialStatus: OrbitMailCredentialStatus.notConfigured,
            clearAuthMethod: true,
          );
          credentialsReconciled = true;
        }
      }
      final chatRaw = (state['brainChatHistory'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(BrainChatMessage.fromJson)
          .toList();
      _brainChatHistory
        ..clear()
        ..addAll(chatRaw);
      _draft = draft;
      _lastSavedDraft = _draft;
      _loadStatus = OrbitLoadStatus.loaded;
      lastLoadError = null;
      if (credentialsReconciled) {
        // Persist the reconciled credential metadata so the snapshot never
        // carries a «saved» status without a secret.
        _persist();
      }
    } catch (error) {
      _loadStatus = error is OrbitCorruptDataException
          ? OrbitLoadStatus.corrupt
          : OrbitLoadStatus.transientFailure;
      lastLoadError = error;
    }
    _notify();
  }

  void markRead(String id) {
    if (_readEmails.add(id)) _changed();
  }

  void toggleTask(String id) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(done: !_tasks[index].done);
    _changed();
  }

  void setTaskPriority(String id, int priority) {
    final index = _tasks.indexWhere((task) => task.id == id);
    if (index < 0) return;
    _tasks[index] = _tasks[index].copyWith(priority: priority.clamp(0, 2));
    _changed();
  }

  void addTask(String title) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    _tasks.insert(
      0,
      DemoTask(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        title: clean,
        project: 'local-list',
        due: 'no-due',
      ),
    );
    _changed();
  }

  void clearCompletedTasks() {
    _tasks.removeWhere((task) => task.done);
    _changed();
  }

  void markAllTasksDone() {
    for (var i = 0; i < _tasks.length; i++) {
      if (!_tasks[i].done) {
        _tasks[i] = _tasks[i].copyWith(done: true);
      }
    }
    _changed();
  }

  void addEvent(String title, String time, DateTime date) {
    final clean = title.trim();
    if (clean.isEmpty) return;
    _events.add(
      DemoEvent(
        'local-event-${DateTime.now().microsecondsSinceEpoch}',
        time,
        clean,
        'local-list',
        const Color(0xFF9B8CFF),
        date: date,
      ),
    );
    _changed();
  }

  void registerQuickAction() {
    _quickActionCounter++;
    _notify();
  }

  void updateDraft({String? to, String? subject, String? body}) {
    final updated = _draft.copyWith(to: to, subject: subject, body: body);
    if (updated == _draft) return;
    _draft = updated;
    _editRevision++;
    _notify();
    _persist();
  }

  void startReply(
    DemoEmail email, {
    required String localizedSubject,
    required String localizedBody,
    String? to,
    String? subject,
  }) {
    _draft = DraftState(
      to: to ?? email.email,
      subject: subject ?? 'Re: $localizedSubject',
      body: localizedBody,
    );
    _changed();
  }

  void _changed() {
    _editRevision++;
    _notify();
    _persist();
  }

  void _persist() {
    final snapshot = _pendingSnapshot = <String, Object?>{
      'schemaVersion': 1,
      'tasks': _tasks.map((task) => task.toJson()).toList(),
      'events': _events.map((event) => event.toJson()).toList(),
      'readEmails': _readEmails.toList()..sort(),
      'deletedEmails': _deletedEmails.toList()..sort(),
      'starredEmails': _starredEmails.toList()..sort(),
      'unstarredEmails': _unstarredEmails.toList()..sort(),
      'currentMailFolder': _currentMailFolder.name,
      'trashEmails': _trashEmails.toList()..sort(),
      'spamEmails': _spamEmails.toList()..sort(),
      'archiveEmails': _archiveEmails.toList()..sort(),
      'outboxEmails': _outboxEmails.toList()..sort(),
      'permanentlyDeletedEmails': _permanentlyDeletedEmails.toList()..sort(),
      'sentEmails': _sentEmails.map((e) => e.toJson()).toList(),
      'mailAccounts': _mailAccounts.map((e) => e.toJson()).toList(),
      'brainChatHistory': _brainChatHistory.map((m) => m.toJson()).toList(),
      ..._draft.toJson(),
    };
    if (!_canEdit) {
      lastPersistenceError = StateError(
        'Local data cannot be saved before a successful load: $_loadStatus',
      );
      _notify();
      return;
    }
    final save = _saveQueue.then((_) async {
      try {
        await _repository.save(snapshot);
        final savedDraft = DraftState.fromJson(snapshot);
        if (lastPersistenceError != null || _lastSavedDraft != savedDraft) {
          _lastSavedDraft = savedDraft;
          lastPersistenceError = null;
          _notify();
        }
      } catch (error) {
        lastPersistenceError = error;
        _notify();
        rethrow;
      }
    });
    _lastSave = save;
    _saveQueue = save.catchError((_) {});
  }

  Future<void> flush() {
    if (!_canEdit) {
      return Future<void>.error(
        lastLoadError ?? StateError('Local data is not loaded: $_loadStatus'),
      );
    }
    return _lastSave;
  }

  Future<void> retryPersistence() async {
    if (_pendingSnapshot == null) return;
    _persist();
    await flush();
  }

  Future<void> resetCorruptData() async {
    final repository = _repository;
    if (repository is! OrbitCorruptDataRecovery) {
      throw StateError('Local state recovery is unavailable');
    }
    _loadStatus = OrbitLoadStatus.resetPending;
    _notify();
    await (repository as OrbitCorruptDataRecovery).resetCorruptData();
    _loadStatus = OrbitLoadStatus.unloaded;
    _pendingSnapshot = null;
    lastLoadError = null;
    lastPersistenceError = null;
    await load();
  }
}
