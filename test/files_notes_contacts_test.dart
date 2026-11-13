import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/file_record.dart';
import 'package:orbit_visual_lab/services/contacts/contacts_service.dart';
import 'package:orbit_visual_lab/services/files/orbit_file_manager.dart';
import 'package:orbit_visual_lab/services/notes/notes_service.dart';

void main() {
  group('FileRecord & OrbitFileManager (FNC-01)', () {
    late OrbitDataEngine engine;
    late OrbitFileManager fileManager;

    setUp(() async {
      final db = MemoryOrbitDatabase(autoSeed: true);
      engine = OrbitDataEngine(db);
      await engine.initialize();
      fileManager = OrbitFileManager(dataEngine: engine);
    });

    test('formats file size in human readable Russian format', () {
      final fileSmall = FileRecord(
        id: 'f1',
        workspaceId: 'workspace-work',
        fileName: 'readme.txt',
        extension: 'txt',
        sizeBytes: 512,
        mimeType: 'text/plain',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(fileSmall.formattedSize, '512 Б');

      final filePdf = FileRecord(
        id: 'f2',
        workspaceId: 'workspace-work',
        fileName: 'План_недели.pdf',
        extension: 'pdf',
        sizeBytes: 2516582, // ~2.4 MB
        mimeType: 'application/pdf',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(filePdf.formattedSize, '2,4 МБ');
      expect(filePdf.isPdf, isTrue);

      final fileXlsx = FileRecord(
        id: 'f3',
        workspaceId: 'workspace-work',
        fileName: 'График.xlsx',
        extension: 'xlsx',
        sizeBytes: 1153433, // ~1.1 MB
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(fileXlsx.formattedSize, '1,1 МБ');
      expect(fileXlsx.isSpreadsheet, isTrue);
    });

    test('attaches, retrieves and deletes files per entity and workspace', () async {
      final attached = await fileManager.attachFile(
        fileName: 'План_недели.pdf',
        sizeBytes: 2516582,
        mimeType: 'application/pdf',
        associatedEntityType: 'email',
        associatedEntityId: 'email-123',
      );

      expect(attached.id, isNotEmpty);
      expect(attached.fileName, 'План_недели.pdf');

      // Retrieve by entity
      final emailFiles = await fileManager.getFiles(
        associatedEntityId: 'email-123',
      );
      expect(emailFiles.length, 1);
      expect(emailFiles.first.fileName, 'План_недели.pdf');

      // Calculate total storage
      final totalBytes = await fileManager.getTotalStorageUsed();
      expect(totalBytes, 2516582);

      // Remove file
      await fileManager.removeFile(attached.id);
      final remaining = await fileManager.getFiles(associatedEntityId: 'email-123');
      expect(remaining, isEmpty);
    });

    test('rejects files larger than 50MB with ArgumentError', () async {
      expect(
        () => fileManager.attachFile(
          fileName: 'huge_archive.zip',
          sizeBytes: 60 * 1024 * 1024,
          mimeType: 'application/zip',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('NotesService (FNC-02)', () {
    late OrbitDataEngine engine;
    late NotesService notesService;

    setUp(() async {
      final db = MemoryOrbitDatabase(autoSeed: true);
      engine = OrbitDataEngine(db);
      await engine.initialize();
      notesService = NotesService(dataEngine: engine);
    });

    test('creates, retrieves, updates and deletes notes', () async {
      final note = await notesService.createNote(
        title: 'Архитектура синхронизации',
        content: 'Использовать bi-directional sync с offline queue',
        tags: ['Архитектура', 'Синхронизация'],
      );

      expect(note.title, 'Архитектура синхронизации');
      expect(note.tags, contains('Архитектура'));

      // Retrieve
      final list = await notesService.getNotes();
      expect(list.length, 1);

      // Update
      final updatedNote = note.copyWith(content: 'Обновлённый контент');
      await notesService.updateNote(updatedNote);

      final fetched = await notesService.getNoteById(note.id);
      expect(fetched?.content, 'Обновлённый контент');

      // Filter by tag
      final filtered = await notesService.getNotes(tagFilter: 'Архитектура');
      expect(filtered.length, 1);

      final emptyFilter = await notesService.getNotes(tagFilter: 'Несуществующий');
      expect(emptyFilter, isEmpty);

      // Search notes
      final searchRes = await notesService.searchNotes('синхронизации');
      expect(searchRes.length, 1);

      // Delete note
      await notesService.deleteNote(note.id);
      final afterDelete = await notesService.getNotes();
      expect(afterDelete, isEmpty);
    });

    test('extracts unique tag set across all notes', () async {
      await notesService.createNote(
        title: 'Заметка 1',
        content: 'Текст',
        tags: ['Проект', 'Дизайн'],
      );
      await notesService.createNote(
        title: 'Заметка 2',
        content: 'Текст',
        tags: ['Дизайн', 'Flutter'],
      );

      final tags = await notesService.getAllTags();
      expect(tags, containsAll(['Проект', 'Дизайн', 'Flutter']));
      expect(tags.length, 3);
    });
  });

  group('ContactsService (FNC-03)', () {
    late OrbitDataEngine engine;
    late ContactsService contactsService;

    setUp(() async {
      final db = MemoryOrbitDatabase(autoSeed: true);
      engine = OrbitDataEngine(db);
      await engine.initialize();
      contactsService = ContactsService(dataEngine: engine);
    });

    test('creates, retrieves, updates and deletes contacts', () async {
      final c1 = await contactsService.createContact(
        name: 'Мария Соколова',
        email: 'sokolova@example.com',
        phone: '+7 999 123-45-67',
        company: 'ORBIT Team',
        role: 'Lead Designer',
      );

      expect(c1.name, 'Мария Соколова');
      expect(c1.email, 'sokolova@example.com');

      final list = await contactsService.getContacts();
      expect(list.length, 1);

      // Search
      final searchRes = await contactsService.searchContacts('sokolova');
      expect(searchRes.length, 1);
      expect(searchRes.first.name, 'Мария Соколова');

      // Search by role
      final roleRes = await contactsService.searchContacts('Lead Designer');
      expect(roleRes.length, 1);

      // Delete
      await contactsService.deleteContact(c1.id);
      final empty = await contactsService.getContacts();
      expect(empty, isEmpty);
    });

    test('groups contacts alphabetically by first letter of name', () async {
      await contactsService.createContact(
        name: 'Алексей Романов',
        email: 'alexey@orbit.app',
      );
      await contactsService.createContact(
        name: 'Мария Соколова',
        email: 'mariya@orbit.app',
      );
      await contactsService.createContact(
        name: 'Артем Кузнецов',
        email: 'artem@orbit.app',
      );

      final grouped = await contactsService.getContactsGroupedByLetter();

      expect(grouped.containsKey('А'), isTrue);
      expect(grouped.containsKey('М'), isTrue);
      expect(grouped['А']!.length, 2);
      expect(grouped['М']!.length, 1);
    });
  });
}
