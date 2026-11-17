# Ejemplo de social_auth_mercadolibre

Login con Mercado Libre y canje del código (con el verifier PKCE) en `tools/mercadolibre_backend`.

Con el proveedor local (sin aplicación de Mercado Libre), desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/mercadolibre_backend/server.mjs
cd packages/social_auth_mercadolibre/example && flutter run
```

Con Mercado Libre real ver [tools/mercadolibre_backend/README.md](../../../tools/mercadolibre_backend/README.md).
