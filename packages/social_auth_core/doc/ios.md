# iOS

Mínimo: iOS 15.

No hace falta tocar `Info.plist`: `ASWebAuthenticationSession` intercepta el esquema del redirect (`miapp://callback`) sin registrarlo.

## Universal Links (https)

Un redirect `https://` requiere iOS 17.4 o posterior y el dominio asociado a la app (Associated Domains). En versiones anteriores el resultado es `NOT_SUPPORTED`. Este camino no está probado en dispositivo.

## Cómo funciona

- iOS muestra un aviso ("… quiere usar … para iniciar sesión") antes de abrir el navegador, salvo con `prefersEphemeralSession: true`.
- Con `prefersEphemeralSession: true` la sesión no comparte cookies con Safari: el usuario siempre tiene que iniciar sesión.
- Si el usuario cierra la hoja, el resultado es `CANCELLED`.

## Swift Package Manager y CocoaPods

El plugin incluye `Package.swift` y `podspec`. Flutter usa Swift Package Manager cuando está activado en el proyecto y CocoaPods en caso contrario. La app de ejemplo compila con Swift Package Manager; la ruta de CocoaPods no se ha probado.
