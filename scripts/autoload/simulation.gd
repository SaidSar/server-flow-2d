extends Node
## Autoload "Simulation": modelo de tráfico, infraestructura, economía y SLA.
## No conoce la UI: las escenas escuchan sus señales y leen su estado.
## Avanza en pasos fijos (config.step_seconds) aunque el jugador esté en el garage.
## En depuración: F9 fuerza una sobrecarga y F10 acelera ×8.
## DDoS (solo en las etapas que lo definen, hoy Enterprise): tráfico malicioso de fondo constante más
## 1 a ddos_spike_count picos por oleada. El Firewall encendido descarta firewall_filter_pct de todo
## ese tráfico; lo que pasa se suma a la carga de CPU, RAM y red de los servidores.

## Un paso de simulación terminó.
signal tick(snapshot: SimSnapshot)
## Cambió el recurso cuello de botella (&"" = ya no hay) o el nodo donde está.
signal bottleneck_changed(resource: StringName, node: StringName)
## Algo pasó (o dejó de pasar) el umbral de saturación. Lo usa el garage (rack rojo, avatar estresado).
signal saturation_changed(is_saturated: bool)
signal phase_changed(phase: Phase)
signal wave_started(wave_number: int)
## La oleada terminó y la empresa sigue en pie (el post-mortem se muestra con este reporte).
signal wave_finished(report: WaveReport)
signal stage_completed(report: WaveReport)
## Terminaron las oleadas con SLA > 0 pero sin llegar a la meta (no es quiebra).
signal stage_failed(report: WaveReport)
## El SLA llegó a 0: la empresa quebró.
signal game_over(report: WaveReport)
## Cambió la infraestructura o las monedas por una compra, un respaldo o el firewall.
signal infrastructure_changed
## Se creó un checkpoint (inicio o fin de oleada): es momento de guardar.
signal checkpoint_created

enum Phase {
	## Sin partida (menú de título).
	IDLE,
	## Hay partida; la oleada actual todavía no empieza.
	READY,
	RUNNING,
	## Terminó una oleada; esperando "Siguiente oleada".
	BETWEEN_WAVES,
	## SLA en 0.
	GAME_OVER,
	## Terminó la última oleada sin llegar a la meta; esperando "Repetir etapa".
	STAGE_FAILED,
}

## Tope de pasos por frame para que una caída de FPS no congele el juego.
const MAX_STEPS_PER_FRAME := 200
## Nodos donde puede estar el cuello de botella.
const NODE_WEB: StringName = &"web"
const NODE_DB: StringName = &"db"

var config: SimulationConfig
var stage: StageData
var wave: WaveData
var wave_number := 1
var phase: Phase = Phase.IDLE
var paused := false
## Velocidad elegida por el jugador (1× o 2×).
var speed := 1.0
var debug_fast := false
var overload_enabled := false

var servers: Array[ServerState] = []
var db := DbState.new()
var has_firewall := false
## Firewall encendido (el "firewall_activo" de la ficha). Al comprarlo se enciende solo.
var firewall_on := false
## Picos de ataque de la oleada en curso: (inicio s, duración s, intensidad en múltiplos de base_rps).
var ddos_spikes: Array[Vector3] = []
var sla := 90.0
var coins := 0
var users_served := 0
var upgrade_levels: Dictionary[StringName, int] = {}
var backup_cooldown := 0.0
var wave_time := 0.0
## Estadísticas de cada etapa completada: id → {stars, avg_sla, avg_latency_ms, users_served}.
var stage_stats: Dictionary[StringName, Dictionary] = {}

var last_snapshot := SimSnapshot.new()
## Reporte de la oleada en curso o de la última que terminó (para el post-mortem y el game over).
var report: WaveReport
## Etapa completada cuya victoria el jugador aún no ha visto (pudo terminar mientras estaba en el garage).
var pending_stage_report: WaveReport
## Ronda de inversión que se entrega cuando el jugador acepta la victoria (después del diálogo de Briseida).
var pending_investment := 0
var is_saturated := false
var bottleneck: StringName = &""
var bottleneck_node: StringName = &""

