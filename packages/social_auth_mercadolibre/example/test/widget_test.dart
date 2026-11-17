import 'package:flutter_test/flutter_test.dart';
import 'package:social_auth_mercadolibre_example/main.dart';

void main() {
  testWidgets('shows the sign-in button and the provider', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('Sign in with Mercado Libre'), findsOneWidget);
    expect(find.text('Provider: local mock (no credentials)'), findsOneWidget);
  });
}
