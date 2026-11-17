# Backend de ejemplo para TikTok

Servidor Node sin dependencias que hace las dos cosas que TikTok no permite hacer desde la app:

| Ruta                         | Qué hace                                                                                          |
| ---------------------------- | ------------------------------------------------------------------------------------------------- |
| `GET /auth/tiktok/callback`  | Recibe el redirect https de TikTok y reenvía `code`, `scopes` y `state` a la app (`APP_CALLBACK`) |
| `POST /auth/tiktok/exchange` | Cambia el `code` por tokens con `client_key` + `client_secret` y devuelve el perfil               |

## Con el proveedor local

Desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/tiktok_backend/server.mjs   # puerto 4600
```

## Con TikTok real

1. Crea la app en <https://developers.tiktok.com> y agrega el producto Login Kit.
2. Expón este servidor por https (Cloudflare Tunnel, ngrok).
3. En Login Kit registra `<PUBLIC_URL>/auth/tiktok/callback` como Redirect URI (https, sin parámetros ni fragmento).
4. Copia `.env.example` a `.env`, complétalo con el Client key y el Client secret, y arranca con `node --env-file=.env server.mjs`.
5. Corre el ejemplo con tus valores:

   ```sh
   cd packages/social_auth_tiktok/example
   flutter run --dart-define=TIKTOK_CLIENT_KEY=<client key> --dart-define=BACKEND_URL=<PUBLIC_URL>
   ```

El `.env` está en `.gitignore`: el secret nunca se sube ni viaja a la app.

## Qué cambiar en un backend real

- Devuelve tu propia sesión (cookie o JWT tuyo), no el perfil tal cual.
- Guarda access y refresh token en el servidor. El refresh token rota: cada renovación devuelve uno nuevo e invalida el anterior.
- Usa `expires_in` y `refresh_expires_in` de la respuesta, no valores fijos.
- Limita intentos en `/exchange`.

Copia de `examples/tiktok-backend` de `rn-social-login`: si cambias una, cambia la otra.
