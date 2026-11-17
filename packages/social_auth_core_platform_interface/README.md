# social_auth_core_platform_interface

Interfaz de plataforma de [`social_auth_core`](../social_auth_core). Define `SocialAuthCorePlatform` (abrir y cancelar la sesión del navegador del sistema) y `AuthException` con los códigos de error de la familia.

Solo la necesitas para escribir una implementación de plataforma nueva: extiende `SocialAuthCorePlatform` y asígnala en `SocialAuthCorePlatform.instance` desde tu `registerWith()`.