## Estado al inicio de la oleada actual. Es lo que se guarda y lo que restaura "Reintentar".
var _checkpoint: Dictionary = {}
## Estado al inicio de la etapa actual. Lo restaura "Repetir etapa".
var _stage_checkpoint: Dictionary = {}
## Fallos de toda la etapa por causa (para el consejo de "Meta no alcanzada").
var _stage_failures: Dictionary[StringName, float] = {}
var _upgrades: Dictionary[StringName, UpgradeData] = {}
## Costo base de cada mejora según la etapa que la desbloquea (StageData.upgrade_costs).
var _stage_costs: Dictionary[StringName, int] = {}
var _rng := RandomNumberGenerator.new()
var _accumulator := 0.0
var _coin_fraction := 0.0
var _served_fraction := 0.0
## Acumuladores de la etapa para el promedio de SLA y de latencia.
var _stage_sla_sum := 0.0
var _stage_time := 0.0
var _stage_latency_sum := 0.0
var _stage_requests := 0.0


func _ready() -> void:
	config = load(Paths.SIMULATION_CONFIG) as SimulationConfig
	_load_upgrades()
	_rng.randomize()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if phase != Phase.RUNNING or paused:
		return
	_accumulator += delta * get_effective_speed()
	var steps := 0
	while _accumulator >= config.step_seconds and phase == Phase.RUNNING and steps < MAX_STEPS_PER_FRAME:
		_accumulator -= config.step_seconds
		step()
		steps += 1
	if steps >= MAX_STEPS_PER_FRAME:
		_accumulator = 0.0


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not OS.is_debug_build() or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_F9:
		overload_enabled = not overload_enabled
		print("[Simulation] Sobrecarga de prueba: %s" % ("activada" if overload_enabled else "desactivada"))
	elif key.keycode == KEY_F10:
		debug_fast = not debug_fast
		print("[Simulation] Velocidad de depuración: %s" % ("×%d" % config.debug_speed if debug_fast else "normal"))


#region Sesión y oleadas

## Partida nueva: infraestructura del garage, etapa 1, oleada 1.
func new_game() -> void:
	upgrade_levels.clear()
	coins = config.start_coins
	db.disk_gb_used = config.start_disk_gb_used
	firewall_on = false
	stage_stats.clear()
	pending_stage_report = null
	pending_investment = 0
	_enter_stage(Paths.STAGE_ORDER[0])
	_set_phase(Phase.READY)
	_capture_stage_start()
	_create_checkpoint()


## Sale de la partida (menú de título).
func end_session() -> void:
	paused = false
	overload_enabled = false
	_set_phase(Phase.IDLE)
	_set_bottleneck(&"", &"")


func has_session() -> bool:
	return phase != Phase.IDLE


func start_wave() -> void:
	if phase != Phase.READY and phase != Phase.BETWEEN_WAVES:
		return
	wave = stage.get_wave(wave_number)
	wave_time = 0.0
	_accumulator = 0.0
	paused = false
	report = WaveReport.new()
	report.stage_id = stage.id
	report.wave_number = wave_number
	report.sla_start = sla
	report.stage_user_goal = stage.user_goal
	_schedule_ddos_spikes()
	# El checkpoint incluye lo que se compró entre oleadas.
	_create_checkpoint()
	_set_phase(Phase.RUNNING)
	wave_started.emit(wave_number)


## Restaura el inicio de la oleada actual (después de un game over).
func retry_wave() -> void:
	load_checkpoint(_checkpoint)
	start_wave()


## Vuelve al inicio de la oleada 1 de la etapa, con las monedas y mejoras con que empezó.
func repeat_stage() -> void:
	load_checkpoint(_stage_checkpoint)
	start_wave()


## El jugador ya vio la victoria (y el diálogo de la ronda de inversión): se entregan las monedas.
func acknowledge_stage_report() -> void:
	pending_stage_report = null
	if pending_investment <= 0:
		return
	coins += pending_investment
	pending_investment = 0
	_capture_stage_start()
	_create_checkpoint()
	infrastructure_changed.emit()


