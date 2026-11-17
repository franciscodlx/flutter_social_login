import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_core_example/main.dart';

void main() {
  testWidgets('shows the sign-in buttons', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Sign in (code only)'), findsOneWidget);
    expect(find.text('Sign in + exchange'), findsOneWidget);
  });
}
