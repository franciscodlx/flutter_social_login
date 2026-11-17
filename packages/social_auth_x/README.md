# social_auth_x

Login con X (Twitter) para Flutter (iOS y Android) con OAuth 2.0 + PKCE, en el navegador del sistema. Cliente público: sin consumer secret en la app.

## Compatibilidad

| Paquete | Flutter                   | iOS  | Android        | Web, escritorio |
| ------- | ------------------------- | ---- | -------------- | --------------- |
| 0.1.x   | ≥ 3.35 (probado con 3.50) | ≥ 15 | ≥ 7.0 (API 24) | No              |

## Instalación

```sh
flutter pub add social_auth_x
```

Android necesita el esquema de tu app en `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
}
```

iOS no necesita configuración.

## Configurar el proveedor

1. Crea un proyecto y una app en el [portal de desarrolladores de X](https://developer.x.com).
2. En User authentication settings elige el tipo **Native App** (cliente público, sin secret).
3. Registra tu Callback URI, por ejemplo `miapp://callback`. X la compara de forma exacta.
4. Usa el **Client ID** de OAuth 2.0 (no la API Key de OAuth 1.0a).

## Uso

```dart
import 'package:social_auth_x/social_auth_x.dart';

const options = SignInOptions(
  clientId: 'TU_CLIENT_ID',
  redirectUri: 'miapp://callback',
);

// Recomendado: tu backend hace el canje.
final result = await xLogin.signIn(options);
// result.code, result.codeVerifier, result.redirectUri

// O en el dispositivo:
final session = await xLogin.signIn(
  options.copyWith(
    exchangeCode: true,
    scopes: [...xDefaultScopes, xEmailScope, xOfflineScope],
  ),
);
// session.accessToken, session.refreshToken, session.profile (XProfile)
```

| Exporta                                              | Para qué                                                         |
| ---------------------------------------------------- | ---------------------------------------------------------------- |
| `xLogin.signIn / signOut / isAvailable`              | Login; `signOut(clientId:, token:)` revoca el token              |
| `xLogin.refresh(clientId:, refreshToken:)`           | Nuevo access token (requiere `offline.access`)                   |
| `createXLogin(...)`                                  | Otra instancia, p. ej. contra un servidor de pruebas             |
| `ProviderLoginController(xLogin, options)`           | Estado para widgets (`loading`, `result`, `error`)               |
| `XProfile.fromJson`, `xUserInfoUrl`, `xTokenEndpoint`, … | Utilidades y constantes para tu backend                     |

Scopes por defecto: `users.read tweet.read` (los que pide `GET /2/users/me`). `offline.access` agrega el refresh token; `users.email` agrega `profile.email`.

## Backend (canje del código)

El código de X **caduca a los 30 segundos**: envíalo al backend de inmediato.

```js
// Node
const res = await fetch('https://api.x.com/2/oauth2/token', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    code_verifier: codeVerifier,
    redirect_uri: 'miapp://callback',
    client_id: process.env.X_CLIENT_ID,
  }),
});
const { access_token } = await res.json();
const me = await fetch('https://api.x.com/2/users/me', {
  headers: { Authorization: `Bearer ${access_token}` },
}).then((r) => r.json()); // { data: { id, name, username } }
```

```php
// Laravel
$tokens = Http::asForm()->post('https://api.x.com/2/oauth2/token', [
    'grant_type' => 'authorization_code',
    'code' => $request->input('code'),
    'code_verifier' => $request->input('codeVerifier'),
    'redirect_uri' => config('services.x.redirect'),
    'client_id' => config('services.x.client_id'),
])->throw()->json();
$me = Http::withToken($tokens['access_token'])
    ->get('https://api.x.com/2/users/me')->throw()->json('data');
```

## Errores normalizados

`AuthException.code`: `cancelled | network | invalidConfig | providerError | notSupported` (`.value` da `CANCELLED`, `NETWORK`, …). El código original de X queda en `providerError` y el status HTTP en `status`.

## Seguridad

- PKCE con S256 y `state` generados y verificados en el dispositivo.
- Sin secret en la app. Si canjeas en el dispositivo, guarda los tokens en Keychain/Keystore (p. ej. `flutter_secure_storage`), no en `shared_preferences`.
- El access token dura 2 horas. Al refrescar, guarda el refresh token nuevo que llegue.
- X no es OpenID Connect: no hay `id_token`. La identidad se confirma en el backend llamando a `/2/users/me`.

## Migrar desde paquetes OAuth 1.0a

Los paquetes de Flutter basados en OAuth 1.0a piden la API Key y el API Secret en la app. Con este paquete:

| Antes                                         | Ahora                                                   |
| --------------------------------------------- | ------------------------------------------------------- |
| API Key + API Secret en la app                | Solo el Client ID de OAuth 2.0 (tipo Native App)        |
| `authToken` + `authTokenSecret`               | `accessToken` (+ `refreshToken` con `offline.access`)   |
| Endpoints v1.1 (`account/verify_credentials`) | `GET /2/users/me`; los tokens OAuth 2.0 no sirven en v1.1 |

## Probar sin credenciales

`example/` corre contra `tools/mock_idp`. Ver [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Sin verificar contra X real

La documentación de X no confirma: esquemas propios en la Callback URI, el código de error al cancelar (se asume `access_denied`), si el refresh token rota, y qué pasa en Android con la app de X instalada (el núcleo abre siempre el navegador, no la app).

## Licencia

MIT.
