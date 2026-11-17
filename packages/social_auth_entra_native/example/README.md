# Ejemplo de social_auth_entra_native

Inicio de sesión, alta y restablecimiento de contraseña con pantallas propias contra la API de native authentication de Entra.

Con el servidor local (sin tenant), desde la raíz del repo:

```sh
node tools/mock_entra/server.js
cd packages/social_auth_entra_native/example && flutter run
```

Datos del mock: `ada@example.com` / `Passw0rd!`, código `12345678`. Ver [tools/mock_entra/README.md](../../../tools/mock_entra/README.md).

Con un tenant externo real (ver [Configurar el proveedor](../README.md#configurar-el-proveedor)):

```sh
flutter run --dart-define=ENTRA_TENANT=<subdominio> --dart-define=ENTRA_CLIENT_ID=<client id>
```
