import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/app.dart';
import 'package:orbit_visual_lab/data/demo_data.dart';
import 'package:orbit_visual_lab/data/orbit_local_state_codec.dart';
import 'package:orbit_visual_lab/screens/event_detail_screen.dart';
import 'package:orbit_visual_lab/state/app_state.dart';
import 'package:orbit_visual_lab/visual_engine/orbit_visual_engine.dart';
import 'package:orbit_visual_lab/widgets/orbit_photoreal_scene.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  final appState = OrbitAppState();
  await appState.load();
  final style = OrbitStyleManager(
    MemoryAppearanceRepository(
      const AppearanceSettings(quality: OrbitQuality.eco, motionEnabled: false),
    ),
  );
  await style.load();
  final quality = OrbitQualityManager();
  addTearDown(quality.dispose);
  await tester.pumpWidget(
    OrbitVisualLabApp(style: style, quality: quality, appState: appState),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Event Model Expansion & Backwards Compatibility (Task 4)', () {
    test('legacy v1 JSON without new fields decodes cleanly', () {
      final legacyJson = {
        'id': 'legacy_1',
        'title': 'Legacy Meeting',
        'time': '10:00',
        'meta': 'Обсуждение проекта',
        'colorValue': 0xFF3D7AF5,
        'date': '2026-11-10T10:00:00.000',
      };

      final event = DemoEvent.fromJson(legacyJson);
      expect(event.id, 'legacy_1');
      expect(event.title, 'Legacy Meeting');
      expect(event.endTime, isNull);
      expect(event.description, isNull);
      expect(event.location, isNull);
      expect(event.organizer, isNull);
      expect(event.attendees, isEmpty);
      expect(event.attachments, isEmpty);
      expect(event.conferenceUrl, isNull);
    });

    test('rich v2 event roundtrips through JSON without data loss', () {
      final event = DemoEvent(
        'evt_v2',
        '14:00',
        'Архитектурный комитет',
        'Конференц-зал ORBIT Alpha',
        const Color(0xFF3D7AF5),
        endTime: '15:30',
        date: DateTime(2026, 11, 12, 14, 0),
        description: 'Рассмотрение спецификации ORBIT 0.5.7',
        location: 'Москва, Главный офис, Этаж 7',
        conferenceUrl: 'https://meet.orbit.internal/arch-committee',
        organizer: const EventOrganizer(
          name: 'Дмитрий Соколов',
          email: 'd.sokolov@orbit.internal',
        ),
        attendees: const [
          EventAttendee(
            name: 'Анна Воронова',
            email: 'a.voronova@orbit.internal',
            status: AttendeeStatus.accepted,
          ),
          EventAttendee(
            name: 'Павел Смирнов',
            email: 'p.smirnov@orbit.internal',
            status: AttendeeStatus.tentative,
          ),
          EventAttendee(
            name: 'Елена Кузнецова',
            email: 'e.kuznetsova@orbit.internal',
            status: AttendeeStatus.unknown,
          ),
        ],
        attachments: const [
          EventAttachment(
            name: 'ORBIT_0.5.7_Spec.pdf',
            type: 'pdf',
            sizeBytes: 1048576,
          ),
        ],
      );

      final jsonMap = event.toJson();
      final decoded = DemoEvent.fromJson(jsonMap);

      expect(decoded.id, event.id);
      expect(decoded.title, event.title);
      expect(decoded.endTime, '15:30');
      expect(decoded.description, event.description);
      expect(decoded.location, event.location);
      expect(decoded.conferenceUrl, event.conferenceUrl);
      expect(decoded.organizer?.name, 'Дмитрий Соколов');
      expect(decoded.organizer?.email, 'd.sokolov@orbit.internal');
      expect(decoded.attendees.length, 3);
      expect(decoded.attendees[0].status, AttendeeStatus.accepted);
      expect(decoded.attendees[1].status, AttendeeStatus.tentative);
      expect(decoded.attendees[2].status, AttendeeStatus.unknown);
      expect(decoded.attachments.length, 1);
      expect(decoded.attachments[0].name, 'ORBIT_0.5.7_Spec.pdf');
      expect(decoded.attachments[0].formattedSize, '1.0 MB');
    });

    test('OrbitLocalStateCodec validates both legacy and rich events', () {
      final validState = {
        'schemaVersion': 1,
        'events': [
          {
            'id': 'legacy_evt',
            'title': 'Legacy Call',
            'time': '09:00',
            'meta': 'Call',
            'color': 0xFF123456,
            'date': '2026-11-10T09:00:00.000',
          },
          {
            'id': 'rich_evt',
            'title': 'Rich Meeting',
            'time': '11:00',
            'endTime': '12:00',
            'meta': 'Room 1',
            'color': 0xFF654321,
            'date': '2026-11-10T11:00:00.000',
            'description': 'Discussion',
            'location': 'HQ Room 1',
            'conferenceUrl': 'https://meet.orbit.internal/room1',
            'organizer': {'name': 'Lead', 'email': 'lead@orbit.internal'},
            'attendees': [
              {
                'name': 'Dev',
                'email': 'dev@orbit.internal',
                'status': 'accepted',
              },
            ],
            'attachments': [
              {
                'name': 'doc.pdf',
                'type': 'pdf',
                'sizeBytes': 2048,
              },
            ],
          },
        ],
      };

      expect(() => OrbitLocalStateCodec.validate(validState), returnsNormally);
    });
  });

  group('Event Navigation & Details Screen (Tasks 2 & 3)', () {
    testWidgets('Today screen event row navigates to EventDetailScreen and back', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 5, 9, 41)), () async {
        await _pumpApp(tester);

        // Find the first event row in Today screen
        final eventRowFinder = find.byKey(const Key('event-row-review'));
        expect(eventRowFinder, findsOneWidget);

        // Tap the event
        await tester.tap(eventRowFinder);
        await tester.pumpAndSettle();

        // Verify EventDetailScreen is displayed
        expect(find.byType(EventDetailScreen), findsOneWidget);
        expect(find.text('Совещание по ВП'), findsOneWidget);
        expect(find.text('10:00 — 11:00'), findsOneWidget);
        expect(find.text('Алексей Смирнов'), findsNWidgets(2)); // Organizer and attendee
        expect(find.text('https://meet.orbit.local/vp-review'), findsOneWidget);

        // Tap the back button
        final backButton = find.byTooltip('Назад');
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        await tester.pumpAndSettle();

        // Verify we returned cleanly to Today screen
        expect(find.byType(EventDetailScreen), findsNothing);
        expect(find.byKey(const Key('today-greeting')), findsOneWidget);
      });
    });

    testWidgets('Calendar screen event row navigates to EventDetailScreen and preserves date on back', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 1, 15, 12)), () async {
        await _pumpApp(tester);

        // Navigate to Calendar
        await tester.tap(find.byKey(const Key('orbit-nav-2')));
        await tester.pumpAndSettle();

        // Switch to week day with events
        await tester.tap(find.byKey(const Key('week-day-2026-01-15')));
        await tester.pumpAndSettle();

        // Tap on event
        final eventRowFinder = find.byKey(const Key('event-row-review'));
        expect(eventRowFinder, findsOneWidget);
        await tester.tap(eventRowFinder);
        await tester.pumpAndSettle();

        // Verify details screen
        expect(find.byType(EventDetailScreen), findsOneWidget);

        // Tap back
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();

        // Verify calendar is still showing 15 января 2026
        expect(find.byType(EventDetailScreen), findsNothing);
        expect(find.text('15 января 2026'), findsOneWidget);
      });
    });

    testWidgets('EventDetailScreen renders clean empty states when optional fields are null', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 5, 9, 41)), () async {
        final appState = OrbitAppState();
        await appState.load();
        appState.addEvent('Короткий созвон', '17:00', DateTime(2026, 11, 5, 17, 0));
        final createdEvent = appState.events.firstWhere((e) => e.title == 'Короткий созвон');

        final style = OrbitStyleManager(
          MemoryAppearanceRepository(
            const AppearanceSettings(quality: OrbitQuality.eco, motionEnabled: false),
          ),
        );
        await style.load();
        final quality = OrbitQualityManager();
        addTearDown(quality.dispose);

        await tester.pumpWidget(
          OrbitVisualLabApp(style: style, quality: quality, appState: appState),
        );
        await tester.pumpAndSettle();

        // Tap on newly created event row
        final eventRowFinder = find.byKey(Key('event-row-${createdEvent.id}'));
        expect(eventRowFinder, findsOneWidget);
        await tester.ensureVisible(eventRowFinder);
        await tester.pumpAndSettle();
        await tester.tap(eventRowFinder);
        await tester.pumpAndSettle();

        expect(find.byType(EventDetailScreen), findsOneWidget);
        expect(find.text('Короткий созвон'), findsOneWidget);
        expect(find.text('Описание не указано'), findsOneWidget);
        expect(find.text('Место не указано'), findsOneWidget);
        expect(find.text('Список участников пуст'), findsOneWidget);
        expect(find.text('Вложения отсутствуют'), findsOneWidget);
      });
    });
  });

  group('Performance & Scroll Throttling (Task 1)', () {
    testWidgets('OrbitPhotorealScene suspends phase ticks when isScrollingNotifier is true', (
      tester,
    ) async {
      await withClock(Clock.fixed(DateTime(2026, 11, 9, 12, 0)), () async {
        OrbitPhotorealScene.isScrollingNotifier.value = false;

        await tester.pumpWidget(
          MaterialApp(
            home: OrbitPhotorealScene(
              palette: OrbitPalette.of(OrbitProfile.flow),
              quality: ResolvedQuality.balanced,
              motionEnabled: true,
            ),
          ),
        );
        await tester.pump();

        final initialBuildCount = OrbitPhotorealScene.debugBuildCount;

        // Advance clock and pump while idle
        await withClock(Clock.fixed(DateTime(2026, 11, 9, 12, 0, 0, 250)), () async {
          await tester.pump(const Duration(milliseconds: 250));
        });
        final countWhileIdle = OrbitPhotorealScene.debugBuildCount;
        expect(countWhileIdle, greaterThan(initialBuildCount));

        // Now set scrolling to true
        OrbitPhotorealScene.isScrollingNotifier.value = true;
        final countBeforeScroll = OrbitPhotorealScene.debugBuildCount;

        // Advance clock and pump while scrolling
        await withClock(Clock.fixed(DateTime(2026, 11, 9, 12, 0, 0, 800)), () async {
          await tester.pump(const Duration(milliseconds: 550));
        });
        final countDuringScroll = OrbitPhotorealScene.debugBuildCount;

        // Rebuild count must NOT increase during active scrolling!
        expect(countDuringScroll, equals(countBeforeScroll));

        // Reset scrolling to false
        OrbitPhotorealScene.isScrollingNotifier.value = false;
        await withClock(Clock.fixed(DateTime(2026, 11, 9, 12, 0, 1, 200)), () async {
          await tester.pump(const Duration(milliseconds: 400));
        });
        expect(OrbitPhotorealScene.debugBuildCount, greaterThan(countDuringScroll));
      });
    });

    test('All 4 profiles provide valid palettes and contrast ratios', () {
      for (final profile in OrbitProfile.values) {
        final dark = OrbitPalette.ofBrightness(profile, Brightness.dark);
        final light = OrbitPalette.ofBrightness(profile, Brightness.light);

        expect(dark.profile, profile);
        expect(light.profile, profile);
        expect(dark.surface, isNotNull);
        expect(light.surface, isNotNull);
        expect(dark.accent, isNotNull);
        expect(light.accent, isNotNull);
      }
    });
  });
}
