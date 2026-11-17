# Ejemplo de social_auth_x

Login con X como cliente público (PKCE, sin secret): código para tu backend, o canje, perfil, refresh y revocación en el dispositivo.

Con el proveedor local (sin cuenta de X), desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
cd packages/social_auth_x/example && flutter run
```

Con X real registra `xloginexample://callback` como Callback URI de tu app (tipo Native App) y corre:

```sh
flutter run --dart-define=X_CLIENT_ID=<client id>
```
