# social_auth_entra_native

Native authentication de Microsoft Entra External ID para Flutter (iOS y Android): alta, inicio de sesión y restablecimiento de contraseña con tus propias pantallas, sin abrir el navegador. Es un cliente de la API de Microsoft, no un envoltorio de los SDK MSAL nativos.

## Compatibilidad

| Paquete | Flutter                   | iOS  | Android        | Web, escritorio |
| ------- | ------------------------- | ---- | -------------- | --------------- |
| 0.1.x   | ≥ 3.35 (probado con 3.50) | ≥ 15 | ≥ 7.0 (API 24) | No              |

## Instalación

```sh
flutter pub add social_auth_entra_native
```

El núcleo (`social_auth_core`) solo se usa para el fallback al navegador. Si lo vas a usar, Android necesita el esquema de tu app en `android/app/build.gradle.kts`:

```kotlin
defaultConfig {
    manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
}
```

## Configurar el proveedor

Solo funciona con **tenants externos** (External ID), no con tenants de empleados.

1. Registra la app en el tenant externo y concede el consentimiento de administrador.
2. En Authentication activa **Allow public client flows** y **Enable native authentication**.
3. Crea un user flow (correo con contraseña o correo con código de un solo uso) y asócialo a la app.
4. Para restablecer contraseñas, activa el self-service password reset para clientes.
5. Para el fallback al navegador, registra un redirect URI (`miapp://callback`).

## Uso

Cada llamada devuelve el siguiente paso; tu pantalla muestra lo que ese paso pide y devuelve el paso completo a la siguiente función. `EntraStep` es una `sealed class`, así que un `switch` cubre todos los casos:

```dart
import 'package:social_auth_entra_native/social_auth_entra_native.dart';

final auth = EntraNativeAuth(
  tenantSubdomain: 'contoso', // contoso.onmicrosoft.com
  clientId: 'TU_CLIENT_ID',
);

var step = await auth.signIn(username: email, password: password);

switch (step) {
  case SignedInStep(:final tokens): // accessToken, idToken, refreshToken, profile
    break;
  case CodeRequiredStep(): // se envió un código a step.sentTo
    step = await auth.submitCode(step, codigo);
  case PasswordRequiredStep():
    step = await auth.submitPassword(step, password);
  case BrowserRequiredStep(): // Entra pide continuar en el navegador
    final tokens = await auth.signInWithBrowser(
      redirectUri: 'miapp://callback',
      loginHint: step.username,
    );
  case AttributesRequiredStep() || NewPasswordRequiredStep():
    break;
}
```

| Método                                              | Qué hace                                                                 |
| --------------------------------------------------- | ------------------------------------------------------------------------ |
| `signIn(username:, password:)`                      | Con contraseña, o con código por correo si se omite                      |
| `signUp(username:, password:, attributes:)`         | Alta; envía un código al correo                                          |
| `resetPassword(username:)`                          | Envía el código para restablecer                                         |
| `submitCode(step, code)` / `resendCode(step)`       | Responde a `CodeRequiredStep`                                            |
| `submitPassword(step, password)`                    | Responde a `PasswordRequiredStep`                                        |
| `submitAttributes(step, attributes)`                | Responde a `AttributesRequiredStep` (ver `step.requiredAttributes`)      |
| `submitNewPassword(step, newPassword)`              | Responde a `NewPasswordRequiredStep`; espera al cambio e inicia sesión   |
| `refresh(refreshToken)`                             | Nuevo access token                                                       |
| `signInWithBrowser(redirectUri:, loginHint:)`       | Fallback: código de autorización + PKCE en el navegador del sistema      |

| Paso                      | Qué mostrar                                   |
| ------------------------- | --------------------------------------------- |
| `CodeRequiredStep`        | Campo para el código (`sentTo`, `codeLength`) |
| `PasswordRequiredStep`    | Campo de contraseña                           |
| `AttributesRequiredStep`  | Los campos de `requiredAttributes`            |
| `NewPasswordRequiredStep` | Campo de contraseña nueva                     |
| `BrowserRequiredStep`     | Botón para continuar en el navegador          |
| `SignedInStep`            | Nada: ya hay tokens                           |

Los scopes por defecto son `openid offline_access` (id_token y refresh token); cámbialos con `scopes:`. `baseUrl:` apunta el cliente a un servidor de pruebas y `httpClient:` permite inyectar tu propio `http.Client`.

### Cerrar sesión

La API no tiene llamada de cierre de sesión: borra los tokens que guardaste.

## Errores

`EntraAuthException` extiende el `AuthException` de la familia (`cancelled | network | invalidConfig | providerError | notSupported`) y agrega el detalle de Entra. `error.reason` sirve para un `switch`:

| `reason`                                                                                                                      | Significado                                     |
| ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- |
| `user_not_found`                                                                                                              | No existe la cuenta                             |
| `user_already_exists`                                                                                                         | El correo ya está registrado                    |
| `invalid_grant`                                                                                                               | Usuario o contraseña incorrectos                |
| `invalid_grant:invalid_oob_value`                                                                                             | Código incorrecto                               |
| `invalid_grant:password_too_weak`, `:password_too_short`, `:password_too_long`, `:password_recently_used`, `:password_banned` | La contraseña no cumple la política             |
| `invalid_grant:attribute_validation_failed`                                                                                   | Atributos inválidos (`error.invalidAttributes`) |
| `expired_token`                                                                                                               | El paso caducó: empieza el flujo de nuevo       |

Un `client_id` o tenant incorrecto, o native authentication sin activar, llega como `invalidConfig`. Sin conexión llega un `AuthException` con `network`. `error.traceId` y `error.correlationId` sirven para soporte de Microsoft.

## Backend

No hace falta backend para iniciar sesión: la app es un cliente público. Tu API debe validar el access token (firma con las claves del tenant, `aud` y `exp`) como con cualquier token de Entra. El paquete solo decodifica el `id_token` para armar `profile`; no verifica su firma.

## Seguridad

- Con native authentication la contraseña pasa por tu app: no la guardes ni la registres en logs, y envíala solo a través de este cliente (HTTPS).
- Guarda los tokens en Keychain/Keystore (por ejemplo con `flutter_secure_storage`), no en `shared_preferences`.
- El `continuationToken` de cada paso es de un solo uso y de vida corta; no lo persistas.
- Todas las peticiones ofrecen `redirect`, como exige Microsoft: si Entra no puede terminar por API, responde `BrowserRequiredStep` en vez de fallar.

## Límites de esta versión

- **MFA**: el cliente no declara la capacidad `mfa_required`, así que si la política exige segundo factor Entra responde `BrowserRequiredStep` y el flujo termina en el navegador.
- **Restablecimiento de contraseña**: los parámetros de `start`, `challenge`, `continue` y `submit` no pudieron contrastarse con la referencia de Microsoft (esa parte de la página no se pudo leer); están implementados según el mismo patrón que alta e inicio de sesión.
- No hay SSO entre apps a través del navegador con native authentication.
- No funciona en web: la API no admite CORS.
- Nada se ha probado contra un tenant real.

## Probar sin tenant

`example/` corre contra [`tools/mock_entra`](../../tools/mock_entra), un servidor local que imita la API. Las pruebas del paquete arrancan ese mismo servidor, así que `flutter test` necesita Node ≥ 22. Ver [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Licencia

MIT.
