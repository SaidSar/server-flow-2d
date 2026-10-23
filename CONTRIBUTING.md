# Cómo contribuir

## Ramas

1. Parte siempre de `develop` actualizado: `git switch develop && git pull`.
2. Crea tu rama: `git switch -c feature/<nombre-corto>`.
3. Haz commits pequeños y descriptivos.
4. Sube tu rama y abre un Pull Request hacia `develop`. Pide revisión a otra persona del equipo.
5. `develop` se integra a `main` por PR cuando está estable.

Nunca hagas commit directo en `main`.

## Formato de commits

```
<tipo>: <descripción breve en minúsculas>
```

| Tipo | Úsalo para |
|---|---|
| `feat:` | Funcionalidad nueva (escenas, mecánicas, UI). |
| `fix:` | Corrección de errores. |
| `art:` | Arte, audio, fuentes o archivos de Blender. |
| `docs:` | Documentación (README, `docs/`, comentarios). |
| `refactor:` | Cambios de código que no alteran el comportamiento. |

Ejemplos:

```
feat: agrega barra de SLA al HUD
fix: el botón continuar no se habilitaba tras guardar
art: nuevos colores de puerta para el garage
docs: explica el orden de capas del cuarto
refactor: mueve rutas de escenas a paths.gd
```

## Antes de abrir un PR

- El proyecto abre en Godot 4.6 sin errores ni warnings en la consola.
- Todo el GDScript nuevo usa tipado estático.
- Los textos visibles están en español; código, archivos y nodos en inglés.
- Si agregas arte del cuarto, respeta el lienzo 2x de 1592×1318 y el nombre `<capa>/<id>.png`.
- Archivos `.blend`, `.psd`, audio y fuentes deben quedar en Git LFS (revisa con `git lfs ls-files`).
