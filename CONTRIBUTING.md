# Contribuir

## Preparar el entorno

```sh
flutter pub get
```

## Correr el ejemplo

1. Proveedor local (Node ≥ 22): `node tools/mock_idp/server.mjs`. Con `MOCK_IDP_AUTO=approve` redirige sin mostrar la pantalla de consentimiento; con `MOCK_IDP_AUTO=deny` siempre rechaza.
2. App: `cd packages/social_auth_core/example && flutter run`.

En el emulador de Android el ejemplo llega al proveedor local por `10.0.2.2`; en el simulador de iOS, por `localhost`.

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

## Convenciones

- Commits con [Conventional Commits](https://www.conventionalcommits.org/): `feat(core): …`, `fix(android): …`.
- Documentación en español; identificadores y comentarios de código en inglés.
- `dart format .` y `dart analyze --fatal-infos .` deben pasar.
- `tools/mock_idp` es una copia de `examples/mock-idp` de `rn-social-login`: si cambias una, cambia la otra.
