# flutter_social_login

Plugins de login social para Flutter sobre un núcleo compartido: OAuth 2.0 authorization code + PKCE en el navegador del sistema (`ASWebAuthenticationSession` en iOS, Custom Tabs en Android), sin WebView y sin `clientSecret` en la app.

Es el gemelo de [`rn-social-login`](https://github.com/franciscodlx/rn-social-login) (React Native): misma API (`signIn`, `signOut`, `isAvailable`) y mismos códigos de error.

## Paquetes

| Paquete                                                                               | Qué hace                                                            | Estado                   |
| ------------------------------------------------------------------------------------- | ------------------------------------------------------------------- | ------------------------ |
| [`social_auth_core`](packages/social_auth_core)                                       | PKCE, `state`/`nonce`, navegador del sistema, errores normalizados  | Probado en iOS y Android |
| [`social_auth_core_platform_interface`](packages/social_auth_core_platform_interface) | Interfaz de plataforma y `AuthException`                            | —                        |
| [`social_auth_core_android`](packages/social_auth_core_android)                       | Implementación Android (Custom Tabs)                                | —                        |
| [`social_auth_core_ios`](packages/social_auth_core_ios)                               | Implementación iOS (Swift Package Manager y CocoaPods)              | —                        |
| [`social_auth_linkedin`](packages/social_auth_linkedin)                               | LinkedIn (OpenID Connect), canje en tu backend                      | Probado contra el mock   |
| [`social_auth_x`](packages/social_auth_x)                                             | X (Twitter), cliente público con PKCE, refresh y revocación         | Probado contra el mock   |
| [`social_auth_mercadolibre`](packages/social_auth_mercadolibre)                       | Mercado Libre (host por país, PKCE), canje en tu backend            | Probado contra el mock   |
| [`social_auth_twitch`](packages/social_auth_twitch)                                   | Twitch (OpenID Connect, `nonce`, `claims`), canje en tu backend     | Probado contra el mock   |
| [`social_auth_presets`](packages/social_auth_presets)                                 | GitHub, Discord, Slack y Strava, canje en tu backend                | Probado contra el mock   |
| [`social_auth_telegram`](packages/social_auth_telegram)                               | Telegram (OpenID Connect + PKCE), canje en tu backend               | Probado contra el mock   |
| [`social_auth_tiktok`](packages/social_auth_tiktok)                                   | TikTok (Login Kit, flujo web), canje en tu backend                  | Probado contra el mock   |
| [`social_auth_entra_native`](packages/social_auth_entra_native)                       | Entra External ID native auth (pantallas propias, sin navegador)    | Probado contra el mock   |

El núcleo es un plugin federado: la app solo depende de `social_auth_core`, que trae las implementaciones de cada plataforma.

## Estructura

```
packages/social_auth_core                     lógica OAuth en Dart + app de ejemplo
packages/social_auth_core_platform_interface  contrato entre Dart y cada plataforma
packages/social_auth_core_android             Kotlin
packages/social_auth_core_ios                 Swift
packages/social_auth_<proveedor>              un paquete Dart por proveedor + app de ejemplo
tools/mock_idp                                proveedor OIDC local para probar sin credenciales
tools/mock_entra                              API de native auth de Entra, local
tools/<proveedor>_backend                     backend de ejemplo (redirect https + canje con secret)
```

Los paquetes de proveedor son Dart puro: no agregan código nativo. `package:social_auth_core/testing.dart` trae `FakeBrowser` para probar sin dispositivo.

## Desarrollo

Requiere Flutter ≥ 3.35 (probado con 3.50) y Node ≥ 22 para los servidores de `tools/`. Es un workspace de pub con [Melos](https://melos.invertase.dev).

```sh
flutter pub get        # resuelve todo el workspace
dart analyze .
dart format .
dart run melos run test
```

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para correr el ejemplo.

## Licencia

MIT.
