# Server Flow 2D

> Título de trabajo. Videojuego educativo de infraestructura web — **NEXUS CODE**, UAdeO.

Contexto y decisiones del proyecto: [docs/CONTEXTO.md](docs/CONTEXTO.md) · Reglas para Claude Code: [CLAUDE.md](CLAUDE.md)

Simulador *tycoon* 2D en el que eres el **SysAdmin** de una startup y tu trabajo es mantener sus servidores en pie mientras la empresa crece.

- **Vista principal:** un cuarto isométrico con arte pre-renderizado en Blender. Al hacer clic en la PC, la cámara hace zoom al monitor y entras al **panel de control** (dashboard), donde se juega.
- **Etapas:** Startup (garage) → Scale-up (oficina) → Enterprise (data center), con 5 oleadas cada una. Los tres cuartos existen; en el data center hay ataques DDoS que se frenan con el Firewall.
  - El HUD (cuarto y dashboard) siempre muestra "{empresa} · {etapa}". Si la etapa todavía no tiene su cuarto (`StageData.room_ready = false`), se usa el último cuarto listo de una etapa anterior y el HUD lo indica ("Cuarto temporal: oficina").
- **Tienda de decoración** (solo estética, desde Scale-up y solo entre oleadas): botón "Tienda" del cuarto o del post-mortem. Se compra, se coloca en una cuadrícula de 0.5 m (huella verde si cabe, roja si choca), se gira, se guarda en el inventario o se vende al 50 %. En PC se coloca con clic (R gira, Esc cancela); en el celular se toca para mover y se confirma con "Colocar".
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

Flujo para probar: *Nueva partida* → elegir personaje (Alex o Alexa) → nombre del avatar → nombre de la empresa → garage → botón de pincel (personalizar) → clic en el monitor de la PC → dashboard (empieza la oleada 1) → compra mejoras en la consola → post-mortem → *Siguiente oleada* → *← Cuarto*.

**Atajos de depuración** (solo en builds de depuración):
- **F9:** fuerza una sobrecarga (×2 tráfico), para ver el rack saturado, al avatar estresado y los paquetes rojos.
- **F10:** acelera la simulación ×8, para llegar rápido al post-mortem, al game over o a la victoria.

## Dashboard

El monitor de la PC es donde se juega:

- **Monitor de tráfico:** Clientes → [Firewall] → [Load Balancer] → Servidores Web → Base de datos, con barras de utilización y paquetes de colores.
  - Verde: 200 OK. Amarillo: latencia alta. Rojo: timeout o error 500. Morado: DDoS.
  - El Load Balancer aparece con 2 o más servidores, y el Firewall cuando se instala.
- **Consola de administración:** una mejora por cada `UpgradeData`. Se resalta en rojo la que arregla el cuello de botella actual.
- **Oleadas:** son 5 por etapa. Entre oleadas aparece el post-mortem con la causa principal y su explicación educativa.
- **Fin de etapa:** siempre se juegan las 5 oleadas y la etapa se decide al terminar la quinta.
  - **Victoria:** se alcanzó la meta de usuarios. Muestra estrellas y Briseida (CEO), con su retrato, anuncia la ronda de inversión.
  - **Meta no alcanzada:** no es quiebra; "Repetir etapa" vuelve a la oleada 1 con los ahorros con que empezó la etapa.
- **Quiebra (game over):** solo si el SLA llega a 0. Se puede reintentar la oleada.
- **Ficha de cada mejora:** se abre al mantenerla presionada (0.4 s) o con su botón "i". En PC también aparece como tooltip. Muestra el efecto, el nivel, el costo y qué concepto enseña.
- **BYTE:** el asistente da el tutorial y avisa la primera vez que un recurso pasa del 85 %.
- **Tráfico en pantalla:** se multiplica por `display_scale` (×100) para que los números se sientan reales.

### Ajustes

El engranaje de la esquina inferior derecha está en el cuarto y en el dashboard (escena reutilizable `scenes/ui/settings_button.tscn`). Abre el panel de Ajustes y **pausa el juego** mientras está abierto:
- **Música y Sonido:** volumen de los buses `Music` y `SFX` de `default_bus_layout.tres`, con botón de silencio.
- **Regresar:** también con Esc o con el botón "atrás" de Android.
- **Salir:** pide confirmación, guarda la partida y vuelve al título.

Los ajustes se guardan en `user://settings.cfg` (autoload `Settings`), aparte de la partida.

La simulación (`Simulation`) sigue corriendo aunque vuelvas al garage. La vista solo escucha sus señales. El modelo y los números de balance están en [docs/balance.md](docs/balance.md).

La partida se guarda en `user://savegame.cfg`. En Windows está en `%APPDATA%\Godot\app_userdata\Server Flow 2D\`.

## Pruebas y herramientas

Desde la raíz del proyecto (`godot` = tu ejecutable de Godot 4.6):

```bash
# Prueba de humo: instancia todas las escenas y recorre el flujo completo sin ventana
godot --headless --path . -s res://tests/smoke_test.gd -- --save-path=user://test_smoke.cfg

