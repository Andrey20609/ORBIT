import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/demo_data.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_repository.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_mail_folders_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ORBIT Mail Folders System (DoD Tests)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('1. Удаление письма переносит его в Корзину, откуда его можно восстановить или очистить', () async {
      final state = OrbitAppState();
      await state.load();

      const sampleEmailId = 'mail_1';
      expect(state.isEmailInInbox(sampleEmailId), isTrue);

      // Удаляем письмо -> должно попасть в Корзину
      state.deleteEmail(sampleEmailId);
      expect(state.isEmailInInbox(sampleEmailId), isFalse);
      expect(state.trashEmails.contains(sampleEmailId), isTrue);
      expect(state.folderForEmail(sampleEmailId), OrbitMailFolder.trash);

      // Восстанавливаем из Корзины -> возвращается во Входящие
      state.restoreFromTrash(sampleEmailId);
      expect(state.trashEmails.contains(sampleEmailId), isFalse);
      expect(state.isEmailInInbox(sampleEmailId), isTrue);

      // Снова удаляем и очищаем корзину навсегда
      state.deleteEmail(sampleEmailId);
      expect(state.trashEmails, isNotEmpty);
      state.emptyTrash();
      expect(state.trashEmails, isEmpty);
      expect(state.isEmailInInbox(sampleEmailId), isFalse);
    });

    test('2. Отправка письма добавляет запись в Отправленные и очищает черновик', () async {
      final state = OrbitAppState();
      await state.load();

      state.updateDraft(
        to: 'alex@orbit.io',
        subject: 'Архитектура папок',
        body: 'Готово к релизу',
      );

      final sent = state.sendEmail(state.draft);
      expect(state.sentEmails, hasLength(1));
      expect(state.sentEmails.first.id, sent.id);
      expect(state.sentEmails.first.recipient, 'alex@orbit.io');
      expect(state.sentEmails.first.subject, 'Архитектура папок');
      expect(state.draft.subject, isEmpty);
    });

    test('3. Перемещение между Архивом, Спамом и персистентность в SharedPreferences', () async {
      final repo = SharedPreferencesLocalStateRepository();
      final state = OrbitAppState(repo);
      await state.load();

      state.selectMailFolder(OrbitMailFolder.archive);
      state.moveToFolder('mail_2', OrbitMailFolder.archive);
      state.moveToFolder('mail_3', OrbitMailFolder.spam);
      await state.flush();

      final restoredState = OrbitAppState(repo);
      await restoredState.load();

      expect(restoredState.currentMailFolder, OrbitMailFolder.archive);
      expect(restoredState.archiveEmails.contains('mail_2'), isTrue);
      expect(restoredState.spamEmails.contains('mail_3'), isTrue);
    });

    testWidgets('4. Шторка OrbitMailFoldersSheet открывается и переключает активную папку', (tester) async {
      OrbitMailFolder selected = OrbitMailFolder.inbox;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('open-folders-btn'),
                onPressed: () {
                  showOrbitMailFoldersSheet(
                    context,
                    palette: OrbitPalette.fromProfile(OrbitProfile.one, isLight: false),
                    profile: OrbitProfile.one,
                    currentFolder: selected,
                    badgeBuilder: (folder) => folder == OrbitMailFolder.inbox ? 3 : 0,
                    onFolderSelected: (folder) => selected = folder,
                  );
                },
                child: const Text('Папки'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open-folders-btn')));
      await tester.pumpAndSettle();

      expect(find.text('Папки почты'), findsOneWidget);
      expect(find.text('Входящие'), findsOneWidget);
      expect(find.text('Отправленные'), findsOneWidget);
      expect(find.text('Корзина'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mail-folder-item-trash')));
      await tester.pumpAndSettle();

      expect(selected, OrbitMailFolder.trash);
    });
  });
}
