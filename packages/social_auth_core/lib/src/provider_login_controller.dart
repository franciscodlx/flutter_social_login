import 'package:flutter/foundation.dart';
import 'package:social_auth_core_platform_interface/social_auth_core_platform_interface.dart';

import 'provider.dart';

/// Listenable state around a provider's `signIn` / `signOut`, for a widget:
///
/// ```dart
/// final controller = ProviderLoginController(login, options);
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, _) => FilledButton(
///     onPressed: controller.loading ? null : controller.signIn,
///     child: const Text('Sign in'),
///   ),
/// );
/// ```
class ProviderLoginController<TProfile> extends ChangeNotifier {
  ProviderLoginController(this.login, this.options);

  final ProviderLogin<TProfile> login;

  /// Options of the next sign-in; may be replaced at any time.
  SignInOptions options;

  bool _loading = false;
  SignInResult<TProfile>? _result;
  AuthException? _error;
  bool _disposed = false;

  bool get loading => _loading;
  SignInResult<TProfile>? get result => _result;

  /// Last failure. A user cancellation has code [AuthErrorCode.cancelled].
  AuthException? get error => _error;

  /// Completes with the result, or null if it failed (see [error]).
  Future<SignInResult<TProfile>?> signIn([SignInOptions? overrides]) async {
    _update(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final next = await login.signIn(overrides ?? options);
      _update(() => _result = next);
      return next;
    } on Object catch (error) {
      _update(() => _error = AuthException.from(error));
      return null;
    } finally {
      _update(() => _loading = false);
    }
  }

  Future<void> signOut({String? token, String? tokenTypeHint}) async {
    await login.signOut(
      clientId: options.clientId,
      token: token,
      tokenTypeHint: tokenTypeHint,
    );
    _update(() {
      _result = null;
      _error = null;
    });
  }

  void _update(VoidCallback change) {
    change();
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
