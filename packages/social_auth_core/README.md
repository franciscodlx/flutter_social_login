# social_auth_core

Núcleo compartido de los plugins de login social para Flutter (iOS y Android): OAuth 2.0 authorization code + PKCE en el navegador del sistema, sin WebView y sin `clientSecret` en la app.

Úsalo directamente con cualquier proveedor OAuth 2.0 / OpenID Connect, o a través de un paquete de proveedor de la familia.

## Compatibilidad

| Paquete | Flutter | iOS  | Android        | Web, escritorio |
| ------- | ------- | ---- | -------------- | --------------- |
| 0.1.x   | ≥ 3.35 (probado con 3.50) | ≥ 15 | ≥ 7.0 (API 24) | No              |

## Instalación

```sh
flutter pub add social_auth_core
```

Android necesita el esquema de tu redirect en `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
}
```

iOS no necesita configuración. Detalles: [doc/android.md](doc/android.md), [doc/ios.md](doc/ios.md).

## Configurar el proveedor

1. Registra la app en el portal del proveedor como cliente **público** (nativo), si lo permite.
2. Registra el redirect URI, por ejemplo `miapp://callback`.
3. Si el proveedor exige `client_secret` o solo acepta redirects https, el canje va en tu backend (ver "Proveedores que solo aceptan redirect https").

## Uso

```dart
import 'package:social_auth_core/social_auth_core.dart';

final login = ProviderLogin<Map<String, dynamic>>(
  ProviderConfig(
    id: 'mi-proveedor',
    authorizationEndpoint: 'https://idp.example.com/authorize',
    tokenEndpoint: 'https://idp.example.com/token', // solo clientes públicos
    userInfoEndpoint: 'https://idp.example.com/userinfo',
    issuer: 'https://idp.example.com',
    defaultScopes: const ['openid', 'profile', 'email'],
    useNonce: true,
    mapProfile: (raw) => raw,
  ),
);

const options = SignInOptions(
  clientId: 'TU_CLIENT_ID',
  redirectUri: 'miapp://callback',
);

try {
  // Recomendado: tu backend canjea el código.
  final result = await login.signIn(options);
  // result.code, result.codeVerifier, result.redirectUri

  // O en el dispositivo, como cliente público:
  final session = await login.signIn(options.copyWith(exchangeCode: true));
  // session.accessToken, session.refreshToken, session.profile
} on AuthException catch (e) {
  if (!e.isCancelled) rethrow;
}
```

Para un widget, `ProviderLoginController` es un `ChangeNotifier` con `loading`, `result` y `error`:

```dart
final controller = ProviderLoginController(login, options);

ListenableBuilder(
  listenable: controller,
  builder: (context, _) => FilledButton(
    onPressed: controller.loading ? null : controller.signIn,
    child: const Text('Entrar'),
  ),
);
```

| API                                                        | Para qué                                                        |
| ---------------------------------------------------------- | --------------------------------------------------------------- |
| `ProviderLogin(config).signIn / signOut / isAvailable`     | La API de toda la familia                                       |
| `ProviderLoginController`                                  | Estado para widgets                                             |
| `authorize(AuthorizeRequest)` / `cancelAuthorize()`        | Solo el paso del navegador                                      |
| `exchangeCode`, `refreshAccessToken`, `revokeToken`, `fetchUserInfo` | Llamadas de cliente público                           |
| `decodeIdToken`, `validateIdTokenClaims`                   | Leer y revisar `iss`, `aud`, `exp`, `nonce` (no la firma)       |
| `PkcePair.generate()`                                      | Verifier y challenge S256                                       |

### Proveedores que solo aceptan redirect https

Registra en el proveedor una URL de tu backend y haz que reenvíe la query a tu app:

```dart
const SignInOptions(
  clientId: 'TU_CLIENT_ID',
  redirectUri: 'https://api.miapp.com/auth/callback', // registrada en el proveedor
  callbackUri: 'miapp://callback', // donde escucha la app
);
```

## Backend (canje del código)

Envía `code`, `codeVerifier` y `redirectUri` a tu backend, que hace el `POST` al token endpoint. Los backends de ejemplo en Node (y fragmentos en Laravel) están en [`rn-social-login`](https://github.com/franciscodlx/rn-social-login/tree/main/examples); son los mismos para Flutter.

## Errores normalizados

`AuthException.code` es uno de `AuthErrorCode.cancelled | network | invalidConfig | providerError | notSupported` (`code.value` da `CANCELLED`, `NETWORK`, … como en React Native). El error original del proveedor queda en `providerError` y `providerErrorDescription`.

## Seguridad

- PKCE (S256) y `state` se generan con el generador aleatorio seguro de la plataforma en cada inicio de sesión; el `state` se verifica antes de aceptar un código.
- El redirect se compara con el `redirectUri` configurado (esquema, host y ruta).
- El inicio de sesión ocurre en el navegador del sistema: la app no ve la contraseña ni las cookies.
- La firma del `id_token` **no** se verifica en el dispositivo; hazlo en tu backend.
- El núcleo no guarda tokens. Usa Keychain / Keystore (por ejemplo `flutter_secure_storage`), no `SharedPreferences`.
- Solo acepta endpoints `https`, salvo `http` hacia `localhost`, `127.0.0.1` y `10.0.2.2` para pruebas.

## Probar sin credenciales

`example/` corre contra `tools/mock_idp`, un proveedor OpenID Connect local. Ver [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
