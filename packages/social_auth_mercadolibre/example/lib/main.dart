import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:social_auth_mercadolibre/social_auth_mercadolibre.dart';

/// Real Mercado Libre: `flutter run --dart-define=MERCADOLIBRE_CLIENT_ID=…
/// --dart-define=BACKEND_URL=https://… --dart-define=COUNTRY=MX` (see
/// tools/mercadolibre_backend). Without them the app runs against
/// tools/mock_idp.
const clientIdDefine = String.fromEnvironment('MERCADOLIBRE_CLIENT_ID');
const backendDefine = String.fromEnvironment('BACKEND_URL');
const countryDefine = String.fromEnvironment('COUNTRY', defaultValue: 'MX');
const useMock = clientIdDefine == '';

// The Android emulator reaches the host machine through 10.0.2.2.
final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
final String backendUrl = useMock ? 'http://$host:4200' : backendDefine;
final country = MercadoLibreCountry.fromCode(countryDefine);

final login = createMercadoLibreLogin(
  country: country,
  authorizationEndpoint: useMock ? 'http://$host:4000/authorize' : null,
);

final options = SignInOptions(
  clientId: useMock ? 'confidential-app' : clientIdDefine,
  // Registered in the Mercado Libre application; the backend bounces it to
  // callbackUri.
  redirectUri: '$backendUrl/auth/mercadolibre/callback',
  // Scheme set in android/app/build.gradle.kts.
  callbackUri: 'meliexample://callback',
);

typedef Session = ({MercadoLibreProfile profile, bool hasRefreshToken});

/// Code and PKCE verifier go to the backend, which holds the secret.
Future<Session> exchangeOnBackend(
  SignInResult<MercadoLibreProfile> result,
) async {
  final response = await http.post(
    Uri.parse('$backendUrl/auth/mercadolibre/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'code': result.code,
      'codeVerifier': result.codeVerifier,
      'redirectUri': result.redirectUri,
    }),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200) {
    throw Exception(body['error_description'] ?? body['error']);
  }
  final profile = body['profile'] as Map<String, dynamic>;
  return (
    profile: MercadoLibreProfile(
      id: '${profile['id']}',
      nickname: profile['nickname'] as String?,
      email: profile['email'] as String?,
      siteId: profile['siteId'] as String?,
    ),
    hasRefreshToken: body['hasRefreshToken'] == true,
  );
}

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mercado Libre login example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF2D3277)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final controller = ProviderLoginController(login, options);
  bool exchanging = false;
  Session? session;
  String? failure;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    setState(() {
      session = null;
      failure = null;
    });
    final result = await controller.signIn();
    if (result == null) {
      return;
    }
    setState(() => exchanging = true);
    try {
      final next = await exchangeOnBackend(result);
      setState(() => session = next);
    } on Object catch (error) {
      setState(() => failure = '$error');
    } finally {
      setState(() => exchanging = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mercado Libre login example')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final busy = controller.loading || exchanging;
        final error = controller.error;
        final current = session;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              useMock
                  ? 'Provider: local mock (no credentials)'
                  : 'Provider: Mercado Libre (${country.code})',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : signIn,
              child: const Text('Sign in with Mercado Libre'),
            ),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            if (error != null)
              Text(
                'ERROR ${error.code.value}: ${error.message}',
                style: const TextStyle(color: Color(0xFFB00020)),
              ),
            if (failure != null)
              Text(
                'EXCHANGE FAILED: $failure',
                style: const TextStyle(color: Color(0xFFB00020)),
              ),
            if (current != null) ...[
              const Text('SIGNED IN'),
              Text('id: ${current.profile.id}'),
              Text('nickname: ${current.profile.nickname}'),
              Text('email: ${current.profile.email}'),
              Text('site: ${current.profile.siteId}'),
              Text('refresh token on backend: ${current.hasRefreshToken}'),
            ],
          ],
        );
      },
    ),
  );
}
