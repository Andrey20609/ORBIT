import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/data/database/memory_orbit_database.dart';
import 'package:orbit_visual_lab/data/database/orbit_data_engine.dart';
import 'package:orbit_visual_lab/data/models/task_record.dart';
import 'package:orbit_visual_lab/services/brain/brain_context_aggregator.dart';
import 'package:orbit_visual_lab/services/brain/privacy_guardrails.dart';

void main() {
  group('[BRN-01] PrivacyGuardrails', () {
    test('masks credit card numbers with last 4 digits visible', () {
      const input = 'Оплата картой 4276 3800 1234 5678 в магазине';
      final sanitized = PrivacyGuardrails.sanitizeText(input);
      expect(sanitized, 'Оплата картой •••• •••• •••• 5678 в магазине');
    });

    test('masks API keys and JWT tokens', () {
      const apiKey = 'sk-proj1234567890abcdef1234567890';
      const input = 'Использовать ключ $apiKey для доступа к серверу';
      final sanitized = PrivacyGuardrails.sanitizeText(input);
      expect(sanitized, 'Использовать ключ [API_KEY_MASKED] для доступа к серверу');

      const jwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozGzN_mock_signature_hash';
      final jwtInput = 'Bearer $jwt в заголовке';
      final jwtSanitized = PrivacyGuardrails.sanitizeText(jwtInput);
      expect(jwtSanitized, 'Bearer [JWT_MASKED] в заголовке');
    });

    test('masks passwords inside URIs', () {
      const uriInput = 'Подключение к postgres://admin:SuperSecretPass123@db.company.internal:5432/orbit';
      final sanitized = PrivacyGuardrails.sanitizeText(uriInput);
      expect(
        sanitized,
        'Подключение к postgres://admin:[PASSWORD_MASKED]@db.company.internal:5432/orbit',
      );
    });

    test('BrainContextAggregator sanitizes sensitive text in tasks and emails', () async {
      final db = MemoryOrbitDatabase();
      final dataEngine = OrbitDataEngine(db);
      await dataEngine.initialize();

      await dataEngine.saveTask(
        TaskRecord(
          id: 'task-secret-1',
          workspaceId: 'workspace-work',
          title: 'Оплатить счёт картой 4276 1111 2222 9999',
          createdAt: DateTime.now().toUtc(),
        ),
      );

      final aggregator = BrainContextAggregator(dataEngine);
      final contextMap = await aggregator.buildAggregatedContext();

      final tasks = contextMap['tasks']! as List;
      expect(tasks.length, 1);
      final taskTitle = (tasks.first as Map)['title'] as String;
      expect(taskTitle, contains('•••• •••• •••• 9999'));
      expect(taskTitle, isNot(contains('4276 1111 2222 9999')));
    });
  });
}
