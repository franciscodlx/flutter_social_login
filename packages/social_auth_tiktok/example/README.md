# Ejemplo de social_auth_tiktok

Login con TikTok (flujo web de Login Kit) y canje del código en `tools/tiktok_backend`.

Con el proveedor local (sin app de TikTok), desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/tiktok_backend/server.mjs
cd packages/social_auth_tiktok/example && flutter run
```

Con TikTok real ver [tools/tiktok_backend/README.md](../../../tools/tiktok_backend/README.md).
