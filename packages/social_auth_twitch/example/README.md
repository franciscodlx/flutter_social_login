# Ejemplo de social_auth_twitch

Login con Twitch y canje del código en `tools/twitch_backend`, que verifica la firma y el `nonce` del `id_token`.

Con el proveedor local (sin aplicación de Twitch), desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/twitch_backend/server.mjs
cd packages/social_auth_twitch/example && flutter run
```

Con Twitch real ver [tools/twitch_backend/README.md](../../../tools/twitch_backend/README.md).
