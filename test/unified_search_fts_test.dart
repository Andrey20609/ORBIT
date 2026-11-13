import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/contact_record.dart';
import 'package:orbit_visual_lab/data/models/email_record.dart';
import 'package:orbit_visual_lab/data/models/event_record.dart';
import 'package:orbit_visual_lab/data/models/note_record.dart';
import 'package:orbit_visual_lab/data/models/task_record.dart';
import 'package:orbit_visual_lab/services/search/search_models.dart';
import 'package:orbit_visual_lab/services/search/unified_search_service.dart';

void main() {
  late MemoryOrbitDatabase db;
  late OrbitDataEngine dataEngine;
  late UnifiedSearchService searchService;

  setUp(() async {
    db = MemoryOrbitDatabase();
    dataEngine = OrbitDataEngine(db);
    await dataEngine.initialize();

    searchService = UnifiedSearchService(dataEngine);

    // Seed test data across all domains
    await dataEngine.saveEmail(
      EmailRecord(
        id: 'email-search-1',
        workspaceId: 'workspace-work',
        sender: 'Booking.com',
        recipient: 'alexey@orbit.app',
        subject: 'Подтверждение бронирования Тында',
        preview: 'Гостиница в Тынде оплачена',
        body: 'Номер забронирован.',
        timestamp: DateTime.utc(2026, 11, 10, 12, 0),
      ),
    );

    await dataEngine.saveTask(
      TaskRecord(
        id: 'task-search-1',
        workspaceId: 'workspace-work',
        title: 'Командировка в Тынду',
        project: 'БАМ',
        createdAt: DateTime.utc(2026, 11, 10, 13, 0),
      ),
    );

    await dataEngine.saveEvent(
      EventRecord(
        id: 'event-search-1',
        workspaceId: 'workspace-work',
        title: 'Аудит СЛД Тында',
        startTime: DateTime.utc(2026, 11, 12, 13, 30),
        endTime: DateTime.utc(2026, 11, 12, 15, 30),
        location: 'СЛД Тында',
      ),
    );

    await dataEngine.saveNote(
      NoteRecord(
        id: 'note-search-1',
        workspaceId: 'workspace-work',
        title: 'Памятка Тында',
        content: 'Взять тёплые вещи и рабочие чертежи.',
        tags: ['поездка', 'Тында'],
        updatedAt: DateTime.utc(2026, 11, 10, 15, 0),
      ),
    );

    await dataEngine.saveContact(
      const ContactRecord(
        id: 'contact-search-1',
        workspaceId: 'workspace-work',
        name: 'Начальник СЛД Тында',
        email: 'sld.tynda@rzd.ru',
        company: 'СЛД Тында',
      ),
    );
  });

  group('[FNC-04] Unified Search FTS Engine', () {
    test('searches across all 5 domains by query "Тында"', () async {
      final results = await searchService.search('Тында');

      expect(results.length, 5);
      final categories = results.map((r) => r.category).toSet();
      expect(categories, containsAll([
        SearchCategory.email,
        SearchCategory.task,
        SearchCategory.event,
        SearchCategory.note,
        SearchCategory.contact,
      ]));
    });

    test('filters search results strictly by specific category', () async {
      final taskResults = await searchService.search(
        'Тында',
        category: SearchCategory.task,
      );

      expect(taskResults.length, 1);
      expect(taskResults.first.category, SearchCategory.task);
      expect(taskResults.first.title, 'Командировка в Тынду');
    });

    test('returns empty results on non-matching query', () async {
      final results = await searchService.search('НесуществующийЗапросXYZ');
      expect(results, isEmpty);
    });
  });
}
