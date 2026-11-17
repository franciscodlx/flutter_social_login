import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_entra_native_example/main.dart';

void main() {
  testWidgets('shows the three flows against the mock', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Provider: local mock (no tenant)'), findsOneWidget);
    for (final label in ['Sign in', 'Sign up', 'Reset password']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('ada@example.com'), findsOneWidget);
  });
}
