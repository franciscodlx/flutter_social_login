# social_auth_twitch

Login con Twitch para Flutter (iOS y Android) con OpenID Connect, en el navegador del sistema. Sin WebView y sin `client_secret` en la app.

## Compatibilidad

| Paquete | Flutter                   | iOS  | Android        | Web, escritorio |
| ------- | ------------------------- | ---- | -------------- | --------------- |
| 0.1.x   | ≥ 3.35 (probado con 3.50) | ≥ 15 | ≥ 7.0 (API 24) | No              |

## Instalación

```sh
flutter pub add social_auth_twitch
```

Android necesita el esquema de tu app en `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
}
```

iOS no necesita configuración.

## Configurar el proveedor

1. Registra la aplicación en la [consola de Twitch](https://dev.twitch.tv/console/apps) con tipo de cliente **Confidential** y genera un Client Secret.
2. En "OAuth Redirect URLs" registra una URL **https de tu backend**, por ejemplo `https://api.miapp.com/auth/twitch/callback`.
3. Scopes por defecto: `openid user:read:email`.

El canje del código exige el `client_secret`, así que tu backend tiene dos rutas: una que reenvía el redirect a tu app y otra que canjea el código y verifica el `id_token`. [`tools/twitch_backend`](../../tools/twitch_backend) es una implementación completa.

```
app ──signIn()──▶ Twitch ──https──▶ tu backend /callback ──miapp://callback──▶ app
app ──code + nonce──▶ tu backend /exchange ──+ secret──▶ Twitch ──▶ id_token verificado + perfil
```

## Uso

```dart
import 'package:social_auth_twitch/social_auth_twitch.dart';

const options = SignInOptions(
  clientId: 'TU_CLIENT_ID',
  redirectUri: 'https://api.miapp.com/auth/twitch/callback',
  callbackUri: 'miapp://callback',
);

try {
  final result = await twitchLogin.signIn(options);
  await http.post(
    Uri.parse('https://api.miapp.com/auth/twitch/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'code': result.code,
      'nonce': result.nonce,
      'redirectUri': result.redirectUri,
    }),
  );
} on AuthException catch (e) {
  if (e.code == AuthErrorCode.cancelled) return;
  rethrow;
}
```

| Exporta                                                         | Para qué                                                                                          |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `twitchLogin`                                                   | `signIn`, `isAvailable`                                                                           |
| `createTwitchLogin(...)`                                        | Otra instancia: otros parámetros (`{'claims': twitchClaims([...]), 'force_verify': 'true'}`) o un servidor de pruebas |
| `twitchClaims(claims)`, `TwitchClaim`                           | Valor del parámetro `claims`                                                                      |
| `TwitchProfile.fromJson`                                        | Convierte la respuesta de userinfo o los claims del `id_token`                                    |
| `twitchTokenEndpoint`, `twitchJwksUri`, `twitchIssuer`, `twitchValidateEndpoint`, … | Constantes para tu backend                                                  |

Twitch solo devuelve `sub` si no se piden los demás claims. El paquete manda por defecto `claims` con `email`, `email_verified`, `picture` y `preferred_username`, para el `id_token` y para userinfo. Los de email requieren además el scope `user:read:email`.

`signIn(options.copyWith(exchangeCode: true))` falla con `INVALID_CONFIG`: el canje en el dispositivo no es posible.

## Backend (canje del código)

Node, completo y con pruebas: [`tools/twitch_backend/server.mjs`](../../tools/twitch_backend/server.mjs). Laravel:

```php
// Reenvía el redirect de Twitch a la app.
Route::get('/auth/twitch/callback', fn (Request $r) =>
    redirect()->away('miapp://callback?' . $r->getQueryString()));

Route::post('/auth/twitch/exchange', function (Request $r) {
    $tokens = Http::asForm()->post('https://id.twitch.tv/oauth2/token', [
        'grant_type' => 'authorization_code',
        'code' => $r->input('code'),
        'redirect_uri' => config('services.twitch.redirect'), // fijo, no el que mande la app
        'client_id' => config('services.twitch.client_id'),
        'client_secret' => config('services.twitch.client_secret'),
    ])->throw()->json();

    // Verifica el id_token: firma RS256 con https://id.twitch.tv/oauth2/keys,
    // iss = https://id.twitch.tv/oauth2, aud = tu client id, exp,
    // y nonce === $r->input('nonce'). Por ejemplo con firebase/php-jwt.
    $claims = verifyTwitchIdToken($tokens['id_token'], $r->input('nonce'));

    // Crea aquí tu propia sesión para $claims->sub.
    return ['profile' => $claims];
});
```

## Errores normalizados

`AuthException.code`: `cancelled | network | invalidConfig | providerError | notSupported` (`.value` da `CANCELLED`, `NETWORK`, …). El código original de Twitch queda en `providerError`.

## Seguridad

- `state` y `nonce` generados en el dispositivo; el backend comprueba que el `id_token` traiga ese `nonce`. Twitch no documenta PKCE, así que no se envía.
- El `client_secret` y los tokens de Twitch viven solo en tu backend. Si sigues usando el access token, Twitch pide validarlo al arrancar y cada hora (`twitchValidateEndpoint`).
- El backend reenvía a un `callbackUri` fijo en su configuración, nunca tomado de la petición.

## Probar sin credenciales

`example/` corre contra `tools/mock_idp` y `tools/twitch_backend`. Ver [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
