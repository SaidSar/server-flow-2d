# Server Flow 2D

> Título de trabajo. Videojuego educativo de infraestructura web — **NEXUS CODE**, UAdeO.

Simulador *tycoon* 2D en el que eres el **SysAdmin** de una startup y tu trabajo es mantener sus servidores en pie mientras la empresa crece.

- **Vista principal:** un cuarto isométrico con arte pre-renderizado en Blender. Al hacer clic en la PC, la cámara hace zoom al monitor y entras al **panel de control** (dashboard), donde se juega.
- **Etapas:** Startup (garage) → Scale-up (oficina) → Enterprise (data center), con 5 oleadas cada una. Por ahora solo existe el garage.
- **Plataformas:** Windows y Android, en horizontal.

## Equipo NEXUS CODE

- Jesús Cervantes López
- Lucio Adrián Martínez Pérez
- Said Eduardo Sarmiento Santillanes
- Carlos David Ponce Gamboa

## Cómo abrir el proyecto

1. Instala **Godot 4.6** (versión estándar, no .NET) y **Git LFS** (`git lfs install`).
2. Clona el repo: `git clone https://github.com/SaidSar/server-flow-2d.git` (LFS descarga los `.blend` y las fuentes).
3. En Godot: *Importar* → selecciona `project.godot`. La primera importación de texturas tarda un poco.
4. Ejecuta con **F5**. La escena principal es `scenes/main/main.tscn`.

Flujo para probar: *Nueva partida* → nombre del avatar → nombre de la empresa → garage → botón de pincel (personalizar) → clic en el monitor de la PC → dashboard → *Volver al cuarto*.

**Atajo de depuración:** en builds de depuración, **F9** fuerza una sobrecarga del servidor. Así puedes ver el rack saturado y a Alex estresado sin esperar a que suba la carga.

La partida se guarda en `user://savegame.cfg`. En Windows está en `%APPDATA%\Godot\app_userdata\Server Flow 2D\`.

## Pruebas y herramientas

Desde la raíz del proyecto (`godot` = tu ejecutable de Godot 4.6):

```bash
# Prueba de humo: instancia todas las escenas y recorre el flujo completo sin ventana
godot --headless --path . -s res://tests/smoke_test.gd

# Regenera resources/customization/customization_catalog.tres después de editar paleta.json
godot --headless --path . -s res://scripts/tools/build_customization_catalog.gd
```

La prueba de humo usa su propio archivo de guardado; no toca tu partida.

> **Al exportar:** `customization.gd` lee `data/customization/paleta.json` en tiempo de ejecución. En cada preset de exportación agrega `data/*.json` en *Recursos → Filtros para exportar archivos que no son recursos*.

## Estructura

| Carpeta | Contenido |
|---|---|
| `assets/` | Arte, audio y fuentes que usa el juego. Las capas del cuarto viven en `assets/art/rooms/<cuarto>/<capa>/<id>.png`. |
| `data/` | Datos editables en JSON (p. ej. `data/customization/paleta.json`). |
| `resources/` | Recursos `.tres` (`UpgradeData`, `StageData`, catálogo de personalización). |
| `scenes/` | Escenas `.tscn` agrupadas por área (`main`, `ui`, `rooms`, `dashboard`, `characters`). |
| `scripts/` | GDScript. `autoload/` contiene los singletons globales. |
| `source_art/` | Archivos fuente de Blender y scripts. Godot la ignora (`.gdignore`). |
| `docs/` | Documentación del proyecto. |
| `tests/` | Pruebas automáticas (`smoke_test.gd`). |

### Autoloads

| Nombre | Responsabilidad |
|---|---|
| `GameState` | Datos de la partida en curso (avatar, empresa, colores, etapa, oleada, monedas, usuarios, SLA). |
| `SaveSystem` | Guarda y carga `user://savegame.cfg` con `ConfigFile`. |
| `Simulation` | Bucle de simulación (`tick`) con CPU, RAM, red, disco y SLA. |
| `Customization` | Catálogo de colores leído de `paleta.json` y resolución de texturas. |
| `SceneRouter` | Cambios de escena y transiciones. Todas las rutas de escenas están en `scripts/paths.gd`. |

### Arte del cuarto

Todas las capas del cuarto están renderizadas sobre el **mismo lienzo a 2x (1592×1318)**. Se apilan en la misma posición, sin offsets, con `centered = false`, dentro de un nodo raíz con `scale = (0.5, 0.5)`. Orden de dibujo (de atrás hacia adelante): piso, pared_izq, pared_der, puerta, rack, mesa, alex, cajas.

`scenes/rooms/room_base.tscn` tiene esa pila de capas, la cámara, el HUD y el panel de personalización. Cada cuarto **hereda** de ella; `garage.tscn` asigna sus texturas, el área clicable del monitor (`PcArea`) y el punto de zoom (`MonitorFocus`), en coordenadas del lienzo 2x.

Las texturas se importan con mipmaps, y el filtro por defecto del proyecto es *Linear Mipmap*, para que el zoom de la cámara se vea suave.

## Convenciones

- **Código, archivos y nodos en inglés.** Archivos y carpetas en `snake_case`, `class_name` en `PascalCase`, nodos en `PascalCase`.
- **Textos visibles del juego en español.**
- GDScript con **tipado estático** en todo el código.
- Las escenas se comunican con **señales**, no con referencias directas entre ellas.
- Nada de rutas "mágicas" repetidas: las rutas viven en `scripts/paths.gd`.
- Botones de al menos **64 px de alto** (mouse y táctil).
- Renderer **Compatibility** (`gl_compatibility`).

## Flujo de ramas

- `main` — versión estable. Solo recibe merges desde `develop` por Pull Request.
- `develop` — integración. Aquí se juntan las features terminadas.
- `feature/<nombre>` — trabajo nuevo, siempre creado desde `develop` (p. ej. `feature/dashboard-graficas`).

```bash
git switch develop
git pull
git switch -c feature/mi-cambio
# ...commits...
git push -u origin feature/mi-cambio
# Abrir PR hacia develop
```

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) para el formato de commits.
