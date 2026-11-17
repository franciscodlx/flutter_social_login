import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:social_auth_twitch/social_auth_twitch.dart';

/// Real Twitch: `flutter run --dart-define=TWITCH_CLIENT_ID=…
/// --dart-define=BACKEND_URL=https://…` (see tools/twitch_backend). Without
/// them the app runs against tools/mock_idp.
const clientIdDefine = String.fromEnvironment('TWITCH_CLIENT_ID');
const backendDefine = String.fromEnvironment('BACKEND_URL');
const useMock = clientIdDefine == '';

// The Android emulator reaches the host machine through 10.0.2.2.
final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
final String backendUrl = useMock ? 'http://$host:4300' : backendDefine;

final login = useMock
    ? createTwitchLogin(authorizationEndpoint: 'http://$host:4000/authorize')
    : twitchLogin;

final options = SignInOptions(
  clientId: useMock ? 'confidential-app' : clientIdDefine,
  // Registered in the Twitch application; the backend bounces it to
  // callbackUri.
  redirectUri: '$backendUrl/auth/twitch/callback',
  // Scheme set in android/app/build.gradle.kts.
  callbackUri: 'twitchexample://callback',
);

typedef Session = ({TwitchProfile profile, bool verified});

/// Code and nonce go to the backend, which holds the secret and checks that
/// the id_token carries this nonce.
Future<Session> exchangeOnBackend(SignInResult<TwitchProfile> result) async {
  final response = await http.post(
    Uri.parse('$backendUrl/auth/twitch/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'code': result.code,
      'nonce': result.nonce,
      'redirectUri': result.redirectUri,
    }),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200) {
    throw Exception(body['error_description'] ?? body['error']);
  }
  final profile = body['profile'] as Map<String, dynamic>;
  return (
    profile: TwitchProfile(
      id: '${profile['id']}',
      username: profile['username'] as String?,
      picture: profile['picture'] as String?,
      email: profile['email'] as String?,
      emailVerified: profile['emailVerified'] as bool?,
    ),
    verified: body['idTokenVerified'] == true,
  );
}

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Twitch login example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF9146FF)),
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
    appBar: AppBar(title: const Text('Twitch login example')),
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
                  : 'Provider: Twitch',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : signIn,
              child: const Text('Sign in with Twitch'),
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
              Text('username: ${current.profile.username}'),
              Text('email: ${current.profile.email}'),
              Text('email verified: ${current.profile.emailVerified}'),
              Text(
                'id_token verified (signature + nonce): ${current.verified}',
              ),
            ],
          ],
        );
      },
    ),
  );
}
