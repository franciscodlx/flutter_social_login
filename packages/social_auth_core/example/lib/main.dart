import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:social_auth_core/social_auth_core.dart';

// The Android emulator reaches the host machine through 10.0.2.2.
final String idp =
    'http://${Platform.isAndroid ? '10.0.2.2' : 'localhost'}:4000';

typedef Profile = ({String id, String name, String email});

// Run it with `node tools/mock_idp/server.mjs` from the repository root.
final mockLogin = ProviderLogin<Profile>(
  ProviderConfig(
    id: 'mock-idp',
    authorizationEndpoint: '$idp/authorize',
    tokenEndpoint: '$idp/token',
    userInfoEndpoint: '$idp/userinfo',
    revocationEndpoint: '$idp/revoke',
    issuer: 'http://localhost:4000',
    defaultScopes: const ['openid', 'profile', 'email'],
    useNonce: true,
    mapProfile: (raw) =>
        (id: '${raw['sub']}', name: '${raw['name']}', email: '${raw['email']}'),
  ),
);

const options = SignInOptions(
  clientId: 'example-app',
  redirectUri: 'socialauthcore://callback',
);

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'social_auth_core example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF1F6FEB)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final controller = ProviderLoginController(mockLogin, options);
  String mode = '';
  String note = '';

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> signIn(String label, {required bool exchangeCode}) async {
    setState(() {
      mode = label;
      note = '';
    });
    await controller.signIn(options.copyWith(exchangeCode: exchangeCode));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('social_auth_core example')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final result = controller.result;
        final error = controller.error;
        final profile = result?.profile;
        final accessToken = result?.accessToken;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            FilledButton(
              onPressed: controller.loading
                  ? null
                  : () => signIn('code', exchangeCode: false),
              child: const Text('Sign in (code only)'),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.loading
                  ? null
                  : () => signIn('exchange', exchangeCode: true),
              child: const Text('Sign in + exchange'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: accessToken == null
                  ? null
                  : () async {
                      await controller.signOut(token: accessToken);
                      setState(() => note = 'SIGNED OUT');
                    },
              child: const Text('Sign out (revoke)'),
            ),
            const SizedBox(height: 16),
            if (controller.loading) const LinearProgressIndicator(),
            if (note.isNotEmpty) Text(note),
            if (error != null)
              Text(
                'ERROR ${error.code.value}: ${error.message}',
                style: const TextStyle(color: Color(0xFFB00020)),
              ),
            if (result != null) ...[
              Text('SIGNED IN ($mode)'),
              Text('code: ${result.code.length} chars'),
              Text('verifier: ${result.codeVerifier?.length} chars'),
              if (profile != null) ...[
                Text('id: ${profile.id}'),
                Text('name: ${profile.name}'),
                Text('email: ${profile.email}'),
                Text('refresh token: ${result.refreshToken != null}'),
              ],
            ],
          ],
        );
      },
    ),
  );
}
