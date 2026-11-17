import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_x_example/main.dart';

void main() {
  testWidgets('shows the sign-in buttons and the provider', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Sign in (code only)'), findsOneWidget);
    expect(find.text('Sign in + profile'), findsOneWidget);
    expect(find.text('Provider: local mock (no credentials)'), findsOneWidget);
  });
}