# Pruebas del modelo de simulación (semilla fija) + resumen de balance por oleada
godot --headless --path . -s res://tests/test_simulation.gd -- --save-path=user://test_simulation.cfg

# Pruebas de la tienda y la decoración (colocación, monedas, inventario, guardado)
godot --headless --path . -s res://tests/test_decor.gd -- --save-path=user://test_decor.cfg

# Pruebas del DDoS y del Firewall de la etapa 3 (semilla fija)
godot --headless --path . -s res://tests/test_ddos.gd -- --save-path=user://test_ddos.cfg

# Regenera resources/customization/customization_catalog.tres después de editar paleta.json
godot --headless --path . -s res://scripts/tools/build_customization_catalog.gd
```

**Partida alterna:** `SaveSystem` acepta otra ruta de guardado con `-- --save-path=<ruta>` o con la variable de entorno `SERVERFLOW_SAVE_PATH`. Las pruebas la exigen: sin ella terminan de inmediato sin tocar nada, y `smoke_test.gd` falla si se lee o escribe la partida real (`user://savegame.cfg`). Úsala también en mediciones y partidas de prueba. En Android la app no recibe argumentos (la plantilla de exportación ignora los del intent), así que en builds **debug** se usa el archivo `user://save_path_override.txt` con la ruta alterna:

```bash
adb shell "echo user://medicion.cfg | run-as com.nexuscode.serverflow2d sh -c 'cat > files/save_path_override.txt'"
```

Al terminar la medición, bórralo: `adb shell run-as com.nexuscode.serverflow2d rm files/save_path_override.txt`. En builds release ese archivo se ignora.

> **Al exportar:** `customization.gd` lee `data/customization/paleta.json` y `layer_offsets.json` en tiempo de ejecución. Los presets de `export_presets.cfg` ya incluyen `data/*.json`; si creas uno nuevo, agrégalo en *Recursos → Filtros para exportar archivos que no son recursos*.

## Exportar (debug)

`export_presets.cfg` tiene dos presets:
- **Android:** `com.nexuscode.serverflow2d`, solo `arm64-v8a`, sin Gradle.
- **Windows Desktop.**

Los archivos salen en `build/`, que no va al repo.

**Al publicar una versión, subir `version/name` y `version/code` en `export_presets.cfg`.** En Android, `version/code` siempre aumenta. En Windows, `file_version` y `product_version` llevan la misma versión con un `.0` al final (p. ej. `0.3.1.0`).

En el preset de Windows, `application/modify_resources` debe quedar activado (`true`): así el `.exe` muestra la versión, la empresa y el icono del juego en lugar de los de Godot. Se revisa en Propiedades → Detalles del `.exe`.

```bash
godot --headless --path . --export-debug "Android" build/android/server-flow-2d-debug.apk
godot --headless --path . --export-debug "Windows Desktop" build/windows/ServerFlow2D.exe
adb install -r build/android/server-flow-2d-debug.apk
```

**Requisitos:**
- Las plantillas de exportación de tu versión exacta de Godot.
- El SDK de Android.
- Un JDK: Godot recomienda el 17; sin Gradle también funciona el 21 de Android Studio.
- Las rutas `export/android/*` configuradas en *Configuración del editor*.

**Notas:**
- **Godot de Steam:** guarda la configuración, las plantillas y la keystore de depuración en `…/steamapps/common/Godot Engine/editor_data/`, no en `%APPDATA%\Godot`.
- **Keystores:** nunca van al repo.
- **Exportar y adb:** exportar a Android cierra el servidor de `adb`; vuelve a abrir `adb logcat` después de exportar.
- **Rendimiento en el celular:** en builds de depuración, **F3** o un **toque de tres dedos** muestran FPS y memoria.

## Estructura

| Carpeta | Contenido |
|---|---|
| `assets/` | Arte, audio y fuentes que usa el juego. Las capas del cuarto viven en `assets/art/rooms/<cuarto>/<capa>/<id>.png`. |
| `data/` | Datos editables en JSON: `customization/` (paleta y offsets del garage), `rooms/<cuarto>.json` (lienzo, offsets, proyección, cuadrícula, zonas ocupadas, sprites reutilizados, paleta de piso) y `decor/catalogo.json`. |
| `resources/` | Recursos `.tres` (`UpgradeData`, `StageData`, catálogo de personalización). |
| `scenes/` | Escenas `.tscn` agrupadas por área (`main`, `ui`, `rooms`, `dashboard`, `characters`). |
| `scripts/` | GDScript. `autoload/` contiene los singletons globales. |
| `source_art/` | Archivos fuente de Blender y scripts. Godot la ignora (`.gdignore`). |
| `docs/` | Documentación del proyecto. |
| `tests/` | Pruebas automáticas (`smoke_test.gd`, `test_simulation.gd`, `test_decor.gd`, `test_ddos.gd`). |