func set_paused(value: bool) -> void:
	paused = value


func set_speed(value: float) -> void:
	speed = value


func get_effective_speed() -> float:
	return speed * (config.debug_speed if debug_fast else 1.0)


func get_wave_count() -> int:
	return stage.get_wave_count() if stage != null else 0


func is_last_stage() -> bool:
	return _next_stage_id() == &""

#endregion


#region Paso de simulación

## Avanza un paso fijo. Lo llama _physics_process; las pruebas lo llaman directo.
func step() -> void:
	if phase != Phase.RUNNING:
		return
	var dt := config.step_seconds
	wave_time += dt
	backup_cooldown = maxf(backup_cooldown - dt, 0.0)

	# 1. Tráfico entrante
	var multiplier := wave.traffic_multiplier(wave_time)
	if overload_enabled:
		multiplier *= config.debug_overload_multiplier
	var noise := 1.0 + _rng.randf_range(-config.traffic_noise, config.traffic_noise)
	var legit_rps := stage.base_rps * multiplier * noise
	var incoming_malicious := stage.base_rps * ddos_multiplier(wave_time)

	# 2. Firewall
	var malicious_rps := incoming_malicious
	var extra_latency := 0.0
	if is_firewall_active():
		malicious_rps *= 1.0 - stage.firewall_filter_pct / 100.0
		extra_latency += config.firewall_latency_ms

	# 3–4. Reparto entre servidores (con Load Balancer) y utilización de cada uno
	var active := servers.size() if has_load_balancer() else 1
	for i in servers.size():
		var server := servers[i]
		if i < active:
			_load_server(server, legit_rps / active, malicious_rps / active)
		else:
			_load_server(server, 0.0, 0.0)
	var web := servers[0]

	# 5. Base de datos
	var reads := legit_rps * config.read_ratio
	var writes := legit_rps - reads
	db.u_db = (reads * (1.0 - db.cache_hit) + writes) / db.iops
	var disk_full := db.is_disk_full()
	db.disk_gb_used = minf(db.disk_gb_used + writes * dt * stage.gb_per_write, db.disk_gb_cap)

	# 6. Latencia
	var u_total := maxf(web.get_peak(), db.u_db)
	var latency := config.base_latency_ms / (1.0 - minf(u_total, config.max_latency_utilization)) + extra_latency

	# 7. Resultado de las peticiones legítimas
	var requests := legit_rps * dt
	var fail_rate := _fail_rate(u_total)
	var timeouts := requests * fail_rate
	var errors_500 := writes * dt * (1.0 - fail_rate) if disk_full else 0.0
	var successes := requests - timeouts - errors_500
	if latency >= config.timeout_latency_ms:
		timeouts += successes
		successes = 0.0
	var green := successes if latency < config.fast_latency_ms else 0.0
	var yellow := successes - green

	# 10. Causas de los fallos: lo que agregó el DDoS se le cobra al DDoS; el resto, al recurso más cargado
	var legit_only_u := maxf(_peak_utilization(web, legit_rps / active), db.u_db)
	var ddos_failures := 0.0
	if fail_rate > 0.0:
		ddos_failures = timeouts * clampf((fail_rate - _fail_rate(legit_only_u)) / fail_rate, 0.0, 1.0)
	_add_failures(&"ddos", ddos_failures)
	_add_failures(_overload_cause(web), timeouts - ddos_failures)
	_add_failures(&"disk", errors_500)

	# 8. Economía
	_coin_fraction += (green + yellow * 0.5) * stage.coin_per_req
	var earned := floori(_coin_fraction)
	_coin_fraction -= earned
	coins += earned
	_served_fraction += successes
	var served := floori(_served_fraction)
	_served_fraction -= served
	users_served += served

	# 9. SLA (solo cuentan las peticiones legítimas)
	if requests > 0.0:
		sla = clampf(sla + (successes / requests - stage.sla_target) * config.sla_k * dt, 0.0, 100.0)

	report.requests += requests
	report.green += green
	report.yellow += yellow
	report.timeouts += timeouts
	report.errors_500 += errors_500
	report.coins_earned += earned
	report.latency_sum += latency * requests
	_stage_sla_sum += sla * dt
	_stage_time += dt
	_stage_latency_sum += latency * requests
	_stage_requests += requests

	# 11. Snapshot, cuello de botella y fin de oleada
	_fill_snapshot(legit_rps, incoming_malicious, incoming_malicious - malicious_rps, latency, u_total, requests, green, yellow)
	_update_bottleneck(web)
	tick.emit(last_snapshot)

	if sla <= 0.0:
		_finish_game_over(WaveReport.Outcome.SLA_ZERO)
	elif wave_time >= wave.duration_s:
		_finish_wave()


