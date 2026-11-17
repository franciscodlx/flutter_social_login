# Backend de ejemplo para Twitch

Servidor Node sin dependencias que hace las dos cosas que Twitch no permite hacer desde la app:

| Ruta                         | Qué hace                                                                                                               |
| ---------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `GET /auth/twitch/callback`  | Recibe el redirect https de Twitch y reenvía `code` y `state` a la app (`APP_CALLBACK`)                                |
| `POST /auth/twitch/exchange` | Cambia el `code` por tokens con el `client_secret`, verifica la firma y el `nonce` del `id_token` y devuelve el perfil |

## Con el proveedor local

Desde la raíz del repo:

```sh
node tools/mock_idp/server.mjs
node tools/twitch_backend/server.mjs   # puerto 4300
```

## Con Twitch real

1. Registra la aplicación en <https://dev.twitch.tv/console/apps> (tipo de cliente Confidential) y genera un Client Secret.
2. Expón este servidor por https (Cloudflare Tunnel, ngrok).
3. En "OAuth Redirect URLs" registra `<PUBLIC_URL>/auth/twitch/callback`.
4. Copia `.env.example` a `.env`, complétalo y arranca con `node --env-file=.env server.mjs`.
5. Corre el ejemplo con tus valores:

   ```sh
   cd packages/social_auth_twitch/example
   flutter run --dart-define=TWITCH_CLIENT_ID=<client id> --dart-define=BACKEND_URL=<PUBLIC_URL>
   ```

El `.env` está en `.gitignore`: el secret nunca se sube ni viaja a la app.

## Qué cambiar en un backend real

- Devuelve tu propia sesión (cookie o JWT tuyo), no el perfil tal cual.
- Guarda el access token de Twitch en el servidor si lo necesitas; no lo mandes a la app.
- Twitch pide validar el access token al arrancar y cada hora (`GET https://id.twitch.tv/oauth2/validate`) si lo sigues usando.
- Limita intentos en `/exchange`.

Copia de `examples/twitch-backend` de `rn-social-login`: si cambias una, cambia la otra.
