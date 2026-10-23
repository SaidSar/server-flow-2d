extends Node
## Autoload "Simulation": esqueleto del bucle de simulación.
## Cada tick recalcula la carga de los servidores, el SLA y los ingresos.
## En builds de depuración, F9 fuerza una sobrecarga para probar el estado saturado.

signal tick(tick_index: int)
## Algún recurso pasó (o dejó de pasar) el umbral de saturación.
signal saturation_changed(is_saturated: bool)

const TICK_SECONDS := 1.0
const SATURATION_THRESHOLD := 85.0
const BASE_LOAD := 20.0
const LOAD_PER_USER := 1.5
const LOAD_NOISE := 8.0
const LOAD_SMOOTHING := 0.3
## Peso de la demanda sobre cada recurso.
const RESOURCE_WEIGHTS := {&"cpu": 1.0, &"ram": 0.9, &"network": 0.8, &"disk": 0.6}
const INCOME_PER_USER := 0.1
const SLA_PENALTY_PER_TICK := 0.5
const SLA_RECOVERY_PER_TICK := 0.1
const DEBUG_OVERLOAD := 60.0

var servers: Array[ServerState] = []
var sla := 100.0
var is_saturated := false
var tick_index := 0
var overload_enabled := false

var _timer: Timer
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = TICK_SECONDS
	_timer.timeout.connect(step)
	add_child(_timer)
	GameState.session_started.connect(reset)
	reset()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if OS.is_debug_build() and key != null and key.pressed and not key.echo and key.keycode == KEY_F9:
		set_overload(not overload_enabled)
		print("[Simulation] Sobrecarga de prueba: %s" % ("activada" if overload_enabled else "desactivada"))


func reset() -> void:
	servers = [ServerState.new()]
	sla = 100.0
	tick_index = 0
	overload_enabled = false
	_set_saturated(false)


func start() -> void:
	if _timer.is_stopped():
		_timer.start()


func stop() -> void:
	_timer.stop()


func is_running() -> bool:
	return not _timer.is_stopped()


func set_overload(enabled: bool) -> void:
	overload_enabled = enabled


## Avanza un tick. Lo llama el Timer; también se puede llamar en pruebas.
func step() -> void:
	tick_index += 1
	var demand := BASE_LOAD + GameState.users * LOAD_PER_USER
	if overload_enabled:
		demand += DEBUG_OVERLOAD

	for server: ServerState in servers:
		server.cpu = _approach(server.cpu, demand * RESOURCE_WEIGHTS[&"cpu"])
		server.ram = _approach(server.ram, demand * RESOURCE_WEIGHTS[&"ram"])
		server.network = _approach(server.network, demand * RESOURCE_WEIGHTS[&"network"])
		server.disk = _approach(server.disk, demand * RESOURCE_WEIGHTS[&"disk"])

	_set_saturated(_any_server_saturated())
	if is_saturated:
		sla = maxf(sla - SLA_PENALTY_PER_TICK, 0.0)
	else:
		sla = minf(sla + SLA_RECOVERY_PER_TICK, 100.0)
	GameState.add_coins(roundi(GameState.users * INCOME_PER_USER))
	tick.emit(tick_index)


func _approach(current: float, target: float) -> float:
	var noisy_target := target + _rng.randf_range(-LOAD_NOISE, LOAD_NOISE)
	return clampf(lerpf(current, noisy_target, LOAD_SMOOTHING), 0.0, 100.0)


func _any_server_saturated() -> bool:
	for server: ServerState in servers:
		if server.get_peak_load() > SATURATION_THRESHOLD:
			return true
	return false


func _set_saturated(value: bool) -> void:
	if value == is_saturated:
		return
	is_saturated = value
	saturation_changed.emit(is_saturated)