## Corre la oleada actual en pasos fijos hasta `seconds` o hasta que termine (para pruebas).
func run_for(seconds: float) -> void:
	var steps := ceili(seconds / config.step_seconds)
	for i in steps:
		if phase != Phase.RUNNING:
			return
		step()


func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


## Tráfico malicioso (en múltiplos de base_rps) en el segundo `t` de la oleada: fondo + picos.
func ddos_multiplier(t: float) -> float:
	if not stage.has_ddos():
		return 0.0
	var multiplier := stage.ddos_background_rate
	for spike: Vector3 in ddos_spikes:
		multiplier += WaveData.envelope(t, spike) * spike.z
	return multiplier


## Sortea los picos de la oleada: entre 1 y ddos_spike_count, uno en cada tramo igual de la oleada,
## con el inicio al azar dentro de su tramo (lejos de los bordes).
func _schedule_ddos_spikes() -> void:
	ddos_spikes.clear()
	if not stage.has_ddos() or stage.ddos_spike_count <= 0 or stage.ddos_spike_intensity <= 0.0:
		return
	var count := _rng.randi_range(1, stage.ddos_spike_count)
	var section := wave.duration_s / count
	var duration := minf(stage.ddos_spike_duration_s, section)
	for i in count:
		var start := section * i + (section - duration) * _rng.randf_range(0.2, 0.8)
		ddos_spikes.append(Vector3(start, duration, stage.ddos_spike_intensity))


func _load_server(server: ServerState, legit: float, malicious: float) -> void:
	server.load_rps = legit + malicious
	server.malicious_rps = malicious
	server.u_cpu = server.load_rps / server.cpu_cap
	server.u_net = server.load_rps / server.net_cap
	# Concurrencia: peticiones dentro del servidor al mismo tiempo (Ley de Little: C = λ × tiempo).
	server.u_ram = server.load_rps * config.service_time_s / server.ram_slots


func _peak_utilization(server: ServerState, load_rps: float) -> float:
	return maxf(load_rps / server.cpu_cap, maxf(load_rps / server.net_cap, load_rps * config.service_time_s / server.ram_slots))


func _add_failures(cause: StringName, amount: float) -> void:
	if amount <= 0.0:
		return
	report.add_failures(cause, amount)
	_stage_failures[cause] = _stage_failures.get(cause, 0.0) + amount


static func _fail_rate(utilization: float) -> float:
	return maxf(0.0, (utilization - 1.0) / utilization) if utilization > 0.0 else 0.0


func _overload_cause(web: ServerState) -> StringName:
	return &"db" if db.u_db >= web.get_peak() else web.get_peak_resource()


func _fill_snapshot(legit_rps: float, malicious_rps: float, blocked_rps: float, latency: float, u_total: float, requests: float, green: float, yellow: float) -> void:
	var snapshot := SimSnapshot.new()
	snapshot.wave_time = wave_time
	snapshot.wave_duration = wave.duration_s
	snapshot.legit_rps = legit_rps
	snapshot.malicious_rps = malicious_rps
	snapshot.blocked_rps = blocked_rps
	snapshot.latency_ms = latency
	snapshot.u_total = u_total
	if requests > 0.0:
		snapshot.green_ratio = green / requests
		snapshot.yellow_ratio = yellow / requests
		snapshot.red_ratio = maxf(1.0 - snapshot.green_ratio - snapshot.yellow_ratio, 0.0)
	last_snapshot = snapshot


