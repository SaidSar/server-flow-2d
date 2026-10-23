class_name SimulationConfig
extends Resource
## Constantes del modelo de simulación. El balance se ajusta aquí, no en el código.

@export_group("Presentación")
## El tráfico que ve el jugador (req/s, peticiones) se multiplica por esto para que se sienta real.
## La simulación no cambia; los usuarios atendidos tampoco se escalan.
@export var display_scale := 100.0

@export_group("Paso de simulación")
@export var step_seconds := 0.1
## Multiplicador de velocidad con F10 (solo en depuración).
@export var debug_speed := 8.0
## Tráfico extra (×) con F9 (solo en depuración).
@export var debug_overload_multiplier := 2.0
## Variación aleatoria del tráfico en cada paso (0.05 = ±5 %).
@export_range(0.0, 0.5) var traffic_noise := 0.05

@export_group("Infraestructura inicial (el garage)")
## Peticiones por segundo que procesa la CPU de un servidor.
@export var start_cpu_cap := 4.2
## Peticiones simultáneas que caben en la RAM.
@export var start_ram_slots := 7.0
## Peticiones por segundo que deja pasar la red.
@export var start_net_cap := 2.333
## Consultas por segundo que resuelve la base de datos.
@export var start_iops := 3.5
@export var start_disk_gb_cap := 10.0
@export var start_disk_gb_used := 6.0
@export var start_cache_hit := 0.0
@export var start_coins := 100

@export_group("Modelo")
## Tiempo que una petición ocupa memoria en el servidor (s).
@export var service_time_s := 2.0
## Fracción del tráfico legítimo que son lecturas; el resto son escrituras.
@export_range(0.0, 1.0) var read_ratio := 0.7
@export var base_latency_ms := 35.0
## La latencia se calcula con u ≤ este tope para no dividir entre cero.
@export var max_latency_utilization := 0.95
@export var max_cache_hit := 0.9

@export_group("Umbrales")
## Las barras pasan a amarillo arriba de este valor.
@export var warning_utilization := 0.65
## Cuello de botella: barras en rojo, rack rojo y Alex estresado.
@export var saturation_utilization := 0.85
## Debajo de esto la respuesta es rápida (verde); arriba, lenta (amarillo).
@export var fast_latency_ms := 200.0
## Desde aquí la petición se considera timeout (rojo).
@export var timeout_latency_ms := 800.0
## Fracción malicioso/total arriba de la cual el cuello de botella se atribuye al DDoS.
@export var ddos_blame_ratio := 0.3

@export_group("SLA")
@export var start_sla := 90.0
## Qué tan rápido sube o baja el SLA: sla += (éxito − meta) × k × dt.
@export var sla_k := 8.0

@export_group("Seguridad y respaldos")
@export_range(0.0, 1.0) var firewall_block_ratio := 0.85
@export var firewall_latency_ms := 15.0
@export_range(0.0, 1.0) var backup_free_ratio := 0.4
@export var backup_cooldown_s := 20.0

@export_group("Estrellas de la etapa")
## 1 estrella por completar; +1 por cada umbral alcanzado.
@export var stars_sla_good := 80.0
@export var stars_sla_great := 95.0
@export var stars_latency_ms := 200.0
