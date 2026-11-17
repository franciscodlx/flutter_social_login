import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_presets_example/main.dart';

void main() {
  testWidgets('shows one button per preset, all against the mock', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());
    for (final label in ['GitHub', 'Discord', 'Slack', 'Strava']) {
      expect(find.text('Sign in with $label (mock)'), findsOneWidget);
    }
  });
}
