# Balance del dashboard

Todos los números viven en recursos `.tres`; el código no tiene constantes de balance.

| Qué | Dónde |
|---|---|
| Infraestructura inicial, umbrales, SLA, firewall, respaldos, estrellas | `resources/simulation/simulation_config.tres` (valores por defecto en `scripts/resources/simulation_config.gd`) |
| Meta, tráfico base, monedas, ronda de inversión | `resources/stages/<etapa>.tres` |
| Duración, rampa, picos y DDoS de cada oleada | `resources/waves/<etapa>_<n>.tres` |
| Costo, efecto y nivel máximo de cada mejora | `resources/upgrades/<id>.tres` |

Después de cambiar algo, corre `tests/test_simulation.gd`: imprime un resumen por oleada con una partida sin compras y otra con una estrategia simple. La estrategia compra la mejora más barata que arregla el recurso más cargado, y hace un respaldo cuando el disco pasa del 80 %.

## Modelo (resumen)

Cada paso dura 0.1 s:

- **Tráfico:** `λ = base_rps × multiplicador de la oleada` (rampa lineal + picos con forma de seno) ± 5 % de ruido.
- **Servidor:** `u_cpu = L / cpu_cap`, `u_net = L / net_cap`, `u_ram = L × 2 s / ram_slots` (concurrencia, Ley de Little).
- **BD:** `u_db = (lecturas × (1 − caché) + escrituras) / iops`, con 70 % lecturas y 30 % escrituras.
- **Latencia:** `35 ms / (1 − min(u, 0.95))` (+15 ms con firewall). Es verde debajo de 200 ms (u < 0.825) y amarilla desde ahí.
- **Fallos:** `(u − 1) / u` cuando u > 1, más las escrituras con el disco lleno (error 500).
- **SLA:** `sla += (éxito − 0.95) × 8 × dt`. Empieza en 90; con 0 es game over.

## Etapa 1 (Startup, garage)

- **Meta:** 1,000 usuarios atendidos.
- **Tráfico:** `base_rps` = 1.2 req/s.
- **Monedas:** 1 por petición rápida y 0.5 por petición lenta.
- **Inicio:** 100 monedas y 0.03 GB por escritura.

**Infraestructura inicial:** está calculada para que la oleada 1 empiece como el boceto del equipo: CPU 50 %, RAM 60 %, Red 90 %, Disco 60 %.

| Recurso | Valor | Carga al empezar (1.2 req/s) |
|---|---|---|
| CPU | 2.4 req/s | 50 % |
| RAM | 4 peticiones simultáneas | 60 % |
| Red | 1.333 req/s | 90 % (cuello de botella del tutorial) |
| BD | 2 consultas/s | 60 % |
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
- **RAM, CPU, Ancho de banda, Disco SSD y Ampliar disco:** +50 % por nivel (compuesto). El costo crece ×1.6 por nivel; los costos base son 30, 35, 25, 35 y 40.
- **Respaldo:** cuesta 15 monedas, libera el 40 % del disco y tiene 20 s de recarga.

**Resultado con semilla fija (`tests/test_simulation.gd`):**
- **Sin compras:** pierde en la oleada 2 (el SLA cae de 89.6 a 0, por la red).
- **Estrategia simple:** gana en la oleada 5 con 1,119/1,000 usuarios, SLA promedio 99.7 %, 163 ms y 4 estrellas. Al final de la oleada 4 lleva 722 usuarios, así que la meta solo se alcanza en la última oleada.

## Etapas 2 y 3 (balance preliminar)

Las dos se pueden ganar con la estrategia simple, pero todavía falta el balance fino.

| | Scale-up | Enterprise |
|---|---|---|
| Meta | 10,000 | 100,000 |
| `base_rps` | 24 | 180 |
| Monedas por petición | 1.0 | 0.5 |
| Ronda de inversión al llegar | 1,500 | 5,000 |
| Desbloquea | Optimizar caché, + Servidor web | Firewall |
| Resultado de la estrategia simple | Gana con 10,717 usuarios | Gana con 124,628 usuarios; parece fácil |

En Enterprise los DDoS van de 0.8× a 2.5× `base_rps` de tráfico malicioso.
