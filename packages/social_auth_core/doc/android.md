# Android

Mínimo: Android 7.0 (API 24).

## Esquema del redirect

En `android/app/build.gradle.kts`, dentro de `defaultConfig`:

```kotlin
manifestPlaceholders["authCoreRedirectScheme"] = "miapp"
```

El plugin registra una actividad que recibe `miapp://…`. Sin esa línea la compilación falla con "Manifest merger failed", porque el placeholder no tiene valor.

## App Links (https)

Para usar un redirect `https://` verificado, agrega en el `AndroidManifest.xml` de tu app otro `intent-filter` (con `android:autoVerify="true"`) a la actividad `dev.franciscodlx.social_auth_core_android.AuthRedirectActivity` y publica `assetlinks.json` en tu dominio. Este camino no está probado en dispositivo.

## Cómo funciona

- El inicio de sesión se abre en una Custom Tab del navegador predeterminado; si no hay ninguno compatible, en el navegador que maneje `https`.
- Al volver el redirect, la pestaña se cierra sola. Si el usuario la cierra antes, el resultado es `CANCELLED`.
- `prefersEphemeralSession` usa una Custom Tab efímera cuando el navegador la soporta; si no, se ignora.

## Probar contra un servidor local

El emulador llega a tu máquina por `10.0.2.2`. El núcleo solo acepta `http` hacia `localhost`, `127.0.0.1` y `10.0.2.2`.
