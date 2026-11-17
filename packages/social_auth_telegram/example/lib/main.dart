import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:social_auth_telegram/social_auth_telegram.dart';

/// Real Telegram: `flutter run --dart-define=TELEGRAM_CLIENT_ID=…
/// --dart-define=BACKEND_URL=https://…` (see tools/telegram_backend). Without
/// them the app runs against tools/mock_idp.
const clientIdDefine = String.fromEnvironment('TELEGRAM_CLIENT_ID');
const backendDefine = String.fromEnvironment('BACKEND_URL');
const useMock = clientIdDefine == '';

// The Android emulator reaches the host machine through 10.0.2.2.
final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
final String backendUrl = useMock ? 'http://$host:4500' : backendDefine;

final login = useMock
    ? createTelegramLogin(authorizationEndpoint: 'http://$host:4000/authorize')
    : telegramLogin;

final options = SignInOptions(
  clientId: useMock ? 'confidential-app' : clientIdDefine,
  // Added to the Allowed URLs in BotFather; the backend bounces it to
  // callbackUri.
  redirectUri: '$backendUrl/auth/telegram/callback',
  // Scheme set in android/app/build.gradle.kts.
  callbackUri: 'telegramexample://callback',
  // `phone` asks the user to share their phone number.
  scopes: [...telegramDefaultScopes, telegramPhoneScope],
);

typedef Session = ({TelegramProfile profile, bool verified});

/// Code and PKCE verifier go to the backend, which holds the secret and
/// verifies the id_token.
Future<Session> exchangeOnBackend(SignInResult<TelegramProfile> result) async {
  final response = await http.post(
    Uri.parse('$backendUrl/auth/telegram/exchange'),
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
    profile: TelegramProfile(
      id: '${profile['id']}',
      telegramId: profile['telegramId'] as String?,
      name: profile['name'] as String?,
      username: profile['username'] as String?,
      picture: profile['picture'] as String?,
      phoneNumber: profile['phoneNumber'] as String?,
    ),
    verified: body['idTokenVerified'] == true,
  );
}

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Telegram login example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF229ED9)),
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
    appBar: AppBar(title: const Text('Telegram login example')),
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
                  : 'Provider: Telegram',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : signIn,
              child: const Text('Sign in with Telegram'),
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
                'BACKEND ERROR: $failure',
                style: const TextStyle(color: Color(0xFFB00020)),
              ),
            if (current != null) ...[
              const Text('SIGNED IN'),
              Text('id: ${current.profile.id}'),
              Text('username: ${current.profile.username}'),
              Text('phone: ${current.profile.phoneNumber}'),
              Text('id_token verified by backend: ${current.verified}'),
            ],
          ],
        );
      },
    ),
  );
}
