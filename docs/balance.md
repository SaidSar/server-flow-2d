# Balance del dashboard

Todos los números viven en recursos `.tres`; el código no tiene constantes de balance.

| Qué | Dónde |
|---|---|
| Infraestructura inicial, umbrales, SLA, latencia del firewall, respaldos, estrellas, `display_scale` | `resources/simulation/simulation_config.tres` (valores por defecto en `scripts/resources/simulation_config.gd`) |
| Meta, tráfico base, monedas, ronda de inversión, DDoS y % que filtra el firewall, costo de las mejoras de la etapa (`upgrade_costs`) | `resources/stages/<etapa>.tres` |
| Duración, rampa y picos de tráfico legítimo de cada oleada | `resources/waves/<etapa>_<n>.tres` |
| Costo (si la etapa no lo define), efecto y nivel máximo de cada mejora | `resources/upgrades/<id>.tres` |

Después de cambiar algo, corre `tests/test_simulation.gd`. Juega la etapa 1 con 3 estrategias (siempre con la misma semilla) e imprime un resumen por oleada:

| Estrategia | Qué hace |
|---|---|
| Sin compras | No compra nada. |
| Buena | Compra la mejora más barata que arregla el recurso más cargado. Hace un respaldo cuando el disco pasa del 80 % y compra el firewall cuando hay DDoS. |
| Mediocre | Compra siempre la mejora más barata que alcance, sin mirar el cuello de botella. |

## Reglas de la etapa

- Siempre se juegan las 5 oleadas. La etapa se decide al **terminar la oleada 5**:
  - Con la meta de usuarios alcanzada, es victoria.
  - Sin la meta, aparece **"Meta no alcanzada"**. No es quiebra: "Repetir etapa" vuelve a la oleada 1 con las monedas y mejoras con que empezó la etapa.
- La **quiebra** (game over) ocurre solo cuando el SLA llega a 0. "Reintentar oleada" vuelve al inicio de esa oleada.
- Al ganar una etapa, Briseida (CEO) anuncia la **ronda de inversión**, y las monedas se entregan al aceptar el diálogo.

## Modelo (resumen)

Cada paso dura 0.1 s:

- **Tráfico:** `λ = base_rps × multiplicador de la oleada` (rampa lineal + picos con forma de seno) ± 5 % de ruido.
- **Servidor:** `u_cpu = L / cpu_cap`, `u_net = L / net_cap`, `u_ram = L × 2 s / ram_slots` (concurrencia, Ley de Little).
- **BD:** `u_db = (lecturas × (1 − caché) + escrituras) / iops`, con 70 % lecturas y 30 % escrituras.
- **DDoS (solo Enterprise):** `malicioso = base_rps × (ddos_background_rate + picos)`. Cada oleada tiene los picos que indica su posición en `ddos_spike_count`, de `ddos_spike_duration_s` con forma de seno y cima `ddos_spike_intensity`; se sortea en qué momento cae cada uno. Con el firewall encendido llega solo `100 % − firewall_filter_pct` de ese tráfico; lo que llega se suma a la carga `L` del servidor como si fuera legítimo, pero no cuenta para el SLA ni da monedas.
- **Latencia:** `35 ms / (1 − min(u, 0.95))` (+15 ms con firewall). Es verde debajo de 200 ms (u < 0.825) y amarilla desde ahí.
- **Fallos:** `(u − 1) / u` cuando u > 1, más las escrituras con el disco lleno (error 500).
- **SLA:** `sla += (éxito − 0.95) × 8 × dt`. Empieza en 90.
- **Lo que ve el jugador:** el tráfico (req/s, peticiones del post-mortem y de la victoria) se multiplica por `display_scale` = 100. Por ejemplo, 2.1 req/s de la simulación se muestran como "210 req/s". Los usuarios atendidos no se escalan.

## Etapa 1 (Startup, garage)

Todo está escalado ×1.75 respecto a la primera versión: el tráfico y la infraestructura inicial, y las monedas por petición entre 1.75. Los porcentajes, el tutorial y la economía siguen iguales; la diferencia es que se atienden 1.75 veces más usuarios.

- **Meta:** 1,000 usuarios atendidos.
- **Tráfico:** `base_rps` = 2.1 req/s, que se ven como 210 req/s.
- **Monedas:** 0.57 por petición rápida y la mitad por petición lenta.
- **Inicio:** 100 monedas y 0.017 GB por escritura.

**Infraestructura inicial:** la oleada 1 empieza como el boceto del equipo: CPU 50 %, RAM 60 %, Red 90 %, Disco 60 %.

