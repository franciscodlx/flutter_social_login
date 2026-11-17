# Ejemplo de social_auth_linkedin

Login con LinkedIn y canje del código en `tools/linkedin_backend`.

Con el proveedor local (sin cuenta de LinkedIn), desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/linkedin_backend/server.mjs
cd packages/social_auth_linkedin/example && flutter run
```

Con LinkedIn real ver [tools/linkedin_backend/README.md](../../../tools/linkedin_backend/README.md).