func _update_bottleneck(web: ServerState) -> void:
	var resource: StringName = web.get_peak_resource()
	var node := NODE_WEB
	var peak := web.get_peak()
	if db.u_db > peak:
		resource = &"db"
		node = NODE_DB
		peak = db.u_db
	if db.get_disk_fill() > peak:
		resource = &"disk"
		node = NODE_DB
		peak = db.get_disk_fill()
	if peak < config.saturation_utilization:
		resource = &""
		node = &""
	elif node == NODE_WEB and web.load_rps > 0.0 and web.malicious_rps / web.load_rps >= config.ddos_blame_ratio:
		resource = &"ddos"
	last_snapshot.bottleneck = resource
	last_snapshot.bottleneck_node = node
	_set_bottleneck(resource, node)


func _set_bottleneck(resource: StringName, node: StringName) -> void:
	if resource != bottleneck or node != bottleneck_node:
		bottleneck = resource
		bottleneck_node = node
		bottleneck_changed.emit(resource, node)
	var saturated := resource != &""
	if saturated != is_saturated:
		is_saturated = saturated
		saturation_changed.emit(saturated)

#endregion


#region Fin de oleada, de etapa y de partida

func _finish_wave() -> void:
	report.sla_end = sla
	_fill_stage_totals()
	# La etapa se decide al terminar la última oleada: se juegan todas aunque la meta llegue antes.
	if wave_number >= stage.get_wave_count():
		if users_served >= stage.user_goal:
			_complete_stage()
		else:
			_fail_stage()
		return
	report.outcome = WaveReport.Outcome.SURVIVED
	wave_number += 1
	_set_phase(Phase.BETWEEN_WAVES)
	_set_bottleneck(&"", &"")
	_create_checkpoint()
	wave_finished.emit(report)


func _complete_stage() -> void:
	report.outcome = WaveReport.Outcome.STAGE_COMPLETE
	report.stars = _compute_stars(report.stage_avg_sla, report.stage_avg_latency_ms)
	var previous: Dictionary = stage_stats.get(stage.id, {})
	stage_stats[stage.id] = {
		"stars": maxi(report.stars, int(previous.get("stars", 0))),
		"avg_sla": report.stage_avg_sla,
		"avg_latency_ms": report.stage_avg_latency_ms,
		"users_served": users_served,
	}
	var next_id := _next_stage_id()
	# Después de la última etapa se puede volver a jugar desde su primera oleada.
	_enter_stage(next_id if next_id != &"" else stage.id)
	pending_investment = stage.investment_coins if next_id != &"" else 0
	_set_phase(Phase.READY)
	_set_bottleneck(&"", &"")
	_capture_stage_start()
	_create_checkpoint()
	pending_stage_report = report
	stage_completed.emit(report)


## Se acabaron las oleadas sin llegar a la meta. No es quiebra: se puede repetir la etapa.
func _fail_stage() -> void:
	report.outcome = WaveReport.Outcome.GOAL_MISSED
	_set_phase(Phase.STAGE_FAILED)
	_set_bottleneck(&"", &"")
	stage_failed.emit(report)


func _finish_game_over(outcome: WaveReport.Outcome) -> void:
	report.outcome = outcome
	report.sla_end = sla
	_fill_stage_totals()
	_set_phase(Phase.GAME_OVER)
	_set_bottleneck(&"", &"")
	game_over.emit(report)


func _fill_stage_totals() -> void:
	report.stage_users_served = users_served
	report.stage_avg_sla = _stage_sla_sum / _stage_time if _stage_time > 0.0 else sla
	report.stage_avg_latency_ms = _stage_latency_sum / _stage_requests if _stage_requests > 0.0 else 0.0
	report.stage_failures_by_cause = _stage_failures.duplicate()


func _compute_stars(avg_sla: float, avg_latency_ms: float) -> int:
	var stars := 1
	if avg_sla >= config.stars_sla_good:
		stars += 1
	if avg_sla >= config.stars_sla_great:
		stars += 1
	if avg_latency_ms < config.stars_latency_ms:
		stars += 1
	return stars


