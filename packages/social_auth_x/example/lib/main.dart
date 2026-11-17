import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:social_auth_x/social_auth_x.dart';

/// Real X: `flutter run --dart-define=X_CLIENT_ID=…` (app type "Native App",
/// Callback URI `xloginexample://callback`). Without it the app runs against
/// tools/mock_idp.
const clientIdDefine = String.fromEnvironment('X_CLIENT_ID');
const useMock = clientIdDefine == '';

// The Android emulator reaches the host machine through 10.0.2.2.
final String idp =
    'http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:4000';

final login = useMock
    ? createXLogin(
        authorizationEndpoint: '$idp/authorize',
        tokenEndpoint: '$idp/token',
        userInfoEndpoint: '$idp/2/users/me',
        revocationEndpoint: '$idp/revoke',
      )
    : xLogin;

const options = SignInOptions(
  clientId: useMock ? 'example-app' : clientIdDefine,
  // Scheme set in android/app/build.gradle.kts.
  redirectUri: 'xloginexample://callback',
);

/// Profile + email + refresh token.
const profileScopes = [...xDefaultScopes, xEmailScope, xOfflineScope];

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'X login example',
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
  final controller = ProviderLoginController<XProfile>(login, options);
  String mode = '';
  String note = '';
  String? accessToken;
  String? refreshToken;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> signIn(String label, SignInOptions next) async {
    setState(() {
      mode = label;
      note = '';
    });
    final result = await controller.signIn(next);
    setState(() {
      accessToken = result?.accessToken;
      refreshToken = result?.refreshToken;
    });
  }

  Future<void> refresh() async {
    try {
      final tokens = await login.refresh(
        clientId: options.clientId,
        refreshToken: refreshToken!,
      );
      setState(() {
        accessToken = tokens.accessToken;
        refreshToken = tokens.refreshToken ?? refreshToken;
        note = 'REFRESHED';
      });
    } on AuthException catch (error) {
      setState(() => note = 'REFRESH FAILED ${error.code.value}');
    }
  }

  Future<void> signOut() async {
    await controller.signOut(token: accessToken, tokenTypeHint: 'access_token');
    setState(() {
      accessToken = null;
      refreshToken = null;
      note = 'SIGNED OUT';
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('X login example')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final busy = controller.loading;
        final result = controller.result;
        final error = controller.error;
        final profile = result?.profile;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              useMock ? 'Provider: local mock (no credentials)' : 'Provider: X',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : () => signIn('code', options),
              child: const Text('Sign in (code only)'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => signIn(
                      'profile',
                      options.copyWith(
                        exchangeCode: true,
                        scopes: profileScopes,
                      ),
                    ),
              child: const Text('Sign in + profile'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: refreshToken == null ? null : refresh,
              child: const Text('Refresh token'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: accessToken == null ? null : signOut,
              child: const Text('Sign out (revoke)'),
            ),
            const SizedBox(height: 16),
            if (busy) const LinearProgressIndicator(),
            if (note.isNotEmpty) Text(note),
            if (error != null)
              Text(
                'ERROR ${error.code.value}: ${error.message}',
                style: const TextStyle(color: Color(0xFFB00020)),
              ),
            if (result != null && note != 'SIGNED OUT') ...[
              Text('SIGNED IN ($mode)'),
              Text('verifier: ${result.codeVerifier?.length} chars'),
              if (profile != null) ...[
                Text('id: ${profile.id}'),
                Text('username: @${profile.username}'),
                Text('name: ${profile.name}'),
                Text('email: ${profile.email}'),
                Text('refresh token: ${refreshToken != null}'),
              ],
            ],
          ],
        );
      },
    ),
  );
}
