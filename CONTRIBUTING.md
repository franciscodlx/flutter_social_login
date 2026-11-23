# Contribuir

## Preparar el entorno

```sh
flutter pub get
```

Las pruebas de `social_auth_entra_native` arrancan `tools/mock_entra`, así que `dart run melos run test` necesita Node ≥ 22.

## Correr el ejemplo

1. Proveedor local (Node ≥ 22): `node tools/mock_idp/server.mjs`. Con `MOCK_IDP_AUTO=approve` redirige sin mostrar la pantalla de consentimiento; con `MOCK_IDP_AUTO=deny` siempre rechaza.
2. App: `cd packages/social_auth_core/example && flutter run`.

En el emulador de Android el ejemplo llega al proveedor local por `10.0.2.2`; en el simulador de iOS, por `localhost`.

### Ejemplos de proveedor

| Ejemplo                                 | Servicios locales                                   | Casos                                                                            |
| --------------------------------------- | --------------------------------------------------- | -------------------------------------------------------------------------------- |
| `packages/social_auth_linkedin/example` | `tools/mock_idp` + `tools/linkedin_backend` (4100)  | Aprobar → `SIGNED IN`, `id_token verified: true`; rechazar o cerrar → `CANCELLED` |
| `packages/social_auth_x/example`        | `tools/mock_idp`                                    | "Sign in + profile" → perfil, email y `refresh token: true`; "Refresh token" → `REFRESHED`; "Sign out" → `SIGNED OUT`; rechazar o cerrar → `CANCELLED` |
| `packages/social_auth_mercadolibre/example` | `tools/mock_idp` + `tools/mercadolibre_backend` (4200) | Aprobar → `SIGNED IN`, `site: MLM`, `refresh token on backend: true`; rechazar o cerrar → `CANCELLED` |
| `packages/social_auth_twitch/example`   | `tools/mock_idp` + `tools/twitch_backend` (4300)    | Aprobar → `SIGNED IN`, email verificado, `id_token verified (signature + nonce): true`; rechazar o cerrar → `CANCELLED` |
| `packages/social_auth_presets/example`  | `tools/mock_idp` + `tools/presets_backend` (4400)   | Cada botón, aprobar → `SIGNED IN (<proveedor>)` con perfil; rechazar o cerrar → `CANCELLED` |
| `packages/social_auth_telegram/example` | `tools/mock_idp` + `tools/telegram_backend` (4500)  | Aprobar → `SIGNED IN` con teléfono, `id_token verified by backend: true`; rechazar o cerrar → `CANCELLED` |
| `packages/social_auth_tiktok/example`   | `tools/mock_idp` + `tools/tiktok_backend` (4600)    | Aprobar → `SIGNED IN`, `granted scopes: user.info.basic`; rechazar o cerrar → `CANCELLED` |
| `packages/social_auth_entra_native/example` | `tools/mock_entra` (4700, código `12345678`)    | "Sign in" → `SIGNED IN` y refresh; "Use a new demo email" + "Sign up" + "Submit code" → `SIGNED IN`; "Reset password" → código → nueva contraseña → `SIGNED IN`; contraseña incorrecta → `FAILED: invalid_grant` |

Si en el mismo emulador está instalado el ejemplo equivalente de `rn-social-login`, ambos registran el mismo esquema y Android muestra "Abrir con…" al volver del navegador.

Los servidores de `tools/` arrancan con `node tools/<nombre>/server.mjs` (`server.js` en `mock_entra`) y sus pruebas con `node --test` dentro de su carpeta.

## Agregar un proveedor

1. `packages/social_auth_<proveedor>` con `lib/`, `test/`, `README.md`, `CHANGELOG.md`, `LICENSE` (copiar la estructura de `social_auth_linkedin`).
2. `flutter create --template=app --org dev.franciscodlx.socialauth --platforms=android,ios --project-name social_auth_<proveedor>_example packages/social_auth_<proveedor>/example`, borrar `.idea`, `*.iml`, `pubspec.lock` y la prueba de plantilla, y agregar `manifestPlaceholders["authCoreRedirectScheme"]`.
3. Agregar ambos al `workspace:` del `pubspec.yaml` raíz y la matriz de ejemplos en `.github/workflows/ci.yml`.

## Qué probar en dispositivo antes de abrir un PR

| Caso                           | Resultado esperado                           |
| ------------------------------ | -------------------------------------------- |
| "Sign in (code only)", aprobar | `SIGNED IN (code)`, verifier de 43 caracteres |
| "Sign in + exchange", aprobar  | Perfil y `refresh token: true`               |
| "Sign out (revoke)"            | `SIGNED OUT`                                 |
| Rechazar en el proveedor       | `ERROR CANCELLED`                            |
| Cerrar el navegador            | `ERROR CANCELLED`                            |

## Cambiar la interfaz nativa

La interfaz entre Dart y cada plataforma está en `pigeon/messages.dart` de `social_auth_core_android` y `social_auth_core_ios` (deben coincidir). Después de editarla:

```sh
dart run pigeon --input pigeon/messages.dart
```

## Publicar

Se publica solo al hacer merge a `main`:

1. En tu PR, sube `version:` en el `pubspec.yaml` de cada paquete que cambió y agrega la entrada en su `CHANGELOG.md`. El CI corre `flutter pub publish --dry-run` en todos los paquetes (falla si falta la entrada del CHANGELOG, por ejemplo) y lista las versiones que se publicarían.
2. Al hacer merge, el workflow `Release` empuja el tag `<paquete>-v<versión>` de cada versión que aún no está en pub.dev, en orden de dependencias, y espera a que aparezca antes de seguir con el siguiente.
3. Cada tag dispara `Publish to pub.dev`, que publica con la publicación automática de pub.dev (OIDC, sin token).

Si un paquete depende de una versión nueva de otro del repo (por ejemplo, un proveedor que necesita `social_auth_core` 0.2.0), sube ambos en el mismo PR. Un paquete **nuevo** se publica la primera vez a mano (`flutter pub publish`), y después se activa su publicación automática en pub.dev.

## Convenciones

- Commits con [Conventional Commits](https://www.conventionalcommits.org/): `feat(core): …`, `fix(android): …`.
- Documentación en español; identificadores y comentarios de código en inglés.
- `dart format .` y `dart analyze --fatal-infos .` deben pasar.
- `tools/mock_idp`, `tools/mock_entra` y `tools/*_backend` son copias de `examples/mock-idp`, `examples/mock-entra` y `examples/*-backend` de `rn-social-login`: si cambias una, cambia la otra.