func _enter_stage(stage_id: StringName) -> void:
	stage = load_stage(stage_id)
	wave_number = 1
	wave = stage.get_wave(1)
	wave_time = 0.0
	users_served = 0
	sla = config.start_sla
	_stage_sla_sum = 0.0
	_stage_time = 0.0
	_stage_latency_sum = 0.0
	_stage_requests = 0.0
	_stage_failures.clear()
	ddos_spikes.clear()
	_rebuild_infrastructure()
	_reset_utilization()


func _next_stage_id() -> StringName:
	var index := Paths.STAGE_ORDER.find(stage.id)
	if index < 0 or index + 1 >= Paths.STAGE_ORDER.size():
		return &""
	return Paths.STAGE_ORDER[index + 1]


func load_stage(stage_id: StringName) -> StageData:
	var path: String = Paths.STAGES.get(stage_id, Paths.STAGES[Paths.STAGE_ORDER[0]])
	return load(path) as StageData


func _set_phase(value: Phase) -> void:
	if phase == value:
		return
	phase = value
	phase_changed.emit(value)

#endregion


#region Mejoras

## Mejoras en el orden de la consola: las de la etapa 1, luego las de la 2...
func get_upgrades() -> Array[UpgradeData]:
	var ordered: Array[UpgradeData] = []
	for stage_id: StringName in Paths.STAGE_ORDER:
		for upgrade_id: StringName in load_stage(stage_id).unlocks:
			if _upgrades.has(upgrade_id):
				ordered.append(_upgrades[upgrade_id])
	return ordered


func get_upgrade(upgrade_id: StringName) -> UpgradeData:
	return _upgrades.get(upgrade_id)


func get_level(upgrade_id: StringName) -> int:
	return upgrade_levels.get(upgrade_id, 0)


func is_unlocked(upgrade: UpgradeData) -> bool:
	return stage != null and upgrade.unlock_stage <= stage.number


func get_cost(upgrade: UpgradeData) -> int:
	return upgrade.cost_at(get_level(upgrade.id), _stage_costs.get(upgrade.id, -1))


func can_purchase(upgrade: UpgradeData) -> bool:
	if not has_session() or phase == Phase.GAME_OVER or not is_unlocked(upgrade):
		return false
	if upgrade.is_maxed(get_level(upgrade.id)) or coins < get_cost(upgrade):
		return false
	return not (upgrade.target == &"backup" and backup_cooldown > 0.0)


func purchase(upgrade_id: StringName) -> bool:
	var upgrade := get_upgrade(upgrade_id)
	if upgrade == null or not can_purchase(upgrade):
		return false
	coins -= get_cost(upgrade)
	if upgrade.target == &"backup":
		db.disk_gb_used *= 1.0 - config.backup_free_ratio
		backup_cooldown = config.backup_cooldown_s
	else:
		upgrade_levels[upgrade_id] = get_level(upgrade_id) + 1
		if upgrade.target == &"firewall":
			firewall_on = true
		_rebuild_infrastructure()
	infrastructure_changed.emit()
	return true


func is_firewall_active() -> bool:
	return has_firewall and firewall_on


func set_firewall_on(enabled: bool) -> void:
	if not has_firewall or firewall_on == enabled:
		return
	firewall_on = enabled
	infrastructure_changed.emit()


## Un servidor web está saturado si su recurso más cargado pasa el umbral (se ve en su rack).
func is_server_saturated(index: int) -> bool:
	if phase != Phase.RUNNING or index < 0 or index >= servers.size():
		return false
	return servers[index].get_peak() >= config.saturation_utilization


## Gasta o devuelve monedas fuera de las oleadas (tienda de decoración). También corrige los
## checkpoints de la oleada y de la etapa para que reintentar o repetir no regrese ese gasto.
func adjust_coins(delta: int) -> void:
	coins = maxi(coins + delta, 0)
	for checkpoint: Dictionary in [_checkpoint, _stage_checkpoint]:
		if checkpoint.has("coins"):
			checkpoint["coins"] = maxi(int(checkpoint["coins"]) + delta, 0)
	var stage_start: Dictionary = _checkpoint.get("stage_start", {})
	if stage_start.has("coins"):
		stage_start["coins"] = maxi(int(stage_start["coins"]) + delta, 0)
	infrastructure_changed.emit()