| Recurso | Valor | Carga al empezar (2.1 req/s) |
|---|---|---|
| CPU | 4.2 req/s | 50 % |
| RAM | 7 peticiones simultáneas | 60 % |
| Red | 2.333 req/s | 90 % (cuello de botella del tutorial) |
| BD | 3.5 consultas/s | 60 % |
| Disco | 6 de 10 GB | 60 % |

**Oleadas:**

| Oleada | Duración | Rampa | Picos (inicio s, duración s, +multiplicador) |
|---|---|---|---|
| 1 (tutorial) | 60 s | 1.0 → 1.3 | — |
| 2 | 70 s | 1.4 → 1.9 | (35, 12, +0.6) |
| 3 | 75 s | 1.9 → 2.5 | (20, 10, +0.8), (55, 12, +1.0) |
| 4 | 80 s | 2.5 → 3.1 | (30, 15, +1.2) |
| 5 | 90 s | 3.0 → 3.8 | (20, 10, +1.0), (50, 10, +1.3), (75, 10, +1.5) |

**Mejoras de la etapa 1:**
- **RAM, CPU y Ancho de banda:** +50 % por nivel (compuesto), máximo nivel 10.
- **Disco SSD:** +50 % por nivel, máximo nivel 12.
- **Ampliar disco:** +50 % por nivel, máximo nivel 8.
- **Costos:** crecen ×1.6 por nivel. Los costos base son 30, 35, 25, 35 y 40 (en el orden de arriba).
- **Respaldo:** cuesta 15 monedas, libera el 40 % del disco y tiene 20 s de recarga.

### Resultados (semilla fija)

| Estrategia | Resultado |
|---|---|
| Sin compras | **Quiebra por SLA en la oleada 2** (la red: el SLA pasa de 89.6 a 0). |
| Buena | Al terminar la oleada 4 lleva **1,263 / 1,000 usuarios (126 %)**. Termina la oleada 5 con 1,959 usuarios, **SLA final 100**, SLA promedio 99.7 %, 163 ms y 4 estrellas. |
| Mediocre | **Quiebra por SLA en la oleada 3**, por la red. Se gasta las monedas en respaldos (15 monedas cada uno) y casi no compra ancho de banda: en la oleada 2 el SLA baja a 80.2 y en la 3 llega a 0. Nunca pierde "por meta". |

## Etapas 2 y 3 (balance preliminar)

No se cambiaron en esta ronda: solo se comprobó que la estrategia buena las sigue ganando. Su balance fino está pendiente.

| | Scale-up | Enterprise |
|---|---|---|
| Meta | 10,000 | 100,000 |
| `base_rps` | 24 (2,400 req/s en pantalla) | 180 (18,000 req/s en pantalla) |
| Monedas por petición | 1.0 | 0.5 |
| Ronda de inversión al llegar | 1,500 | 5,000 |
| Desbloquea | Optimizar caché, + Servidor web | Firewall |
| Resultado de la estrategia buena | Gana con 10,718 usuarios | Gana con 124,629 usuarios (124.6 % de la meta; 84 % al terminar la oleada 4) |

En Enterprise (`enterprise.tres`): fondo de 0.1× `base_rps`, picos de 20 s con cima de 1.5× `base_rps` (1, 1, 2, 3 y 3 por oleada), firewall que filtra el 70 % y cuesta 880 monedas. `tests/test_ddos.gd` comprueba que, con servidores al 45 % por el tráfico legítimo, un pico sin firewall baja el SLA (98.7 → 68.5 con la semilla de la prueba) y con firewall no lo baja.

### Por qué Enterprise sigue en 124.6 %

Con la estrategia buena no hay fallos: se atiende todo el tráfico de las 5 oleadas, así que **124.6 % es el techo** que da ese tráfico contra la meta. Bajar el % exige que fallen peticiones, y estas palancas casi no lo logran (la estrategia buena reacciona cada segundo y compra capacidad):

| Cambio probado (el resto igual) | % de la meta |
|---|---|
| Firewall 70 %, 880 monedas y 1–3 picos (actual) | 124.6 |
| Intensidad del pico 8× `base_rps` | 124.5 |
| Intensidad del pico 12× `base_rps` | 124.3 |
| Duración del pico 40 s, intensidad 12× | 124.5 |
| `coin_per_req` 0.02 (25 veces menos dinero) | 123.6 |

Para bajarlo hay que cambiar el techo: más meta o menos tráfico total. Ojo con la comparación: el ~126 % de la etapa 1 se mide **al terminar la oleada 4**; con esa misma medida Enterprise da 84 % y necesita la oleada 5 para ganar. Al final de la oleada 5 la etapa 1 llega a 196 %.
