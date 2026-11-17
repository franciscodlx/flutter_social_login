# social_auth_presets

Login con GitHub, Discord, Slack y Strava para Flutter (iOS y Android) sobre [`social_auth_core`](../social_auth_core): navegador del sistema, sin WebView y sin `client_secret` en la app.

## Compatibilidad

| Paquete | Flutter                   | iOS  | Android        | Web, escritorio |
| ------- | ------------------------- | ---- | -------------- | --------------- |
| 0.1.x   | ≥ 3.35 (probado con 3.50) | ≥ 15 | ≥ 7.0 (API 24) | No              |

## Instalación

```sh
flutter pub add social_auth_presets
```

Android necesita el esquema de tu app en `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
}
```

iOS no necesita configuración.

## Presets

| Preset          | Scopes por defecto          | Protección además de `state`    | Dónde se registra el redirect                |
| --------------- | --------------------------- | ------------------------------- | -------------------------------------------- |
| `githubPreset`  | `read:user user:email`      | PKCE (S256)                     | OAuth App → Authorization callback URL       |
| `discordPreset` | `identify email`            | PKCE (S256), `iss` del redirect | Developer Portal → OAuth2 → Redirects        |
| `slackPreset`   | `openid profile email`      | `nonce` (OpenID Connect)        | App → OAuth & Permissions → Redirect URLs    |
| `stravaPreset`  | `read` (separados por coma) | ninguna documentada             | API settings → Authorization Callback Domain |

Los cuatro exigen el `client_secret` para cambiar el código por tokens, así que el canje va en tu backend. [`tools/presets_backend`](../../tools/presets_backend) lo implementa para los cuatro.

```
app ──signIn()──▶ proveedor ──https──▶ tu backend /callback ──miapp://callback──▶ app
app ──code + codeVerifier | nonce──▶ tu backend /exchange ──+ secret──▶ proveedor ──▶ perfil
```

## Uso

```dart
import 'package:social_auth_presets/social_auth_presets.dart';

const options = SignInOptions(
  clientId: 'TU_CLIENT_ID',
  redirectUri: 'https://api.miapp.com/auth/github/callback',
  callbackUri: 'miapp://callback',
);

try {
  final result = await githubLogin.signIn(options);
  await http.post(
    Uri.parse('https://api.miapp.com/auth/github/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'code': result.code,
      'codeVerifier': result.codeVerifier, // GitHub y Discord
      'nonce': result.nonce, // Slack
      'redirectUri': result.redirectUri,
    }),
  );
} on AuthException catch (e) {
  if (e.code == AuthErrorCode.cancelled) return;
  rethrow;
}
```

Con un widget, `ProviderLoginController(githubLogin, options)` expone `signIn()`, `loading`, `result` y `error` como `ChangeNotifier`.

| Exporta                                                                        | Para qué                                                                |
| ------------------------------------------------------------------------------ | ----------------------------------------------------------------------- |
| `githubLogin`, `discordLogin`, `slackLogin`, `stravaLogin`                     | `signIn`, `signOut`, `isAvailable`                                      |
| `createPresetLogin(preset, ...)`                                               | Otra instancia: otros scopes, parámetros extra o un servidor de pruebas |
| `githubPreset`, …, `presets['github']`                                         | Config del proveedor; `.backend` trae los endpoints de token, usuario, revocación y JWKS para tu backend |
| `mapGitHubProfile`, `mapDiscordProfile`, `mapSlackProfile`, `mapStravaProfile` | Perfil normalizado `PresetProfile(id, username, name, email, picture, raw)` |

Ejemplos de ajustes:

```dart
createPresetLogin(stravaPreset, defaultScopes: ['read', 'activity:read']);
createPresetLogin(stravaPreset, extraAuthParams: {'approval_prompt': 'force'});
createPresetLogin(githubPreset, extraAuthParams: {'prompt': 'select_account'});
createPresetLogin(slackPreset, extraAuthParams: {'team': 'T0123456'});
```

`extraAuthParams` reemplaza los del preset; para agregar uno solo en una llamada usa `SignInOptions(extraParams: …)`.

Otro proveedor: arma tu propio `Preset(config: ProviderConfig(id: …, authorizationEndpoint: …, defaultScopes: …, mapProfile: …), backend: PresetBackend(tokenEndpoint: …))` y pásalo a `createPresetLogin`.

`signIn(options.copyWith(exchangeCode: true))` falla con `INVALID_CONFIG`: el canje en el dispositivo no es posible con estos proveedores.

## Backend (canje del código)

Node, completo y con pruebas: [`tools/presets_backend/server.mjs`](../../tools/presets_backend/server.mjs). Laravel, con GitHub como ejemplo:

```php
Route::get('/auth/github/callback', fn (Request $r) =>
    redirect()->away('miapp://callback?' . $r->getQueryString()));

Route::post('/auth/github/exchange', function (Request $r) {
    $tokens = Http::asForm()->acceptJson()->post('https://github.com/login/oauth/access_token', [
        'code' => $r->input('code'),
        'code_verifier' => $r->input('codeVerifier'),
        'redirect_uri' => config('services.github.redirect'), // fijo, no el que mande la app
        'client_id' => config('services.github.client_id'),
        'client_secret' => config('services.github.client_secret'),
    ])->throw()->json();

    $user = Http::withToken($tokens['access_token'])
        ->get('https://api.github.com/user')->throw()->json();

    // Crea aquí tu propia sesión para $user['id'].
    return ['profile' => $user];
});
```

Diferencias por proveedor:

- **GitHub**: pide `Accept: application/json` en el token (si no, responde form-encoded). `email` viene `null` si es privado; el principal está en `/user/emails` (scope `user:email`). El código caduca a los 10 minutos.
- **Discord**: el token solo acepta `application/x-www-form-urlencoded`.
- **Slack**: las respuestas traen `ok: true/false`; revisa `ok` además del estado HTTP. Verifica el `id_token` con `https://slack.com/openid/connect/keys`, emisor `https://slack.com` y el `nonce`.
- **Strava**: el perfil (`athlete`) llega en la respuesta de tokens. El access token dura 6 horas y el refresh token puede cambiar en cada renovación.

## Errores normalizados

`AuthException.code`: `cancelled | network | invalidConfig | providerError | notSupported` (`.value` da `CANCELLED`, `NETWORK`, …). El código original del proveedor queda en `providerError`.

## Seguridad

- El `client_secret` y los tokens viven solo en tu backend.
- `state` siempre; PKCE donde el proveedor lo documenta (GitHub, Discord) y `nonce` en Slack.
- Discord incluye `iss` en el redirect: el paquete rechaza la respuesta con `providerError` si no es `https://discord.com`.
- En tu backend, el destino del reenvío y el `redirect_uri` del canje deben ser fijos, no tomados de la petición.

## Sin verificar contra los proveedores reales

- Si GitHub, Discord, Slack o Strava aceptan esquemas propios (`miapp://`) como redirect: la documentación no lo dice, y con el redirect https al backend no hace falta.
- El código de error al rechazar en GitHub, Discord y Slack (se asume `access_denied`; Strava sí lo documenta).
- Slack acepta `code_verifier` en el token pero no documenta `code_challenge` en la autorización, así que PKCE queda apagado en ese preset. Para probarlo: `createPresetLogin(slackPreset, usePkce: true)`.
- Con la app de Strava instalada, el endpoint móvil puede abrir la app en vez del navegador; ese camino no se probó.

## Probar sin credenciales

`example/` corre contra `tools/mock_idp` y `tools/presets_backend`. Ver [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