func is_stage_completed(stage_id: StringName) -> bool:
	return stage_stats.has(stage_id)


func has_load_balancer() -> bool:
	return servers.size() >= 2


## Recalcula capacidades a partir de la infraestructura inicial y los niveles comprados.
func _rebuild_infrastructure() -> void:
	var server_count := 1 + roundi(_apply_upgrades(&"add_server", 0.0))
	servers.resize(server_count)
	for i in server_count:
		if servers[i] == null:
			servers[i] = ServerState.new()
		# Las mejoras de CPU, RAM y red aplican a todos los servidores.
		servers[i].cpu_cap = _apply_upgrades(&"cpu_cap", config.start_cpu_cap)
		servers[i].ram_slots = _apply_upgrades(&"ram_slots", config.start_ram_slots)
		servers[i].net_cap = _apply_upgrades(&"net_cap", config.start_net_cap)
	db.iops = _apply_upgrades(&"iops", config.start_iops)
	db.disk_gb_cap = _apply_upgrades(&"disk_gb_cap", config.start_disk_gb_cap)
	db.cache_hit = minf(_apply_upgrades(&"cache_hit", config.start_cache_hit), config.max_cache_hit)
	has_firewall = _apply_upgrades(&"firewall", 0.0) > 0.0
	if not has_firewall:
		firewall_on = false


## Sin oleada no hay carga: limpia lo que quedó del último paso.
func _reset_utilization() -> void:
	for server: ServerState in servers:
		server.u_cpu = 0.0
		server.u_ram = 0.0
		server.u_net = 0.0
		server.load_rps = 0.0
		server.malicious_rps = 0.0
	db.u_db = 0.0
	last_snapshot = SimSnapshot.new()


func _apply_upgrades(target: StringName, base_value: float) -> float:
	var value := base_value
	for upgrade: UpgradeData in _upgrades.values():
		if upgrade.target == target:
			value = upgrade.apply(value, get_level(upgrade.id))
	return value


func _load_upgrades() -> void:
	_upgrades.clear()
	_stage_costs.clear()
	for stage_id: StringName in Paths.STAGE_ORDER:
		var stage_data := load_stage(stage_id)
		for upgrade_id: StringName in stage_data.upgrade_costs:
			_stage_costs[upgrade_id] = stage_data.upgrade_costs[upgrade_id]
		for upgrade_id: StringName in stage_data.unlocks:
			var upgrade := load(Paths.UPGRADE % upgrade_id) as UpgradeData
			if upgrade == null:
				push_error("No existe la mejora %s" % upgrade_id)
				continue
			_upgrades[upgrade_id] = upgrade

#endregion


#region Checkpoint (guardado)

func get_checkpoint() -> Dictionary:
	return _checkpoint.duplicate(true)


