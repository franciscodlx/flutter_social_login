# social_auth_linkedin

Login con LinkedIn para Flutter (iOS y Android) con OpenID Connect, en el navegador del sistema. Sin WebView y sin `clientSecret` en la app.

## Compatibilidad

| Paquete | Flutter                   | iOS  | Android        | Web, escritorio |
| ------- | ------------------------- | ---- | -------------- | --------------- |
| 0.1.x   | ≥ 3.35 (probado con 3.50) | ≥ 15 | ≥ 7.0 (API 24) | No              |

## Instalación

```sh
flutter pub add social_auth_linkedin
```

Android necesita el esquema de tu app en `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
}
```

iOS no necesita configuración.

## Configurar el proveedor

1. Crea la app en [LinkedIn Developers](https://www.linkedin.com/developers/apps) y agrega el producto **Sign In with LinkedIn using OpenID Connect**.
2. En Auth → Authorized redirect URLs registra una URL **https de tu backend**, por ejemplo `https://api.miapp.com/auth/linkedin/callback`. LinkedIn no acepta esquemas propios (`miapp://`).
3. Scopes: `openid profile email` (los que usa el paquete por defecto).

LinkedIn exige el `client_secret` para cambiar el código por tokens, así que necesitas un backend con dos rutas: una que reenvíe el redirect a tu app y otra que haga el canje. [`tools/linkedin_backend`](../../tools/linkedin_backend) es una implementación completa.

```
app ──signIn()──▶ LinkedIn ──https──▶ tu backend /callback ──miapp://callback──▶ app
app ──code──▶ tu backend /exchange ──code + secret──▶ LinkedIn ──▶ perfil
```

## Uso

```dart
import 'package:social_auth_linkedin/social_auth_linkedin.dart';

const options = SignInOptions(
  clientId: 'TU_CLIENT_ID',
  redirectUri: 'https://api.miapp.com/auth/linkedin/callback',
  callbackUri: 'miapp://callback',
);

try {
  final result = await linkedInLogin.signIn(options);
  await http.post(
    Uri.parse('https://api.miapp.com/auth/linkedin/exchange'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'code': result.code, 'redirectUri': result.redirectUri}),
  );
} on AuthException catch (e) {
  if (e.code == AuthErrorCode.cancelled) return; // el usuario cerró o rechazó
  rethrow;
}
```

Para un widget, `ProviderLoginController(linkedInLogin, options)` expone `loading`, `result` y `error` como `ChangeNotifier`.

| Exporta                                                                               | Para qué                                                                                       |
| ------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| `linkedInLogin`                                                                       | `signIn`, `isAvailable`                                                                        |
| `createLinkedInLogin(...)`                                                            | Otra instancia: parámetros extra (`extraAuthParams: {'enable_extended_login': 'true'}`) o un servidor de pruebas |
| `LinkedInProfile.fromJson(userinfo)`                                                  | Convierte la respuesta de `/v2/userinfo` (o los claims del `id_token`)                         |
| `linkedInTokenEndpoint`, `linkedInUserInfoEndpoint`, `linkedInJwksUri`, `linkedInIssuer` | Constantes para tu backend                                                                   |

`signIn(options.copyWith(exchangeCode: true))` falla con `INVALID_CONFIG`: el canje en el dispositivo no es posible con LinkedIn.

## Backend (canje del código)

```js
// Node
const tokens = await fetch('https://www.linkedin.com/oauth/v2/accessToken', {
  method: 'POST',
  headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
  body: new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: 'https://api.miapp.com/auth/linkedin/callback',
    client_id: process.env.LINKEDIN_CLIENT_ID,
    client_secret: process.env.LINKEDIN_CLIENT_SECRET,
  }),
}).then((r) => r.json());
const profile = await fetch('https://api.linkedin.com/v2/userinfo', {
  headers: { Authorization: `Bearer ${tokens.access_token}` },
}).then((r) => r.json());
```

```php
// Laravel
$tokens = Http::asForm()->post('https://www.linkedin.com/oauth/v2/accessToken', [
    'grant_type' => 'authorization_code',
    'code' => $request->input('code'),
    'redirect_uri' => config('services.linkedin.redirect'),
    'client_id' => config('services.linkedin.client_id'),
    'client_secret' => config('services.linkedin.client_secret'),
])->throw()->json();
$profile = Http::withToken($tokens['access_token'])
    ->get('https://api.linkedin.com/v2/userinfo')->throw()->json();
```

Verifica la firma del `id_token` con `linkedInJwksUri` antes de confiar en él (el backend de ejemplo lo hace).

## Errores normalizados

`AuthException.code`: `cancelled | network | invalidConfig | providerError | notSupported` (`.value` da `CANCELLED`, `NETWORK`, …). `user_cancelled_login` y `user_cancelled_authorize` de LinkedIn llegan como `cancelled`; el código original queda en `providerError`.

## Seguridad

- `state` generado y verificado en el dispositivo. LinkedIn no documenta PKCE ni `nonce` para este flujo, así que no se envían.
- El backend solo acepta los redirect URIs que conoce y reenvía a un `callbackUri` fijo en su configuración, nunca tomado de la petición.
- Devuelve tu propia sesión desde el backend; el access token de LinkedIn no debería llegar a la app.

## Migrar desde linkedin_login

| Antes (`linkedin_login`)                                | Ahora                                                      |
| ------------------------------------------------------- | ---------------------------------------------------------- |
| `LinkedInUserWidget` con `clientSecret` en la app       | `linkedInLogin.signIn` + canje en tu backend               |
| `LinkedInAuthCodeWidget` → `onGetAuthCode`              | `linkedInLogin.signIn(options)` → `result.code`            |
| WebView propio, `redirectUrl` https                     | Navegador del sistema; el backend reenvía a `miapp://`     |
| `appBar`, `destroySession`                              | No aplican: el navegador del sistema maneja la sesión      |

## Probar sin credenciales

`example/` corre contra `tools/mock_idp` y `tools/linkedin_backend`. Ver [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
