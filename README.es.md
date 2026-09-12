<p align="center">
  <img src="docs/open-guard-hero.png" alt="OpenGuard protege las asociaciones predeterminadas" width="100%">
</p>

<p align="center">
  <a href="README.md">简体中文</a> · <a href="README.en.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <strong>Español</strong>
</p>

# OpenGuard

OpenGuard es una utilidad ligera y nativa para la barra de menús de macOS. Mantiene cada extensión de archivo asignada a la aplicación que elijas y restaura la regla si otra aplicación cambia el controlador predeterminado.

## Por qué existe

Nació de una molestia muy concreta: después de asignar los archivos `.md` a Visual Studio Code, Xcode u otra aplicación podía apropiarse de nuevo de la asociación. “Abrir siempre con” de Finder la repara una vez, pero no evita el siguiente cambio.

OpenGuard mantiene la elección del usuario sin un servicio pesado, componentes privilegiados ni permisos de administrador.

## Ventajas

- 33 extensiones predefinidas agrupadas en texto y código fuente, documentos, imágenes, multimedia y archivos comprimidos.
- Una aplicación para todo un grupo, con excepciones por extensión.
- Añade grupos y reglas, ordénalos arrastrando, mueve reglas entre grupos y renombra grupos con el menú contextual. Al quitar un grupo, sus reglas pasan a la raíz.
- Búsqueda por nombre localizado, nombre original, Bundle ID o ruta.
- Restauración cada tres segundos y comprobación inmediata al reactivar el Mac o la aplicación.
- AppKit nativo sin dependencias de ejecución de terceros.
- Cinco idiomas: 简体中文, English, 日本語, 한국어 y Español.
- Compatible con macOS 10.13 o posterior, Intel y Apple Silicon.
- Sin permisos de administrador; el inicio de sesión usa un LaunchAgent de usuario.
- Comprobación asíncrona de GitHub Releases al iniciar y cada hora.

## Uso

1. Mueve `OpenGuard.app` a `/Applications`.
2. Usa los botones superiores para añadir grupos o reglas. Arrastra filas para ordenar o mover reglas entre grupos y la raíz.
3. Usa `…` en un grupo para elegir una aplicación común, o en una extensión para crear una excepción. Haz clic derecho para renombrar un grupo.
4. Si quieres, activa el inicio de sesión y mantén la restauración automática. La inicialización de grupos está dentro del menú “Ajustes” y pide confirmación.

## Funcionamiento y límite

OpenGuard consulta y actualiza los controladores mediante macOS Launch Services y los UTI. No intercepta cambios a nivel del núcleo; detecta la modificación y restaura rápidamente la aplicación elegida. Así sigue siendo ligero y no necesita privilegios.

## Actualizaciones

Comprueba de forma asíncrona la última versión de GitHub al arrancar y cada hora. Solo muestra una vez cada versión nueva durante una ejecución. Los errores de red, límites de API o la ausencia de versiones se omiten sin interrumpir la aplicación. Nunca descarga ni instala actualizaciones automáticamente.

## Compilación

Requiere macOS 10.13 o posterior y Xcode Command Line Tools.

```sh
make clean verify
```

La aplicación universal se genera en `build/OpenGuard.app`.

Para crear un DMG instalable mediante arrastre, un ZIP alternativo y las sumas SHA-256:

```sh
make clean package
```

## Privacidad

OpenGuard no incluye telemetría, publicidad ni seguimiento. No sube reglas, nombres de archivos, listas de archivos ni la lista de aplicaciones. Su única solicitud de red obtiene metadatos públicos de Releases mediante la API de GitHub.

## Arte

El icono y la imagen principal del README se crearon específicamente para OpenGuard con instrucciones de texto originales. No se usaron imágenes de referencia, recursos de stock, marcas de terceros ni logotipos de aplicaciones existentes. Consulta [ARTWORK.md](ARTWORK.md).

## Licencia

Código disponible bajo [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0). Se permite inspeccionar, modificar, hacer Fork y redistribuir con fines no comerciales. No se permite el uso comercial.
