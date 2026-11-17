# Ejemplo de social_auth_telegram

Login con Telegram (pide además el teléfono) y canje del código en `tools/telegram_backend`, que verifica el `id_token`.

Con el proveedor local (sin bot de Telegram), desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/telegram_backend/server.mjs
cd packages/social_auth_telegram/example && flutter run
```

Con Telegram real ver [tools/telegram_backend/README.md](../../../tools/telegram_backend/README.md).
