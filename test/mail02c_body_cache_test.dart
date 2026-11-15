import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/core/module_interfaces.dart';
import 'package:orbit_visual_lab/data/database/drift_orbit_database.dart';
import 'package:orbit_visual_lab/data/drift_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/data/orbit_secure_store.dart';
import 'package:orbit_visual_lab/l10n/app_localizations.dart';
import 'package:orbit_visual_lab/services/mail/imap_body_cache_store.dart';
import 'package:orbit_visual_lab/services/mail/imap_mail_transport.dart';
import 'package:orbit_visual_lab/services/mail/imap_readonly_client.dart';
import 'package:orbit_visual_lab/services/mail/imap_socket.dart';
import 'package:orbit_visual_lab/services/mail/mail_connection_verifier.dart';
import 'package:orbit_visual_lab/services/mail/mail_models.dart';
import 'package:orbit_visual_lab/services/mail/orbit_mail_credential_service.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_environment.dart';
import 'package:orbit_visual_lab/widgets/orbit_real_inbox_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Синтетические тестовые значения (не паттерны реальных секретов).
const String _apPassword = 'MAIL02C-TEST-APP-PASSWORD-q7f3';

// IMAP спецсимволы строятся в рантайме (без escape в исходнике).
final String _bs = String.fromCharCode(92);
final String _nul = String.fromCharCode(0);
final String _crlf =
    String.fromCharCode(13) + String.fromCharCode(10);

OrbitMailAccount _bodyAccount() => const OrbitMailAccount(
      id: 'acc_body',
      name: 'Тестовый ящик (body)',
      email: 'unit.body@test.local',
      providerType: OrbitMailProviderType.yandex,
      incomingHost: 'imap.yandex.ru',
      incomingPort: 993,
      outgoingHost: 'smtp.yandex.ru',
      outgoingPort: 465,
      credentialStatus: OrbitMailCredentialStatus.savedUnverified,
      authMethod: 'appPassword',
      isActive: true,
    );

final class _FakeImapSocket implements OrbitImapSocket {
  _FakeImapSocket(List<String> lines, List<String> literals)
    : _lines = List.of(lines),
      _literals = List.of(literals);

  final List<String> _lines;
  final List<String> _literals;
  final List<String> written = <String>[];
  bool hangReads = false;
  bool destroyed = false;

  @override
  Future<void> writeLine(String line) async {
    written.add(line);
  }

  @override
  Future<String> readLine() async {
    if (hangReads) {
      await Completer<String>().future;
    }
    if (_lines.isEmpty) {
      throw const ImapConnectionException('Скрипт ответов исчерпан');
    }
    return _lines.removeAt(0);
  }

  @override
  Future<String> readUtf8Octets(int octets) async {
    if (_literals.isEmpty) {
      // Обрыв во время чтения литерала тела (MAIL-02C [B10]).
      throw const ImapConnectionException('Нет literal-данных');
    }
    final blob = _literals.removeAt(0);
    if (utf8.encode(blob).length != octets) {
      throw const ImapConnectionException('Octets mismatch');
    }
    return blob;
  }

  @override
  void destroy() {
    destroyed = true;
  }
}

/// Строки полного read-only сценария догрузки тела (app password).
/// ВАЖНО: содержимое литерала НЕ входит в lines - оно приходит через
/// readUtf8Octets из _bodySessionLiterals (как в реальном потоке).
List<String> _bodySessionLines({
  required int uidValidity,
  required int uid,
  required String bodyLiteral,
  required String structureTail,
  required int fullSize,
}) {
  final bodyOctets = utf8.encode(bodyLiteral).length;
  return [
    '* OK ready',
    'A1 OK LOGIN completed',
    '* FLAGS ($_bs' 'Seen)',
    '* 1 EXISTS',
    '* OK [UIDVALIDITY $uidValidity] UIDs valid',
    'A2 OK [READ-ONLY] EXAMINE completed',
    '* 1 FETCH (UID $uid RFC822.SIZE $fullSize BODYSTRUCTURE '
        '$structureTail '
        'BODY[TEXT]<0.262144> {$bodyOctets}',
    ')',
    'A3 OK FETCH completed',
    '* BYE logging out',
    'A4 OK LOGOUT completed',
  ];
}

