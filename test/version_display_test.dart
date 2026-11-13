import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_visual_lab/l10n/app_localizations_ru.dart';

import 'orbit_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Russian version label matches the current build', () {
    expect(AppLocalizationsRu().versionLabel, contains('0.5.30+36'));
    expect(AppLocalizationsRu().versionLabel, isNot(contains('0.5.0')));
  });

  testWidgets('About dialog shows the current build everywhere', (
    tester,
  ) async {
    await pumpOrbitApp(tester);
    await orbitGoToTab(tester, 4);
    await tester.ensureVisible(find.text('О Visual Lab'));
    await tester.tap(find.text('О Visual Lab'));
    await tester.pumpAndSettle();

    expect(find.text('0.5.30+36'), findsWidgets);
    expect(find.text('0.5.17+23'), findsNothing);
    expect(find.text('0.5.0'), findsNothing);
  });
}
