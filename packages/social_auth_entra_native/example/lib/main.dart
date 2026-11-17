import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:social_auth_entra_native/social_auth_entra_native.dart';

/// Real tenant: `flutter run --dart-define=ENTRA_TENANT=contoso
/// --dart-define=ENTRA_CLIENT_ID=…`. Without them the app talks to
/// tools/mock_entra.
const tenantDefine = String.fromEnvironment('ENTRA_TENANT');
const clientIdDefine = String.fromEnvironment('ENTRA_CLIENT_ID');
const useMock = clientIdDefine == '';

// The Android emulator reaches the host machine through 10.0.2.2.
final String host = Platform.isAndroid ? '10.0.2.2' : 'localhost';

final auth = useMock
    ? EntraNativeAuth(
        tenantSubdomain: 'mock-tenant',
        clientId: 'mock-entra-client',
        baseUrl: 'http://$host:4700/mock-tenant',
      )
    : EntraNativeAuth(tenantSubdomain: tenantDefine, clientId: clientIdDefine);

/// Redirect URI registered in the app, for the browser fallback (scheme set
/// in android/app/build.gradle.kts).
const redirectUri = 'entraexample://callback';

/// What tools/mock_entra accepts, so the mock can be tried without typing.
const demo = useMock
    ? (email: 'ada@example.com', password: 'Passw0rd!', code: '12345678')
    : (email: '', password: '', code: '');

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Entra native auth example',
    theme: ThemeData(colorSchemeSeed: const Color(0xFF0067B8)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final email = TextEditingController(text: demo.email);
  final password = TextEditingController(text: demo.password);
  final name = TextEditingController(text: 'Demo User');
  final code = TextEditingController(text: demo.code);

  /// The pending step of the flow in progress, if any.
  EntraStep? step;
  EntraTokens? tokens;
  String message = '';
  bool busy = false;

  @override
  void dispose() {
    for (final controller in [email, password, name, code]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Runs one call and shows whatever step Entra asks for next.
  Future<void> run(String label, Future<EntraStep> Function() task) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final next = await task();
      setState(() {
        if (next is SignedInStep) {
          tokens = next.tokens;
          step = null;
          message = '$label: SIGNED IN';
        } else {
          step = next;
          message = '$label: ${_name(next)}';
        }
      });
    } on EntraAuthException catch (error) {
      setState(() => message = '$label FAILED: ${error.reason}');
    } on AuthException catch (error) {
      setState(() => message = '$label FAILED: ${error.code.value}');
    } finally {
      setState(() => busy = false);
    }
  }

  void start(String label, Future<EntraStep> Function() task) {
    setState(() {
      tokens = null;
      step = null;
    });
    run(label, task);
  }

  static String _name(EntraStep step) => switch (step) {
    CodeRequiredStep() => 'CODE_REQUIRED',
    PasswordRequiredStep() => 'PASSWORD_REQUIRED',
    AttributesRequiredStep() => 'ATTRIBUTES_REQUIRED',
    NewPasswordRequiredStep() => 'NEW_PASSWORD_REQUIRED',
    BrowserRequiredStep() => 'BROWSER_REQUIRED',
    SignedInStep() => 'SIGNED_IN',
  };

  Widget button(String label, VoidCallback? onPressed) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: FilledButton(onPressed: busy ? null : onPressed, child: Text(label)),
  );

  Widget field(String label, TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      controller: controller,
      obscureText: controller == password,
      autocorrect: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final current = step;
    final signedIn = tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Entra native auth example')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            useMock
                ? 'Provider: local mock (no tenant)'
                : 'Provider: Entra ($tenantDefine)',
          ),
          field('Email', email),
          field('Password', password),
          field('Display name', name),
          button(
            'Sign in',
            () => start(
              'SIGN IN',
              () => auth.signIn(username: email.text, password: password.text),
            ),
          ),
          button(
            'Sign up',
            () => start(
              'SIGN UP',
              () => auth.signUp(
                username: email.text,
                password: password.text,
                attributes: {'displayName': name.text},
              ),
            ),
          ),
          button(
            'Reset password',
            () =>
                start('RESET', () => auth.resetPassword(username: email.text)),
          ),
          if (useMock)
            button(
              'Use a new demo email',
              () => setState(
                () => email.text =
                    'demo${DateTime.now().millisecondsSinceEpoch % 100000}'
                    '@example.com',
              ),
            ),
          const SizedBox(height: 16),
          ...switch (current) {
            CodeRequiredStep() => [
              Text(
                'Code sent to ${current.sentTo ?? 'your email'} '
                '(${current.codeLength ?? '?'} digits)',
              ),
              field('Code', code),
              button(
                'Submit code',
                () => run('CODE', () => auth.submitCode(current, code.text)),
              ),
              button(
                'Resend code',
                () => run('RESEND', () => auth.resendCode(current)),
              ),
            ],
            NewPasswordRequiredStep() => [
              const Text('The Password field above is the new password.'),
              button(
                'Set new password',
                () => run(
                  'NEW PASSWORD',
                  () => auth.submitNewPassword(current, password.text),
                ),
              ),
            ],
            PasswordRequiredStep() => [
              button(
                'Submit password',
                () => run(
                  'PASSWORD',
                  () => auth.submitPassword(current, password.text),
                ),
              ),
            ],
            AttributesRequiredStep() => [
              button(
                'Submit attributes',
                () => run(
                  'ATTRIBUTES',
                  () => auth.submitAttributes(current, {
                    'displayName': name.text,
                  }),
                ),
              ),
            ],
            BrowserRequiredStep() => [
              button(
                'Continue in the browser',
                () => run(
                  'BROWSER',
                  () async => SignedInStep(
                    await auth.signInWithBrowser(
                      redirectUri: redirectUri,
                      loginHint: current.username,
                    ),
                  ),
                ),
              ),
            ],
            SignedInStep() || null => const <Widget>[],
          },
          if (busy) const LinearProgressIndicator(),
          if (message.isNotEmpty)
            Text(
              message,
              style: TextStyle(
                color: message.contains('FAILED')
                    ? const Color(0xFFB00020)
                    : const Color(0xFF0A7D32),
              ),
            ),
          if (signedIn != null) ...[
            Text('email: ${signedIn.profile?.email}'),
            Text('name: ${signedIn.profile?.name}'),
            Text(
              'refresh token: ${signedIn.refreshToken != null ? 'yes' : 'no'}',
            ),
            button(
              'Refresh token',
              signedIn.refreshToken == null
                  ? null
                  : () => run(
                      'REFRESH',
                      () async => SignedInStep(
                        await auth.refresh(signedIn.refreshToken!),
                      ),
                    ),
            ),
            button(
              'Sign out',
              // Native auth has no sign-out call: drop the tokens you stored.
              () => setState(() {
                tokens = null;
                message = 'SIGNED OUT';
              }),
            ),
          ],
        ],
      ),
    );
  }
}
