import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:social_auth_tiktok/social_auth_tiktok.dart';

/// Real TikTok: `flutter run --dart-define=TIKTOK_CLIENT_KEY=…
/// --dart-define=BACKEND_URL=https://…` (see tools/tiktok_backend). Without
/// them the app runs against tools/mock_idp.
const clientKeyDefine = String.fromEnvironment('TIKTOK_CLIENT_KEY');
const backendDefine = String.fromEnvironment('BACKEND_URL');
const useMock = clientKeyDefine == '';

// The Android emulator reaches the host machine through 10.0.2.2.
final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
final String backendUrl = useMock ? 'http://$host:4600' : backendDefine;

final login = useMock
    ? createTikTokLogin(authorizationEndpoint: 'http://$host:4000/authorize')
    : tikTokLogin;

final options = SignInOptions(
  // TikTok's "client key"; sent as `client_key`.
  clientId: useMock ? 'confidential-app' : clientKeyDefine,
  // Registered in the app's Login Kit settings; the backend bounces it to
  // callbackUri.
  redirectUri: '$backendUrl/auth/tiktok/callback',
  // Scheme set in android/app/build.gradle.kts.
  callbackUri: 'tiktokexample://callback',
);

typedef Session = ({TikTokProfile profile, List<String> scopes});

/// The code is useless to the app: the backend swaps it for the profile.
Future<TikTokProfile> exchangeOnBackend(
  SignInResult<TikTokProfile> result,
) async {
  final response = await http.post(
    Uri.parse('$backendUrl/auth/tiktok/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'code': result.code, 'redirectUri': result.redirectUri}),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200) {
    throw Exception(body['error_description'] ?? body['error']);
  }
  final profile = body['profile'] as Map<String, dynamic>;
  return TikTokProfile(
    id: '${profile['id']}',
    unionId: profile['unionId'] as String?,
    displayName: profile['displayName'] as String?,
    picture: profile['picture'] as String?,
  );
}

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TikTok login example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF000000)),
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
      final profile = await exchangeOnBackend(result);
      setState(
        () => session = (profile: profile, scopes: grantedTikTokScopes(result)),
      );
    } on Object catch (error) {
      setState(() => failure = '$error');
    } finally {
      setState(() => exchanging = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('TikTok login example')),
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
                  : 'Provider: TikTok',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : signIn,
              child: const Text('Sign in with TikTok'),
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
              Text('name: ${current.profile.displayName}'),
              Text('granted scopes: ${current.scopes.join(', ')}'),
            ],
          ],
        );
      },
    ),
  );
}
