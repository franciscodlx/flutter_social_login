# Backend de ejemplo para LinkedIn

Servidor Node sin dependencias que hace las dos cosas que LinkedIn no permite hacer desde la app:

| Ruta                           | Qué hace                                                                                                  |
| ------------------------------ | --------------------------------------------------------------------------------------------------------- |
| `GET /auth/linkedin/callback`  | Recibe el redirect https de LinkedIn y reenvía `code` y `state` a la app (`APP_CALLBACK`)                 |
| `POST /auth/linkedin/exchange` | Cambia el `code` por tokens con el `client_secret`, verifica la firma del `id_token` y devuelve el perfil |

## Con el proveedor local

Desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/linkedin_backend/server.mjs
```

## Con LinkedIn real

1. Crea la app en <https://www.linkedin.com/developers/apps> y agrega el producto "Sign In with LinkedIn using OpenID Connect".
2. Expón este servidor por https (Cloudflare Tunnel, ngrok).
3. En Auth → "Authorized redirect URLs" registra `<PUBLIC_URL>/auth/linkedin/callback`.
4. Copia `.env.example` a `.env`, complétalo y arranca con `node --env-file=.env server.mjs`.
5. Corre el ejemplo con tus valores:

   ```sh
   cd packages/social_auth_linkedin/example
   flutter run --dart-define=LINKEDIN_CLIENT_ID=<client id> --dart-define=BACKEND_URL=<PUBLIC_URL>
   ```

El `.env` está en `.gitignore`: el secret nunca se sube ni viaja a la app.

## Qué cambiar en un backend real

- Devuelve tu propia sesión (cookie o JWT tuyo), no el perfil tal cual.
- Guarda el access token de LinkedIn en el servidor si lo necesitas; no lo mandes a la app.
- Limita intentos en `/exchange`.

Copia de `examples/linkedin-backend` de `rn-social-login`: si cambias una, cambia la otra.
