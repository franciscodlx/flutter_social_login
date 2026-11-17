# social_auth_telegram

Log in with Telegram para Flutter (iOS y Android) con OpenID Connect + PKCE, en el navegador del sistema. Sin WebView y sin Client Secret en la app.

## Compatibilidad

| Paquete | Flutter                   | iOS  | Android        | Web, escritorio |
| ------- | ------------------------- | ---- | -------------- | --------------- |
| 0.1.x   | ≥ 3.35 (probado con 3.50) | ≥ 15 | ≥ 7.0 (API 24) | No              |

## Instalación

```sh
flutter pub add social_auth_telegram
```

Android necesita el esquema de tu app en `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
}
```

iOS no necesita configuración.

## Configurar el proveedor

1. En [@BotFather](https://t.me/BotFather) elige tu bot → **Login Widget**. Ahí aparecen el Client ID y el Client Secret.
2. En "Allowed URLs" agrega una URL **https de tu backend**, por ejemplo `https://api.miapp.com/auth/telegram/callback`. Telegram solo redirige a URLs registradas.

El canje del código se autentica con el Client Secret, así que necesitas un backend con dos rutas: una que reenvíe el redirect a tu app y otra que haga el canje. [`tools/telegram_backend`](../../tools/telegram_backend) es una implementación completa.

```
app ──signIn()──▶ Telegram ──https──▶ tu backend /callback ──miapp://callback──▶ app
app ──code + codeVerifier──▶ tu backend /exchange ──+ secret──▶ Telegram ──▶ id_token verificado
```

## Uso

```dart
import 'package:social_auth_telegram/social_auth_telegram.dart';

const options = SignInOptions(
  clientId: 'TU_CLIENT_ID',
  redirectUri: 'https://api.miapp.com/auth/telegram/callback',
  callbackUri: 'miapp://callback',
);

try {
  final result = await telegramLogin.signIn(options);
  await http.post(
    Uri.parse('https://api.miapp.com/auth/telegram/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'code': result.code,
      'codeVerifier': result.codeVerifier,
      'redirectUri': result.redirectUri,
    }),
  );
} on AuthException catch (e) {
  if (e.code == AuthErrorCode.cancelled) return;
  rethrow;
}
```

Con un widget, `ProviderLoginController(telegramLogin, options)` expone `signIn()`, `loading`, `result` y `error` como `ChangeNotifier`.

Scopes:

| Scope                 | Constante                | Qué agrega                                        |
| --------------------- | ------------------------ | ------------------------------------------------- |
| `openid`              | —                        | Obligatorio: `sub`                                |
| `profile`             | —                        | `id`, `name`, `preferred_username`, `picture`     |
| `phone`               | `telegramPhoneScope`     | `phone_number` (Telegram pide permiso al usuario) |
| `telegram:bot_access` | `telegramBotAccessScope` | Tu bot puede escribirle al usuario tras el login  |

Por defecto se piden `openid profile`. Para el teléfono: `options.copyWith(scopes: [...telegramDefaultScopes, telegramPhoneScope])`.

| Exporta                                                       | Para qué                                                 |
| ------------------------------------------------------------- | -------------------------------------------------------- |
| `telegramLogin`                                               | `signIn`, `isAvailable`                                  |
| `createTelegramLogin(...)`                                    | Otra instancia: otros scopes o un servidor de pruebas    |
| `TelegramProfile.fromJson(claims)`                            | Convierte los claims del `id_token` en `TelegramProfile` |
| `telegramTokenEndpoint`, `telegramJwksUri`, `telegramIssuer`  | Constantes para tu backend                               |

`signIn(options.copyWith(exchangeCode: true))` falla con `INVALID_CONFIG`: el canje en el dispositivo no es posible.

## Backend (canje del código)

Node, completo y con pruebas: [`tools/telegram_backend/server.mjs`](../../tools/telegram_backend/server.mjs). Laravel:

```php
// Reenvía el redirect de Telegram a la app.
Route::get('/auth/telegram/callback', fn (Request $r) =>
    redirect()->away('miapp://callback?' . $r->getQueryString()));

Route::post('/auth/telegram/exchange', function (Request $r) {
    $tokens = Http::asForm()
        ->withBasicAuth(config('services.telegram.client_id'), config('services.telegram.client_secret'))
        ->post('https://oauth.telegram.org/token', [
            'grant_type' => 'authorization_code',
            'code' => $r->input('code'),
            'code_verifier' => $r->input('codeVerifier'),
            'redirect_uri' => config('services.telegram.redirect'), // fijo, no el que mande la app
            'client_id' => config('services.telegram.client_id'),
        ])->throw()->json();

    // Verifica el id_token: firma con https://oauth.telegram.org/.well-known/jwks.json,
    // iss = https://oauth.telegram.org, aud = tu Client ID y exp.
    $claims = verifyTelegramIdToken($tokens['id_token']);

    // Crea aquí tu propia sesión para $claims->sub.
    return ['profile' => $claims];
});
```

Telegram no tiene endpoint de userinfo: el perfil son los claims del `id_token`. Firma con RS256 por defecto; otros algoritmos se eligen en BotFather (EdDSA y ES256K solo admiten el scope `openid`).

## Errores normalizados

`AuthException.code`: `cancelled | network | invalidConfig | providerError | notSupported` (`.value` da `CANCELLED`, `NETWORK`, …). El código original de Telegram queda en `providerError`.

## Seguridad

- El Client Secret vive solo en tu backend; la app nunca recibe un token de Telegram.
- `state` y PKCE (S256) se generan en el dispositivo; el `codeVerifier` viaja al backend junto con el código.
- El backend verifica firma, emisor, audiencia y caducidad del `id_token` antes de confiar en el perfil.
- En tu backend, el destino del reenvío y el `redirect_uri` del canje deben ser fijos, no tomados de la petición.

## Frente al widget clásico y a los SDK nativos

- El widget clásico (hash HMAC con el token del bot, `/setdomain`) es para sitios web y Telegram lo dejó como "legacy"; este paquete usa el flujo OpenID Connect actual.
- Telegram publica SDK nativos (`telegram-login-ios`, `telegram-login-android`) que abren la app de Telegram en vez del navegador. Este paquete no los envuelve.

## Sin verificar contra Telegram real

- Si acepta esquemas propios (`miapp://`) en "Allowed URLs": la documentación no lo dice, y con el redirect https al backend no hace falta.
- El código de error cuando el usuario rechaza (se asume `access_denied`).
- Si `client_id` es el id numérico del bot o un identificador aparte: la documentación usa ambos términos; usa el valor que muestre BotFather.

## Probar sin credenciales

`example/` corre contra `tools/mock_idp` y `tools/telegram_backend`. Ver [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