## Restaura un checkpoint (de una partida guardada o del inicio de la oleada). Corrige valores inválidos.
func load_checkpoint(data: Dictionary) -> void:
	var stage_id := StringName(str(data.get("stage", Paths.STAGE_ORDER[0])))
	if not Paths.STAGES.has(stage_id):
		stage_id = Paths.STAGE_ORDER[0]
	upgrade_levels.clear()
	var levels: Dictionary = data.get("upgrade_levels", {})
	for upgrade_id: Variant in levels:
		var id := StringName(str(upgrade_id))
		if _upgrades.has(id):
			var upgrade := _upgrades[id]
			var level := maxi(int(levels[upgrade_id]), 0)
			upgrade_levels[id] = level if upgrade.is_action() else mini(level, upgrade.max_level)
	_enter_stage(stage_id)
	wave_number = clampi(int(data.get("wave", 1)), 1, stage.get_wave_count())
	wave = stage.get_wave(wave_number)
	coins = maxi(int(data.get("coins", config.start_coins)), 0)
	users_served = maxi(int(data.get("users_served", 0)), 0)
	sla = clampf(float(data.get("sla", config.start_sla)), 0.0, 100.0)
	db.disk_gb_used = clampf(float(data.get("disk_gb_used", config.start_disk_gb_used)), 0.0, db.disk_gb_cap)
	firewall_on = has_firewall and bool(data.get("firewall_on", true))
	backup_cooldown = 0.0
	_stage_sla_sum = float(data.get("stage_sla_sum", 0.0))
	_stage_time = float(data.get("stage_time", 0.0))
	_stage_latency_sum = float(data.get("stage_latency_sum", 0.0))
	_stage_requests = float(data.get("stage_requests", 0.0))
	stage_stats.clear()
	var stats: Dictionary = data.get("stage_stats", {})
	for key: Variant in stats:
		if stats[key] is Dictionary:
			stage_stats[StringName(str(key))] = stats[key]
	var failures: Dictionary = data.get("stage_failures", {})
	for cause: Variant in failures:
		_stage_failures[StringName(str(cause))] = float(failures[cause])
	_coin_fraction = 0.0
	_served_fraction = 0.0
	pending_stage_report = null
	pending_investment = 0
	_checkpoint = data.duplicate(true)
	var stage_start: Dictionary = data.get("stage_start", {})
	# Sin "stage_start" el propio checkpoint es el inicio de la etapa (o una partida guardada antigua).
	_stage_checkpoint = stage_start.duplicate(true) if not stage_start.is_empty() else _without_stage_start(data)
	# Si se cerró el juego antes de aceptar la victoria, la ronda de inversión se entrega aquí.
	var investment := maxi(int(data.get("pending_investment", 0)), 0)
	if investment > 0:
		coins += investment
		_stage_checkpoint["coins"] = int(_stage_checkpoint.get("coins", 0)) + investment
		_checkpoint["pending_investment"] = 0
		_checkpoint["coins"] = coins
	_set_bottleneck(&"", &"")
	_set_phase(Phase.READY)
	infrastructure_changed.emit()


func _create_checkpoint() -> void:
	_checkpoint = _build_checkpoint_data()
	_checkpoint["stage_start"] = _stage_checkpoint.duplicate(true)
	_checkpoint["pending_investment"] = pending_investment
	checkpoint_created.emit()


## Guarda el estado actual como inicio de la etapa (para "Repetir etapa").
func _capture_stage_start() -> void:
	_stage_checkpoint = _build_checkpoint_data()


## Convierte un checkpoint en "inicio de etapa": oleada 1, sin usuarios ni estadísticas de la etapa.
## Se usa con partidas guardadas que no traen "stage_start".
func _without_stage_start(data: Dictionary) -> Dictionary:
	var copy := data.duplicate(true)
	for key: String in ["stage_start", "pending_investment", "stage_sla_sum", "stage_time", "stage_latency_sum", "stage_requests", "stage_failures"]:
		copy.erase(key)
	copy["wave"] = 1
	copy["users_served"] = 0
	copy["sla"] = config.start_sla
	return copy


func _build_checkpoint_data() -> Dictionary:
	var levels: Dictionary = {}
	for upgrade_id: StringName in upgrade_levels:
		levels[String(upgrade_id)] = upgrade_levels[upgrade_id]
	var stats: Dictionary = {}
	for stage_id: StringName in stage_stats:
		stats[String(stage_id)] = stage_stats[stage_id].duplicate()
	var failures: Dictionary = {}
	for cause: StringName in _stage_failures:
		failures[String(cause)] = _stage_failures[cause]
	return {
		"stage": String(stage.id),
		"wave": wave_number,
		"coins": coins,
		"users_served": users_served,
		"sla": sla,
		"disk_gb_used": db.disk_gb_used,
		"firewall_on": firewall_on,
		"upgrade_levels": levels,
		"stage_sla_sum": _stage_sla_sum,
		"stage_time": _stage_time,
		"stage_latency_sum": _stage_latency_sum,
		"stage_requests": _stage_requests,
		"stage_stats": stats,
		"stage_failures": failures,
	}

#endregion