### Autoloads

| Nombre | Responsabilidad |
|---|---|
| `Simulation` | Modelo de tráfico, infraestructura, economía, SLA, oleadas y mejoras, en pasos fijos de 0.1 s. Guarda un checkpoint al inicio de cada oleada. |
| `GameState` | Identidad de la partida (personaje, nombre del avatar, empresa y colores del cuarto). |
| `SaveSystem` | Guarda y carga `user://savegame.cfg` con `ConfigFile`: identidad + checkpoint de `Simulation`. Guarda solo al empezar y al terminar cada oleada, y al salir. |
| `Settings` | Volumen de música y efectos en `user://settings.cfg`. Se aplica a los buses de audio al iniciar. |
| `Customization` | Catálogo de colores leído de `paleta.json` y resolución de texturas. |
| `SceneRouter` | Cambios de escena y transiciones. Todas las rutas de escenas están en `scripts/paths.gd`. |

### Personajes

Cada personaje elegible es un `AvatarData` en `resources/avatars/<id>.tres`: nombre, descripción, color de su tarjeta, `gender` (`"m"` o `"f"`) y las rutas de sus poses (`teclea_a`, `teclea_b`, `estres`, `de_pie`) y del render de selección. Para agregar uno basta con crear otro `.tres` con su arte; la pantalla de selección lo muestra sola. Las poses sentadas son recortes del lienzo 2x y necesitan su entrada en `layer_offsets.json`.

`GameState.avatar_id` guarda la elección (las partidas viejas sin ella son de Alex).

### Textos con género

Los textos que se dirigen al jugador usan `TextUtil`, que elige la forma según el personaje:
- En código: `TextUtil.g("listo", "lista")`.
- En textos y datos (`.tres`): `TextUtil.format("¡Bienvenid{o|a}!")`. Los tutoriales de BYTE (`tutorial_text`) ya pasan por `format`.

Prefiere frases neutras. Antes de elegir personaje (título, carga) solo usa frases neutras.

### Cuartos y decoración

Cada cuarto lee `data/rooms/<id>.json` con `RoomData`. La oficina reutiliza la puerta, la mesa, los racks y el avatar del garage sumando a su offset el `(dx, dy)` de `reutilizados_del_garage`; tiene dos racks (uno por servidor web, cada uno se pone en rojo cuando su servidor se satura). Paredes, puerta y mesa comparten colores entre cuartos; el **piso es propio de cada cuarto** (`piso_garage`, `piso_oficina`).

`RoomProjection` convierte metros ↔ píxeles del lienzo 2x: `lienzo = origen + x·ex + y·ey + z·ez`. `DecorLayout` tiene las reglas de colocación (zonas ocupadas, tapete en capa inferior, muros con tramos prohibidos en `tramos_prohibidos_pared`), `DecorShop` las monedas e inventario y `DecorPlacer` el dibujo y la interacción. Cada objeto es un `Node2D` en el centro de su huella (para el y-sort) y su sprite va en `proj(esquina mínima) − proj(centro) − ancla`. Los objetos de piso, la mesa con el avatar y los racks se ordenan en `YSort` por el centro de su huella (`ysort_m`).

### Arte del cuarto

Todas las capas del cuarto están renderizadas sobre el **mismo lienzo a 2x (1592×1318)**, pero cada PNG está **recortado a su contenido** para ahorrar memoria y peso del APK. `data/customization/layer_offsets.json` guarda, por capa (`"piso/concreto_calido"`, `"alex/alex_teclea_a"`, …), su posición `x, y` en el lienzo y su tamaño `w, h`. Las capas van con `centered = false` dentro de un nodo raíz con `scale = (0.5, 0.5)`. Orden de dibujo (de atrás hacia adelante): piso, pared_izq, pared_der, puerta, rack, mesa, alex, cajas.

Para asignar la textura de una capa (color del pincel, rack, pose del avatar) usa siempre `Customization.apply_layer(sprite, texture)`: pone la textura y su posición juntas. La clave del offset sale de la ruta (`…/<carpeta>/<archivo>.png`). Si agregas o cambias arte recortado, actualiza también `layer_offsets.json`; `smoke_test.gd` revisa que cada variante tenga su offset y su tamaño correcto. Una capa sin recortar (lienzo completo) no necesita entrada y va en el origen.

Los recortes tienen origen y tamaño **alineados a múltiplos de 8 px** (con al menos 2 px de margen transparente). Si no, los mipmaps del recorte promedian bloques de píxeles distintos a los del lienzo completo y, al ver el cuarto alejado, los bordes se ven ligeramente diferentes.

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

**Regla:** si Git marca `project.godot` como modificado sin haber tocado ajustes, haz commit aparte con `chore: normalizar project.godot` antes de cambiar de rama. Es el editor de Godot reordenando el archivo.

Consulta [CONTRIBUTING.md](CONTRIBUTING.md) para el formato de commits.
