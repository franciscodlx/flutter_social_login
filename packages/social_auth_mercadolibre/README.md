# social_auth_mercadolibre

Login con Mercado Libre para Flutter (iOS y Android) en el navegador del sistema, con PKCE y el canje del código en tu backend. Sin WebView y sin `client_secret` en la app.

## Compatibilidad

| Paquete | Flutter                   | iOS  | Android        | Web, escritorio |
| ------- | ------------------------- | ---- | -------------- | --------------- |
| 0.1.x   | ≥ 3.35 (probado con 3.50) | ≥ 15 | ≥ 7.0 (API 24) | No              |

## Instalación

```sh
flutter pub add social_auth_mercadolibre
```

Android necesita el esquema de tu app en `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
}
```

iOS no necesita configuración.

## Configurar el proveedor

1. Crea la aplicación en el DevCenter de Mercado Libre (Mis aplicaciones) con una cuenta del país donde la vas a usar.
2. Registra como URI de redirect una URL **https de tu backend**, por ejemplo `https://api.miapp.com/auth/mercadolibre/callback`.
3. Activa **PKCE** en la aplicación, para que el canje exija el verifier.
4. Los scopes (`read`, `write`, `offline_access`) se eligen en la aplicación, no en la petición.

El canje necesita el `client_secret`, así que tu backend tiene dos rutas: una que reenvía el redirect a tu app y otra que canjea el código. [`tools/mercadolibre_backend`](../../tools/mercadolibre_backend) es una implementación completa.

```
app ──signIn()──▶ Mercado Libre ──https──▶ tu backend /callback ──miapp://callback──▶ app
app ──code + codeVerifier──▶ tu backend /exchange ──+ secret──▶ Mercado Libre ──▶ perfil
```

## Uso

```dart
import 'package:social_auth_mercadolibre/social_auth_mercadolibre.dart';

final login = createMercadoLibreLogin(country: MercadoLibreCountry.mx);

const options = SignInOptions(
  clientId: 'TU_APP_ID',
  redirectUri: 'https://api.miapp.com/auth/mercadolibre/callback',
  callbackUri: 'miapp://callback',
);

try {
  final result = await login.signIn(options);
  await http.post(
    Uri.parse('https://api.miapp.com/auth/mercadolibre/exchange'),
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

| Exporta                                                         | Para qué                                                                  |
| --------------------------------------------------------------- | ------------------------------------------------------------------------- |
| `createMercadoLibreLogin(country: …)`                           | Login para un país; `authorizationEndpoint:` para un servidor de pruebas  |
| `MercadoLibreCountry`                                           | Países y su host de autorización; `fromCode('MX')`                        |
| `MercadoLibreProfile.fromJson`                                  | Convierte la respuesta de `GET /users/me`                                 |
| `mercadoLibreTokenEndpoint`, `mercadoLibreUserInfoEndpoint`     | Constantes para tu backend                                                |

Cada cuenta pertenece a un sitio: el usuario debe autorizar en el host del país donde la creó. Si tu app atiende varios países, pregunta el país antes de llamar a `signIn`.

`signIn(options.copyWith(exchangeCode: true))` falla con `INVALID_CONFIG`: el canje en el dispositivo no es posible.

## Backend (canje del código)

Node, completo y con pruebas: [`tools/mercadolibre_backend/server.mjs`](../../tools/mercadolibre_backend/server.mjs). Laravel:

```php
// Reenvía el redirect de Mercado Libre a la app.
Route::get('/auth/mercadolibre/callback', fn (Request $r) =>
    redirect()->away('miapp://callback?' . $r->getQueryString()));

Route::post('/auth/mercadolibre/exchange', function (Request $r) {
    $tokens = Http::asForm()->acceptJson()->post('https://api.mercadolibre.com/oauth/token', [
        'grant_type' => 'authorization_code',
        'code' => $r->input('code'),
        'code_verifier' => $r->input('codeVerifier'),
        'redirect_uri' => config('services.mercadolibre.redirect'), // fijo, no el que mande la app
        'client_id' => config('services.mercadolibre.client_id'),
        'client_secret' => config('services.mercadolibre.client_secret'),
    ])->throw()->json();

    $user = Http::withToken($tokens['access_token'])
        ->get('https://api.mercadolibre.com/users/me')->throw()->json();

    // Guarda $tokens en el servidor y crea tu propia sesión para $user['id'].
    return ['profile' => $user];
});
```

## Errores normalizados

`AuthException.code`: `cancelled | network | invalidConfig | providerError | notSupported` (`.value` da `CANCELLED`, `NETWORK`, …). El código original queda en `providerError`.

## Seguridad

- El `client_secret` y los tokens de Mercado Libre viven solo en tu backend.
- `state` y PKCE (S256) se generan en el dispositivo; el `codeVerifier` viaja al backend junto con el código, así un código interceptado no sirve por sí solo.
- En tu backend, el destino del reenvío y el `redirect_uri` del canje deben ser fijos, no tomados de la petición.

## Pendiente de confirmar con una aplicación real

La documentación de Mercado Libre no se pudo consultar de forma automatizada (responde 403), así que esto se escribió de memoria y falta confirmarlo:

- Que el host de autorización de cada país sea el de `MercadoLibreCountry`.
- El código de error que llega cuando el usuario rechaza (se asume `access_denied`).
- Duración del access token y del refresh token.
- Si un usuario operador (colaborador) puede autorizar o solo el titular de la cuenta.

## Probar sin credenciales

`example/` corre contra `tools/mock_idp` y `tools/mercadolibre_backend`. Ver [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
