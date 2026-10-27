# Server Flow 2D — Contexto del proyecto

> Documento vivo del equipo NEXUS CODE. Resume qué es el juego, las decisiones tomadas y cómo está construido. Si cambias algo de lo que aquí se describe, actualiza este archivo en el mismo PR.

## 1. El juego
- **Nombre de trabajo:** Proyecto Nexus: Server Flow 2D. Sector asignado: Empresa de Software y Tecnología.
- **Género:** simulación de gestión (tycoon 2D) con enfoque educativo: arquitectura cliente-servidor, cuellos de botella, concurrencia, latencia, almacenamiento, caché, balanceo de carga y seguridad.
- **Premisa:** el jugador es el SysAdmin de una startup (por defecto "NexusSoft") y debe mantener los servicios en pie mientras la empresa crece.
- **Público:** estudiantes de 15 a 26 años de informática/TI; secundario: fans de simuladores de gestión.
- **Plataformas:** Windows y Android (horizontal). Motor: Godot 4.6.
- **Referentes:** Game Dev Tycoon (solo como referencia de estilo del cuarto isométrico, sin copiar recursos), Startup Company, Mini Metro, TIS-100 / Human Resource Machine.

## 2. Estructura y progresión
| Etapa | Cuarto | Meta de usuarios | Se desbloquea |
|---|---|---|---|
| 1 · Startup | Garage | 1,000 | Mejoras de RAM, CPU, red, disco y respaldo |
| 2 · Scale-up | Oficina | 10,000 | 2.º servidor + Load Balancer, caché, **tienda de decoración** |
| 3 · Enterprise | Data center | 100,000 | Firewall, ataques DDoS; catálogo ampliado con **referencias personales del equipo** |

- 5 oleadas por etapa. Siempre se juegan las 5; la etapa se decide al terminar la quinta.
- **Quiebra (game over):** solo cuando el SLA llega a 0. **Meta no alcanzada:** termina la etapa con SLA > 0 pero sin la meta → "Repetir etapa" (vuelve a la oleada 1 con las monedas y mejoras del inicio de la etapa).
- Al pasar a Scale-up y a Enterprise hay una **ronda de inversión** (+1,500 y +5,000 monedas) que anuncia la CEO en un diálogo.
- **Post-mortem** al final de cada oleada: explica la causa principal de los fallos (cpu, ram, net, db, disk, ddos) como lección corta. Es el corazón educativo del juego.
- **Balance de la etapa 1** (detalle en `docs/balance.md`): sin compras se quiebra en la oleada 2; comprando lo más barato se quiebra en la 3; comprando el cuello de botella se llega al ~126 % de la meta al terminar la oleada 4. La dificultad debe venir de los servidores, no de la meta.

## 3. Personajes
- **Avatar del jugador:** se elige al iniciar ("Elige tu personaje", paso 1 de 3) entre **Alex** (sudadera azul) y **Alexa** (sudadera rosa, coleta alta). Luego el jugador escribe el nombre del avatar (paso 2) y el de la empresa (paso 3). Los textos se adaptan al género del avatar (bienvenido/bienvenida).
- **Briseida:** CEO de la empresa (antes se llamaba Valeria; ya no se usa ese nombre). Anuncia metas, eventos y rondas de inversión.
- **BYTE:** asistente de monitoreo/tutorial: da pistas y avisa cuando un recurso pasa de 85 %.
- **Phantom:** grupo de atacantes sin rostro (DDoS de la etapa 3).

## 4. Flujo del juego
Menú de título (Continuar deshabilitado si no hay partida) → Nueva partida → carga → elegir personaje → nombre del avatar → nombre de la empresa → cuarto de la etapa.
- En el cuarto: clic en la PC → zoom de cámara → **dashboard** (donde se juega). "← Cuarto" regresa sin pausar la simulación; el cuarto refleja el estado (rack rojo, avatar estresado).
- **Pincel** (HUD del cuarto): personalizar colores en vivo. **Engranaje** (abajo a la derecha): música, sonido, regresar, salir (pausa el juego).
- Colores por defecto de una partida nueva: paredes `blanco_hueso`, piso `concreto_calido` (garage), puerta `madera_natural`, mesa `roble`.

## 5. Dashboard
HUD (empresa · etapa, oleada, monedas, usuarios/meta, SLA) · monitor de tráfico (Clientes → [Firewall] → [Load Balancer] → Servidores → BD, paquetes verde/amarillo/rojo/morado) · consola de mejoras (botón del cuello de botella resaltado; pulsación larga o "i" abre la ficha con el concepto que enseña). Tráfico mostrado ×100 (`display_scale`). Simulación con paso fijo de 0.1 s y semilla configurable; modelo descrito en `scripts/autoload/simulation.gd` y `docs/balance.md`.

