# Ejemplo de social_auth_presets

Un botón por proveedor (GitHub, Discord, Slack, Strava); el canje del código lo hace `tools/presets_backend`.

Con el proveedor local (sin cuentas), desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/presets_backend/server.mjs
cd packages/social_auth_presets/example && flutter run
```

Con proveedores reales ver [tools/presets_backend/README.md](../../../tools/presets_backend/README.md).