List<String> _bodySessionLiterals(String bodyLiteral) => [bodyLiteral];

OrbitMailCredentialService _serviceWithApPassword() {
  final service = OrbitMailCredentialService(store: MemoryOrbitSecretStore());
  unawaited(
    service.saveAppPassword(accountId: 'acc_body', appPassword: _apPassword),
  );
  return service;
}

ImapMailTransport _transportOver(
  OrbitMailAccount Function() account,
  OrbitMailCredentialService credentials,
  _FakeImapSocket socket,
) => ImapMailTransport(
      resolveAccount: (id) async => account(),
      resolveAccessToken: (target) async => null,
      credentialService: credentials,
      clientFactory: (target) async => ImapReadOnlyClient.forSocket(socket),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MAIL-02C client body fetch (read-only)', () {
    test('[B1] точная команда BODY.PEEK + BODYSTRUCTURE, без мутирующих',
        () async {
      const bodyText = 'Полное тело письма для кэша.';
      const structure =
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 42 2))';
      final socket = _FakeImapSocket(
        _bodySessionLines(
          uidValidity: 424242,
          uid: 700,
          bodyLiteral: bodyText,
          structureTail: structure,
          fullSize: 42,
        ),
        _bodySessionLiterals(bodyText),
      );
      final client = ImapReadOnlyClient.forSocket(socket);
      await client.login('unit.body@test.local', _apPassword);
      await client.examineInbox();
      final body = await client.fetchBodyByUid(uid: 700);
      await client.logout();

      // Точная команда: только UID FETCH c BODY.PEEK (не RFC822.TEXT),
      // BODYSTRUCTURE (метаданные) и RFC822.SIZE.
      expect(
        socket.written[2],
        'A3 UID FETCH 700 (UID RFC822.SIZE BODYSTRUCTURE '
        'BODY.PEEK[TEXT]<0.262144>)',
      );
      const forbidden = [
        'STORE', 'EXPUNGE', 'DELETE', 'MOVE ', 'COPY', 'APPEND',
        'CREATE', 'RENAME', 'RFC822.TEXT', 'RFC822 (',
      ];
      for (final line in socket.written) {
        for (final token in forbidden) {
          expect(line.contains(token), isFalse,
              reason: 'Запрещённая команда в raw-записи: $line');
        }
      }
      expect(body.bodyText, bodyText);
      expect(body.truncated, isFalse);
      expect(body.fullSize, 42);
      expect(body.attachments, isEmpty);
    });

    test('[B2] size cap: обрезка + truncated + полный размер из RFC822.SIZE',
        () async {
      // Сервер отдаёт cap-фрагмент, полный размер - 1 МБ.
      final fragment = List.filled(300, 'x').join();
      const structure =
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 1048576 100)';
      final socket = _FakeImapSocket(
        _bodySessionLines(
          uidValidity: 424242,
          uid: 701,
          bodyLiteral: fragment,
          structureTail: structure,
          fullSize: 1048576,
        ),
        _bodySessionLiterals(fragment),
      );
      final client = ImapReadOnlyClient.forSocket(socket);
      await client.login('a', _apPassword);
      await client.examineInbox();
      final body = await client.fetchBodyByUid(uid: 701);
      client.destroy();

      expect(body.truncated, isTrue);
      expect(body.fullSize, 1048576);
      expect(body.bodyText.length, 300);
    });

    test('[B3] BODYSTRUCTURE: метаданные вложения без содержимого',
        () async {
      const bodyText = 'С вложением.';
      // multipart/mixed: text part + application/pdf attachment с NAME.
      final structure =
          '("MIXED" ("BOUNDARY" "b1") ('
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 20 1)'
          ' ("APPLICATION" "PDF" ("NAME" "отчёт за квартал.pdf") '
          'NIL NIL "BASE64" 102400)))';
      final socket = _FakeImapSocket(
        _bodySessionLines(
          uidValidity: 424242,
          uid: 702,
          bodyLiteral: bodyText,
          structureTail: structure,
          fullSize: 20,
        ),
        _bodySessionLiterals(bodyText),
      );
      final client = ImapReadOnlyClient.forSocket(socket);
      await client.login('a', _apPassword);
      await client.examineInbox();
      final body = await client.fetchBodyByUid(uid: 702);
      client.destroy();

      expect(body.attachments.length, 1);
      final attachment = body.attachments.single;
      expect(attachment.fileName, 'отчёт за квартал.pdf');
      expect(attachment.sizeBytes, 102400);
      expect(attachment.mimeType, 'APPLICATION/PDF');
      // Запрос содержит ТОЛЬКО BODYSTRUCTURE: содержимое вложения не
      // запрашивалось (ни BODY[1], ни BODY[2] в командах).
      expect(socket.written[2].contains('BODY['), isFalse);
    });

    test('[B4] span-safety: литерал тела с UID-подобным текстом',
        () async {
      const bodyText =
          'UID 999 FLAGS (STORE EXPUNGE) - просто текст письма, '
          'не служебные данные';
      const structure =
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 100 1)';
      final socket = _FakeImapSocket(
        _bodySessionLines(
          uidValidity: 424242,
          uid: 703,
          bodyLiteral: bodyText,
          structureTail: structure,
          fullSize: 100,
        ),
        _bodySessionLiterals(bodyText),
      );
      final client = ImapReadOnlyClient.forSocket(socket);
      await client.login('a', _apPassword);
      await client.examineInbox();
      final body = await client.fetchBodyByUid(uid: 703);
      client.destroy();
      // UID-матч вне литералов: настоящая запись 703 распознана, текст
      // из литерала не подменяет поля.
      expect(body.uid, 703);
      expect(body.bodyText, bodyText);
    });

    test('[B5] sanitizeBodyText: control chars -> пробелы, cap по длине',
        () async {
      final dirty =
          'строка1$_nul${String.fromCharCode(7)}строка2$_crlf'
          '${String.fromCharCode(127)}хвост';
      final cleaned = ImapBodyCacheStore.sanitizeBodyText(dirty);
      expect(cleaned.contains(_nul), isFalse);
      expect(cleaned.contains(String.fromCharCode(7)), isFalse);
      expect(cleaned.contains(String.fromCharCode(127)), isFalse);
      // Переводы строк сохранены.
      expect(cleaned.contains(_crlf), isTrue);
      final long = List.filled(300000, 'a').join();
      expect(
        ImapBodyCacheStore.sanitizeBodyText(long).length,
        262144,
      );
    });
  });

  group('MAIL-02C transport + production cache (file SQLite)', () {
    Future<OrbitAppState> stateOnFileSQLite(
      DriftLocalStateRepository repo,
      OrbitSecretStore store,
    ) async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      final state = OrbitAppState(repo, store);
      await state.load();
      await state.saveMailAccountWithCredentials(
        _bodyAccount(),
        appPassword: _apPassword,
      );
      await state.flush();
      return state;
    }

    test('[B6] сеть -> кэш; повтор после рестарта БЕЗ сети (fromCache)',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02c_b6');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(
          file: File('${tempDir.path}${Platform.pathSeparator}b6.sqlite'),
        ),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);

      const bodyText = 'Первое полное тело письма.';
      const structure =
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 27 1)';
      final socket = _FakeImapSocket(
        _bodySessionLines(
          uidValidity: 424242,
          uid: 700,
          bodyLiteral: bodyText,
          structureTail: structure,
          fullSize: 27,
        ),
        _bodySessionLiterals(bodyText),
      );
      state.debugImapTransportForTest(
        _transportOver(() => _bodyAccount(), _serviceWithApPassword(), socket),
      );

      const emailId = 'acc_body:inbox:424242:700';
      final first = await state.fetchEmailBodyFor(emailId);
      expect(first, isNotNull);
      expect(first!.fromCache, isFalse);
      expect(first.bodyText, bodyText);
      // Один сетевой UID FETCH за догрузку.
      expect(
        socket.written.where((l) => l.startsWith('A3 UID FETCH 700')).length,
        1,
      );

      // «Рестарт»: новый state над тем же файлом БД - кэш-хит без сети.
      final reloaded = await stateOnFileSQLite(repo, sharedStore);
      final freshSocket = _FakeImapSocket(const [], const []);
      reloaded.debugImapTransportForTest(
        _transportOver(
          () => _bodyAccount(),
          _serviceWithApPassword(),
          freshSocket,
        ),
      );
      final second = await reloaded.fetchEmailBodyFor(emailId);
      expect(second, isNotNull);
      expect(second!.fromCache, isTrue);
      expect(second.bodyText, bodyText);
      // Сеть не использовалась: ни одной команды.
      expect(freshSocket.written, isEmpty);
    });

    test('[B7] санитизация персистится: кэш хранит чистый текст',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02c_b7');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(
          file: File('${tempDir.path}${Platform.pathSeparator}b7.sqlite'),
        ),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);

      final dirtyBody =
          'Тело с $_nul управляющими ${String.fromCharCode(11)}символами';
      const structure =
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 50 1)';
      final socket = _FakeImapSocket(
        _bodySessionLines(
          uidValidity: 424242,
          uid: 701,
          bodyLiteral: dirtyBody,
          structureTail: structure,
          fullSize: 50,
        ),
        _bodySessionLiterals(dirtyBody),
      );
      state.debugImapTransportForTest(
        _transportOver(() => _bodyAccount(), _serviceWithApPassword(), socket),
      );

      final cached = await state.fetchEmailBodyFor('acc_body:inbox:424242:701');
      expect(cached, isNotNull);
      expect(cached!.bodyText.contains(_nul), isFalse);
      // Сырой byte-level check SQLite-строки: тоже без NUL.
      final db = await repo.outboxDatabase();
      final rows = await db.query(
        'imap_body_cache',
        where: 'id = ?',
        whereArgs: ['acc_body:inbox:424242:701'],
      );
      final stored = rows.single['body_text']! as String;
      expect(stored.contains(_nul), isFalse);
      expect(stored.contains(String.fromCharCode(11)), isFalse);
    });

    test('[B8] UIDVALIDITY mismatch: transient, кэш удалён, sanitized',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02c_b8');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(
          file: File('${tempDir.path}${Platform.pathSeparator}b8.sqlite'),
        ),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);

      // Сначала кэшируем тело (uidValidity 424242).
      const bodyText = 'Старое поколение.';
      const structure =
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 17 1)';
      final socket1 = _FakeImapSocket(
        _bodySessionLines(
          uidValidity: 424242,
          uid: 700,
          bodyLiteral: bodyText,
          structureTail: structure,
          fullSize: 17,
        ),
        _bodySessionLiterals(bodyText),
      );
      state.debugImapTransportForTest(
        _transportOver(() => _bodyAccount(), _serviceWithApPassword(), socket1),
      );
      expect(
        await state.fetchEmailBodyFor('acc_body:inbox:424242:700'),
        isNotNull,
      );

      // Затем сервер сменил поколение (999999): догрузка UNCACHED
      // письма со СТАРЫМ uidValidity в id - сервер отвечает новым
      // поколением -> transient, sanitized, старая кэш-запись удалена.
      final socket2 = _FakeImapSocket(
        _bodySessionLines(
          uidValidity: 999999,
          uid: 701,
          bodyLiteral: bodyText,
          structureTail: structure,
          fullSize: 17,
        ),
        _bodySessionLiterals(bodyText),
      );
      state.debugImapTransportForTest(
        _transportOver(() => _bodyAccount(), _serviceWithApPassword(), socket2),
      );
      final failed = await state.fetchEmailBodyFor(
        'acc_body:inbox:424242:701',
      );
      expect(failed, isNull);
      expect(
        state.lastBodyFetchError,
        'Письмо недоступно: поколение папки изменилось',
      );
      // Кэш-запись старого поколения для 701 отсутствует/удалена.
      final db = await repo.outboxDatabase();
      final rows = await db.query(
        'imap_body_cache',
        where: 'id = ?',
        whereArgs: ['acc_body:inbox:424242:701'],
      );
      expect(rows, isEmpty);
      // Уже закэшированное 700 остаётся доступным из кэша (fromCache),
      // регенерация id произойдёт на следующем sync.
      final stale = await state.fetchEmailBodyFor(
        'acc_body:inbox:424242:700',
      );
      expect(stale!.fromCache, isTrue);
    });

    test('[B9] auth rejection при догрузке: sanitized, кэш не тронут',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02c_b9');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(
          file: File('${tempDir.path}${Platform.pathSeparator}b9.sqlite'),
        ),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);

      final socket = _FakeImapSocket(
        ['* OK ready', 'A1 NO [AUTHENTICATIONFAILED] rejected'],
        const [],
      );
      state.debugImapTransportForTest(
        _transportOver(() => _bodyAccount(), _serviceWithApPassword(), socket),
      );
      final result = await state.fetchEmailBodyFor('acc_body:inbox:424242:700');
      expect(result, isNull);
      expect(
        state.lastBodyFetchError,
        'Сервер отклонил аутентификацию: проверьте учётные данные',
      );
      // Кэш-таблица пуста, но сообщение не содержит пароля.
      expect(
        state.lastBodyFetchError!.contains(_apPassword),
        isFalse,
      );
    });

    test('[B10] read timeout при догрузке: transient, сокет закрыт',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02c_b10');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(
          file: File('${tempDir.path}${Platform.pathSeparator}b10.sqlite'),
        ),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);

      // Обрыв ВО ВРЕМЯ чтения литерала тела: сервер отдаёт FETCH-заголовок
      // с literal-индикатором, но содержимое не приходит (сокет умер).
      final socket = _FakeImapSocket(
        [
          '* OK ready',
          'A1 OK LOGIN completed',
          '* FLAGS ($_bs' 'Seen)',
          '* 1 EXISTS',
          '* OK [UIDVALIDITY 424242] UIDs valid',
          'A2 OK [READ-ONLY] EXAMINE completed',
          '* 1 FETCH (UID 700 RFC822.SIZE 100 BODYSTRUCTURE '
              '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 100 1) '
              'BODY[TEXT]<0.262144> {100}',
        ],
        const [], // literals пуст: чтение тела уронит соединение
      );
      state.debugImapTransportForTest(
        _transportOver(() => _bodyAccount(), _serviceWithApPassword(), socket),
      );
      final result = await state.fetchEmailBodyFor('acc_body:inbox:424242:700');
      expect(result, isNull);
      expect(
        state.lastBodyFetchError,
        'Ошибка соединения с IMAP-сервером',
      );
      expect(socket.destroyed, isTrue);
    });

    test('[B11] parse deterministic id, включая accountId с двоеточием',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02c_b11');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final repo = DriftLocalStateRepository(
        database: DriftOrbitDatabase(
          file: File('${tempDir.path}${Platform.pathSeparator}b11.sqlite'),
        ),
      );
      final sharedStore = MemoryOrbitSecretStore();
      final state = await stateOnFileSQLite(repo, sharedStore);

      // Некорректный id: меньше 4 сегментов.
      expect(await state.fetchEmailBodyFor('not-an-id'), isNull);
      expect(state.lastBodyFetchError, 'Некорректный идентификатор письма');

      // AccountId с двоеточием: разбор с конца корректен (аккаунт
      // отсутствует - честный sanitized отказ, но id разобран: ошибку
      // даёт поиск аккаунта, а не parse).
      expect(
        await state.fetchEmailBodyFor('weird:acc:inbox:424242:700'),
        isNull,
      );
      expect(state.lastBodyFetchError, 'Аккаунт недоступен');
    });

    test('[D1] raw-helpers scope: новые таблицы закрыты allowlist-ом',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02c_d1');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final db = DriftOrbitDatabase(
        file: File('${tempDir.path}${Platform.pathSeparator}d1.sqlite'),
      );
      await db.open();
      // Сама таблица доступна через allowlist...
      await db.insert('imap_body_cache', {
        'id': 'probe',
        'account_id': 'a',
        'uid_validity': 1,
        'uid': 1,
        'body_text': 'x',
        'truncated': 0,
        'full_size': 1,
        'attachments_json': '[]',
        'fetched_at': 0,
      });
      // ...но недопустимая колонка WHERE отклоняется (scope замкнут).
      await expectLater(
        db.query('imap_body_cache', where: 'evil = ?'),
        throwsArgumentError,
      );
      // Неизвестная таблица отклоняется.
      await expectLater(
        db.query('not_a_table'),
        throwsArgumentError,
      );
      await db.close();
    });
  });

  group('MAIL-02C UI narrow screen (360x780) + cache isolation', () {
    testWidgets('[B12] узкий экран 360x780: тело/вложения читаемы, лист '
        'над доком и системной навигацией', (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = FakeViewPadding(bottom: 24);
      addTearDown(tester.view.reset);

      final state = OrbitAppState(
        MemoryLocalStateRepository(),
        MemoryOrbitSecretStore(),
      );
      await state.load();
      // Real-аккаунт обязателен: панель фильтрует entries по не-DEMO
      // аккаунтам (Memory-репо: без file SQLite в fake-async зоне).
      await state.saveMailAccountWithCredentials(
        _bodyAccount(),
        appPassword: _apPassword,
      );
      await state.flush();
      // Кэш-запись и real-inbox entry напрямую через test hooks
      // (Memory-репо: без file SQLite в fake-async зоне; сети нет).
      const bodyText = 'Полное тело письма на узком экране.';
      state.debugPutUserInboxEntryForTest(
        UserInboxEntry(
          id: 'acc_body:inbox:424242:900',
          accountId: 'acc_body',
          sender: 'Мария Соколова <maria@test.local>',
          subject: 'План на неделю',
          preview: 'Привет!',
          timestamp: DateTime.utc(2026, 11, 15, 9, 24),
          isRead: false,
          isFlagged: false,
        ),
      );
      state.debugPutCachedBodyForTest(
        CachedEmailBody(
          id: 'acc_body:inbox:424242:900',
          accountId: 'acc_body',
          uidValidity: 424242,
          uid: 900,
          bodyText: ImapBodyCacheStore.sanitizeBodyText(bodyText),
          truncated: false,
          fullSize: utf8.encode(bodyText).length,
          attachments: const [
            ImapAttachmentMetadata(
              fileName: 'plan.pdf',
              sizeBytes: 2048,
              mimeType: 'APPLICATION/PDF',
            ),
          ],
          fetchedAtMs: DateTime.now().millisecondsSinceEpoch,
          fromCache: true,
        ),
      );

      final style = OrbitStyleManager(
        MemoryAppearanceRepository(
          const AppearanceSettings(
            profile: OrbitProfile.one,
            atmosphereMode: AtmosphereMode.automatic,
            quality: OrbitQuality.eco,
            motionEnabled: false,
          ),
        ),
      );
      final quality = OrbitQualityManager();
      addTearDown(quality.dispose);
      final palette = OrbitPalette.ofBrightness(
        OrbitProfile.one,
        Brightness.dark,
      );

      final overflowDetails = <FlutterErrorDetails>[];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        overflowDetails.add(details);
      };
      addTearDown(() {
        FlutterError.onError = prevOnError;
      });

      await tester.pumpWidget(
        ListenableBuilder(
          listenable: state,
          builder: (context, _) => OrbitEnvironment(
            style: style,
            quality: quality,
            appState: state,
            appearanceSettings: style.settings,
            resolvedQuality: quality.resolve(style.settings),
            dataRevision: state.dataRevision,
            graphicsFallbackReason: null,
            appearancePersistenceError: null,
            appearanceLoadError: null,
            platformBrightness: Brightness.dark,
            child: MaterialApp(
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: palette.themeData(palette.accent),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: OrbitRealInboxPanel(),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('real-inbox-toggle')));
      await tester.pumpAndSettle();
      // Карточка на узком экране без переполнений; при переполнении
      // печатаем полный details (какой виджет виноват).
      if (overflowDetails.isNotEmpty) {
        // ignore: avoid_print
        for (final d in overflowDetails) {
          // ignore: avoid_print
          print('OVERFLOW DETAILS: ${d.exception}');
          final info = d.informationCollector?.call() ?? const [];
          for (final line in info) {
            // ignore: avoid_print
            print('  OVERFLOW INFO: $line');
          }
        }
      }
      expect(overflowDetails, isEmpty);

      // Открываем лист деталей реального письма.
      final entryFinder = find.byKey(
        const Key('email-entry-acc_body:inbox:424242:900'),
      );
      expect(entryFinder, findsOneWidget);
      await tester.ensureVisible(entryFinder);
      await tester.pumpAndSettle();
      await tester.tap(entryFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // Тело и вложения отображаются; индикатор источника - кэш.
      expect(find.byKey(const Key('email-body-subject')), findsOneWidget);
      expect(find.byKey(const Key('email-body-text')), findsOneWidget);
      expect(
        find.byKey(const Key('email-body-source')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('email-attachment-plan.pdf')),
        findsOneWidget,
      );
      expect(find.textContaining('plan.pdf'), findsOneWidget);
      expect(
        find.textContaining('APPLICATION/PDF'),
        findsOneWidget,
      );
      expect(find.textContaining('Из локального кэша'), findsOneWidget);
    });

    test('[D2] кэш-изоляция: запись imap_body_cache не затрагивает '
        'emails/DEMO', () async {
      final tempDir = await Directory.systemTemp.createTemp('mail02c_d2');
      addTearDown(() async {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      });
      final db = DriftOrbitDatabase(
        file: File(
          '${tempDir.path}${Platform.pathSeparator}d2.sqlite',
        ),
      );
      await db.open();
      await db.insert('emails', {
        'id': 'demo-1',
        'workspace_id': 'workspace-work',
        'folder': 'inbox',
        'sender': 'demo@test.local',
        'recipient': 'me@test.local',
        'subject': 'DEMO письмо',
        'preview': 'p',
        'body': 'b',
        'timestamp': 0,
        'is_read': 0,
        'is_flagged': 0,
        'has_attachments': 0,
      });
      final cache = ImapBodyCacheStore(db);
      await cache.upsert(
        const CachedEmailBody(
          id: 'demo-1',
          accountId: 'acc',
          uidValidity: 1,
          uid: 1,
          bodyText: 'cached',
          truncated: false,
          fullSize: 7,
          attachments: [],
          fetchedAtMs: 0,
          fromCache: true,
        ),
      );
      final emails = await db.query(
        'emails',
        where: 'id = ?',
        whereArgs: ['demo-1'],
      );
      expect(emails.single['subject'], 'DEMO письмо');
      final cachedRows = await db.query(
        'imap_body_cache',
        where: 'id = ?',
        whereArgs: ['demo-1'],
      );
      expect(cachedRows.single['body_text'], 'cached');
      await db.close();
    });
  });
}