## 6. Sistema de arte (importante)
- Todo el arte de cuartos, objetos y personajes es **3D low-poly hecho en Blender por script y renderizado a 2D** con cámara ortográfica isométrica 2:1 (elevación 30°, giro 45°). Fuente en `source_art/blender/` (los `.blend` van por Git LFS).
- **Tile de 1 m = 128×64 px a 1x.** Todo se renderiza a **2x** y el nodo raíz de cada cuarto va a escala 0.5.
- **Capas:** cada cuarto se divide en capas (piso, pared izquierda, pared derecha, puerta, racks, mesa, avatar…) renderizadas al mismo lienzo y **recortadas a su contenido**. Su posición está en el JSON del cuarto, con offsets **múltiplos de 8 px** (evita bordes borrosos por mipmaps). Las sombras de los objetos fijos van horneadas en el piso.
- **Proyección mundo→píxel** en el JSON de cada cuarto: `pixel = origen + x·ex + y·ey + z·ez` (lienzo 2x). La cámara mira desde +x/−y, así que el `y_sort` de Godot ordena bien usando el centro de la huella en el piso.
- **Personalización:** paredes (10 colores, cada pared por separado), puerta (6), mesa (3); el **piso es propio de cada cuarto** (garage: 3 concretos; oficina: laminado claro, laminado nogal, alfombra gris). Paleta en `data/customization/`.
- **Oficina:** reutiliza los sprites del garage para puerta, mesa, racks y avatar sumando un desplazamiento `(dx, dy)` definido en su JSON.
- Estilo: colores planos, sombreado suave, sin contorno (el contorno está "en veremos"). Paleta de interfaz oscura tipo panel de monitoreo (#0b111c, acento #5aa9ff, verde #3ddc84, amarillo #f5c542, rojo #ff4d5e).

## 7. Tienda y decoración (desde la etapa 2)
- **Solo estética** (no afecta la simulación). Se abre **solo entre oleadas** (HUD del cuarto o post-mortem). En la etapa 1 se ve bloqueada.
- **Colocación libre** en una cuadrícula de 0.5 m, **con giro** (cada objeto tiene 2 orientaciones renderizadas; los de pared cambian de muro al girar). Huella verde/roja; en celular se confirma con "✓ Colocar". Los objetos colocados se pueden mover, girar, guardar en el inventario o vender (50 %).
- Catálogo inicial (12): planta, lámpara de pie, sillón, mesita con cafetera, librero, tapete (va debajo, admite objetos encima), máquina de snacks, consola de videojuegos, acuario, trofeo Scale-up (gratis al completar la etapa 2), cuadro (pared) y letrero de neón con el **nombre de la empresa** del jugador (pared). Datos en `data/decor/catalogo.json`.
- En la etapa 3 se agregan objetos inspirados en referencias personales del equipo (diseños propios, sin copiar logos ni personajes con derechos).
- **Ancla de los sprites:** el `ancla` de cada orientación en `catalogo.json` es el píxel del punto (0,0,0) del objeto, que es la **esquina mínima de su huella** (no el centro). El `Node2D` de cada objeto va en `world_to_canvas` del centro de la huella (para el `y_sort`) y su `Sprite2D` en `proj(esquina mínima) − proj(centro) − ancla`.
- **Muros con altura:** los objetos de pared (cuadro z 1.25–1.95 m, neón z 1.95–2.45 m, en `altura_m` del catálogo) ocupan en el muro su tramo × su altura. Las zonas prohibidas (`tramos_prohibidos_pared` en `data/rooms/oficina.json`) también tienen tramo y altura, y solo chocan si se enciman en los dos:
  - pared derecha: ventanas x 4.0–5.9 y 6.5–8.4 (z 1.0–2.5); racks x 0.8–2.5 (z 0–2.05);
  - pared izquierda: puerta y 4.3–5.5 (z 0–2.15); pizarrón y 6.2–8.6 (z 1.25–2.55); monitor del escritorio y 1.1–3.5 (z 0.75–1.6).
  Por eso el neón cabe sobre el escritorio. Dos objetos del mismo muro siguen la misma regla (un neón puede ir encima de un cuadro).

## 8. Estado (actualiza esta sección en cada PR grande)
- **v0.4.0 (en `main`, tag `v0.4.0`):** todo lo de v0.3.1 (garage personalizable, dashboard jugable con 3 etapas, ajustes, balance de la etapa 1, exportación Android/Windows, capas recortadas) más:
  - elegir personaje (Alex/Alexa), textos con género y CEO Briseida (PR #10);
  - oficina de Scale-up con piso propio y un rack por servidor; mientras no exista el data center, la etapa 3 usa la oficina como cuarto temporal (PR #11);
  - tienda y decoración con colocación libre, muros con zonas prohibidas con altura y letrero de neón con el nombre de la empresa (PR #11);
  - `TouchScrollContainer` para las listas táctiles (Tienda, Inventario, pincel): se arrastran con el dedo también sobre los botones, sin comprar por accidente, y con la rueda en PC;
  - partida alterna para pruebas y mediciones (`--save-path`, `SERVERFLOW_SAVE_PATH` o `user://save_path_override.txt` en Android debug).
- **Pendiente:** data center (etapa 3) y su catálogo personal, balance fino de etapas 2 y 3, audio (los buses Music/SFX ya existen), retratos de Briseida y BYTE.

## 9. Cómo trabajar
1. `git checkout develop && git pull` → crea `feature/<tu-tarea>`.
2. Trabaja, corre las pruebas, abre PR hacia `develop` y pide revisión al equipo.
3. Said integra a `main` y publica versiones con tag (`v0.x.y`) y Release con los builds de prueba.
