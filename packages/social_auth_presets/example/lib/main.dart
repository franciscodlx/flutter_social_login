import 'dart:convert';
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:social_auth_presets/social_auth_presets.dart';

/// Real providers: `flutter run --dart-define=GITHUB_CLIENT_ID=…
/// --dart-define=BACKEND_URL=https://…` (also DISCORD_, SLACK_, STRAVA_; see
/// tools/presets_backend). A provider without a client id uses tools/mock_idp.
const clientIds = {
  'github': String.fromEnvironment('GITHUB_CLIENT_ID'),
  'discord': String.fromEnvironment('DISCORD_CLIENT_ID'),
  'slack': String.fromEnvironment('SLACK_CLIENT_ID'),
  'strava': String.fromEnvironment('STRAVA_CLIENT_ID'),
};
const backendDefine = String.fromEnvironment('BACKEND_URL');

/// Where the app listens (scheme set in android/app/build.gradle.kts).
const appCallback = 'presetsexample://callback';

// The Android emulator reaches the host machine through 10.0.2.2.
final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';

const providers = [
  (preset: githubPreset, label: 'GitHub', color: Color(0xFF24292F)),
  (preset: discordPreset, label: 'Discord', color: Color(0xFF5865F2)),
  (preset: slackPreset, label: 'Slack', color: Color(0xFF4A154B)),
  (preset: stravaPreset, label: 'Strava', color: Color(0xFFFC4C02)),
];

bool isReal(Preset preset) => clientIds[preset.id]! != '';

typedef Session = ({String provider, Map<String, dynamic> profile});

Future<Session> signInWith(Preset preset) async {
  final real = isReal(preset);
  final backendUrl = real ? backendDefine : 'http://$host:4400';
  final login = real
      ? createPresetLogin(preset)
      : createPresetLogin(
          preset,
          authorizationEndpoint: 'http://$host:4000/authorize',
        );
  final result = await login.signIn(
    SignInOptions(
      clientId: real ? clientIds[preset.id]! : 'confidential-app',
      // Registered in the provider; the backend forwards it to appCallback.
      redirectUri: '$backendUrl/auth/${preset.id}/callback',
      callbackUri: appCallback,
    ),
  );
  // The code is useless to the app: the backend swaps it for the profile.
  final response = await http.post(
    Uri.parse('$backendUrl/auth/${preset.id}/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'code': result.code,
      'codeVerifier': result.codeVerifier,
      'nonce': result.nonce,
      'redirectUri': result.redirectUri,
    }),
  );
  final body = jsonDecode(response.body) as Map<String, dynamic>;
  if (response.statusCode != 200) {
    throw Exception(
      'BACKEND ERROR: ${body['error_description'] ?? body['error']}',
    );
  }
  return (
    provider: body['provider'] as String,
    profile: body['profile'] as Map<String, dynamic>,
  );
}

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OAuth presets example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF24292F)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool busy = false;
  Session? session;
  String? failure;

  Future<void> run(Preset preset) async {
    setState(() {
      busy = true;
      session = null;
      failure = null;
    });
    try {
      final next = await signInWith(preset);
      setState(() => session = next);
    } on AuthException catch (error) {
      setState(() => failure = 'ERROR ${error.code.value}: ${error.message}');
    } on Object catch (error) {
      setState(() => failure = '$error');
    } finally {
      setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = session;
    return Scaffold(
      appBar: AppBar(title: const Text('OAuth presets example')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Providers without a client id use the local mock.'),
          const SizedBox(height: 8),
          for (final p in providers) ...[
            const SizedBox(height: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: p.color),
              onPressed: busy ? null : () => run(p.preset),
              child: Text(
                'Sign in with ${p.label}${isReal(p.preset) ? '' : ' (mock)'}',
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (busy) const LinearProgressIndicator(),
          if (failure != null)
            Text(failure!, style: const TextStyle(color: Color(0xFFB00020))),
          if (current != null) ...[
            Text('SIGNED IN (${current.provider})'),
            for (final key in ['id', 'username', 'name', 'email'])
              Text('$key: ${current.profile[key]}'),
          ],
        ],
      ),
    );
  }
}
