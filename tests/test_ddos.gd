extends SceneTree
## Pruebas del DDoS de la etapa 3 (Enterprise) y del Firewall, sin ventana y con semilla fija.
## Uso: godot --headless --path . -s res://tests/test_ddos.gd -- --save-path=user://test_ddos.cfg
## Nota: con -s los autoloads se registran después de compilar este script,
## así que aquí se usan a través de root.get_node() y no como identificadores globales.

const SEED := 20261030
const PHASE_READY := 1
const PHASE_RUNNING := 2
const PHASE_BETWEEN_WAVES := 3
const PHASE_GAME_OVER := 4
## Uso de CPU/RAM/red que deja el tráfico legítimo en los servidores de prueba (sin ataque).
const LEGIT_UTILIZATION := 0.45
## Sin Firewall, el pico debe al menos duplicar el uso de cada recurso.
const MIN_SPIKE_LOAD_RATIO := 2.0
## SLA que debe perder la oleada sin Firewall durante el pico (puntos).
const MIN_SLA_DROP_WITHOUT_FIREWALL := 5.0
## Lo más que puede bajar el SLA con el Firewall encendido durante el mismo pico (puntos).
const MAX_SLA_DROP_WITH_FIREWALL := 0.5
## Pasos para revisar que no hay DDoS en una etapa (30 s).
const NO_DDOS_STEPS := 300
## Semillas para revisar el sorteo de picos.
const SCHEDULE_SEEDS := 20

var _failures: Array[String] = []
var _sim: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_sim = root.get_node("Simulation")
	var save_system: Node = root.get_node("SaveSystem")
	if save_system.call("is_using_real_save"):
		printerr("test_ddos: corre la prueba con una partida alterna para no tocar la real, p. ej.: -- --save-path=user://test_ddos.cfg")
		quit(1)
		return

	_test_only_enterprise_has_ddos()
	_test_background_traffic()
	_test_spike_schedule()
	_test_firewall_purchase()
	_test_spike_without_firewall_hurts()
	_test_spike_with_firewall_barely_hurts()
	_test_postmortem_cause()

	_sim.call("end_session")
	save_system.call("delete_save")
	if _failures.is_empty():
		print("TEST DDOS OK")
		quit(0)
	else:
		printerr("TEST DDOS FALLÓ:\n- " + "\n- ".join(_failures))
		quit(1)


## El tráfico malicioso de fondo y los picos solo aparecen en la etapa 3, nunca en garage ni oficina.
func _test_only_enterprise_has_ddos() -> void:
	for stage_id: StringName in [&"startup", &"scale_up"]:
		var stage: StageData = _sim.call("load_stage", stage_id)
		_check(not stage.has_ddos(), "%s no define DDoS" % stage_id)
		for wave_number in range(1, stage.get_wave_count() + 1):
			_start(stage_id, wave_number, false)
			_size_servers_for(_max_legit_rps())
			_check((_sim.get("ddos_spikes") as Array).is_empty(), "%s oleada %d: sin picos de ataque" % [stage_id, wave_number])
			var most := 0.0
			for i in NO_DDOS_STEPS:
				if _sim.get("phase") != PHASE_RUNNING:
					break
				_sim.call("step")
				most = maxf(most, (_sim.get("last_snapshot") as SimSnapshot).malicious_rps)
			_check(is_zero_approx(most), "%s oleada %d: sin tráfico malicioso (llegó %.2f req/s)" % [stage_id, wave_number, most])
	_check((_sim.call("load_stage", &"enterprise") as StageData).has_ddos(), "Enterprise sí tiene DDoS")


## Fuera de los picos llega un tráfico malicioso de fondo bajo y constante.
func _test_background_traffic() -> void:
	var stage: StageData = _sim.call("load_stage", &"enterprise")
	_check(stage.ddos_background_rate > 0.0 and stage.ddos_background_rate < stage.ddos_spike_intensity, "el fondo es más bajo que un pico")
	_start(&"enterprise", 1, false)
	_size_servers_for(_max_legit_rps())
	var first: Vector3 = (_sim.get("ddos_spikes") as Array)[0]
	var expected := stage.base_rps * stage.ddos_background_rate
	var samples := 0
	while _sim.get("phase") == PHASE_RUNNING and float(_sim.get("wave_time")) < first.x - 0.5:
		_sim.call("step")
		var malicious := (_sim.get("last_snapshot") as SimSnapshot).malicious_rps
		_check(absf(malicious - expected) < 0.001, "fondo constante de %.1f req/s antes del pico (t %.1f: %.2f)" % [expected, _sim.get("wave_time"), malicious])
		samples += 1
	_check(samples > 0, "hay tiempo antes del primer pico (%.1f s)" % first.x)


## Entre 1 y ddos_spike_count picos por oleada, dentro de la oleada y sin encimarse.
func _test_spike_schedule() -> void:
	var stage: StageData = _sim.call("load_stage", &"enterprise")
	var counts := {}
	for i in SCHEDULE_SEEDS:
		_sim.call("set_seed", SEED + i)
		_sim.call("load_checkpoint", {"stage": "enterprise", "wave": 1 + i % stage.get_wave_count()})
		_sim.call("start_wave")
		var wave: WaveData = _sim.get("wave")
		var spikes: Array = _sim.get("ddos_spikes")
		counts[spikes.size()] = true
		_check(spikes.size() >= 1 and spikes.size() <= stage.ddos_spike_count, "entre 1 y %d picos (salieron %d)" % [stage.ddos_spike_count, spikes.size()])
		var previous_end := 0.0
		for spike: Vector3 in spikes:
			_check(spike.x >= previous_end and spike.x + spike.y <= wave.duration_s, "pico dentro de la oleada y sin encimarse (%s)" % spike)
			_check(is_equal_approx(spike.y, stage.ddos_spike_duration_s) and is_equal_approx(spike.z, stage.ddos_spike_intensity), "el pico usa la duración y la intensidad de la etapa")
			previous_end = spike.x + spike.y
	_check(counts.size() > 1 or stage.ddos_spike_count == 1, "el número de picos cambia entre oleadas (%s)" % [counts.keys()])


## El Firewall se compra en la consola solo en la etapa 3, con el costo de su etapa, y queda encendido.
func _test_firewall_purchase() -> void:
	var stage: StageData = _sim.call("load_stage", &"enterprise")
	var firewall: UpgradeData = _sim.call("get_upgrade", &"firewall")
	_sim.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 99999})
	_check(not _sim.call("can_purchase", firewall), "el Firewall está bloqueado en la etapa 2")
	_sim.call("load_checkpoint", {"stage": "enterprise", "wave": 1, "coins": 5000})
	var cost: int = _sim.call("get_cost", firewall)
	_check(cost == stage.upgrade_costs[&"firewall"], "el Firewall cuesta lo que dice enterprise.tres (%d)" % cost)
	_check(not _sim.call("is_firewall_active"), "sin comprarlo el Firewall está apagado")
	_check(_sim.call("purchase", &"firewall"), "comprar el Firewall en la etapa 3")
	_check(_sim.call("is_firewall_active") and _sim.get("coins") == 5000 - cost, "al comprarlo queda encendido y cobra %d" % cost)
	_check(not _sim.call("purchase", &"firewall"), "el Firewall se compra una sola vez")


## Sin Firewall, un pico sube notoriamente CPU, RAM y red de los servidores y baja el SLA.
func _test_spike_without_firewall_hurts() -> void:
	var result := _run_spike(false)
	for resource_id: StringName in ServerState.RESOURCE_IDS:
		var before: float = result["before"][resource_id]
		var peak: float = result["peak"][resource_id]
		_check(peak >= before * MIN_SPIKE_LOAD_RATIO, "sin Firewall el pico sube %s de %.0f %% a %.0f %%" % [resource_id, before * 100.0, peak * 100.0])
	var drop: float = result["sla_drop"]
	_check(drop >= MIN_SLA_DROP_WITHOUT_FIREWALL, "sin Firewall el pico baja el SLA (bajó %.1f puntos)" % drop)
	print("   Sin Firewall: SLA %.1f → %.1f, CPU pico %.0f %%" % [result["sla_before"], result["sla_after"], result["peak"][&"cpu"] * 100.0])


## Con el Firewall encendido, el mismo pico casi no afecta el SLA.
func _test_spike_with_firewall_barely_hurts() -> void:
	var without := _run_spike(false)
	var with := _run_spike(true)
	_check(with["sla_drop"] <= MAX_SLA_DROP_WITH_FIREWALL, "con Firewall el pico casi no baja el SLA (bajó %.1f puntos)" % with["sla_drop"])
	_check(with["sla_drop"] < without["sla_drop"], "el SLA cae menos con Firewall que sin él")
	_check(with["peak"][&"cpu"] < 1.0, "con Firewall el CPU no se satura en el pico (%.0f %%)" % (with["peak"][&"cpu"] * 100.0))
	var blocked := (_sim.get("last_snapshot") as SimSnapshot).blocked_rps
	_check(blocked > 0.0, "el Firewall reporta tráfico bloqueado (%.1f req/s)" % blocked)
	print("   Con Firewall: SLA %.1f → %.1f, CPU pico %.0f %%" % [with["sla_before"], with["sla_after"], with["peak"][&"cpu"] * 100.0])


## El post-mortem culpa al DDoS cuando el ataque tumbó las peticiones, y explica qué es y cómo se mitiga.
func _test_postmortem_cause() -> void:
	var finished: Array[WaveReport] = []
	var on_finished := func(report: WaveReport) -> void: finished.append(report)
	_sim.connect("wave_finished", on_finished)
	_sim.connect("game_over", on_finished)
	for firewall_on: bool in [false, true]:
		finished.clear()
		_start(&"enterprise", 1, firewall_on)
		_size_servers_for(_max_legit_rps())
		while _sim.get("phase") == PHASE_RUNNING:
			_sim.call("step")
		_check(finished.size() == 1, "la oleada termina con un reporte")
		if finished.is_empty():
			continue
		var report := finished[0]
		if firewall_on:
			_check(report.get_main_cause() != &"ddos", "con Firewall el post-mortem no culpa al DDoS (causa: %s)" % report.get_main_cause())
		else:
			_check(report.get_main_cause() == &"ddos", "sin Firewall el post-mortem reporta ddos (causa: %s)" % report.get_main_cause())
			_check(report.get_main_cause_title() == "DDoS", "el título de la causa es DDoS")
			var lesson := report.get_main_cause_explanation()
			_check(lesson.contains("denegación de servicio") and lesson.contains("firewall"), "la lección explica el DDoS y el firewall (%s)" % lesson)
	_sim.disconnect("wave_finished", on_finished)
	_sim.disconnect("game_over", on_finished)


#region Ayudantes

## Empieza una oleada con semilla fija; con o sin Firewall comprado y encendido.
func _start(stage_id: StringName, wave_number: int, firewall_on: bool) -> void:
	_sim.call("set_seed", SEED)
	var levels := {"firewall": 1} if firewall_on else {}
	_sim.call("load_checkpoint", {"stage": String(stage_id), "wave": wave_number, "upgrade_levels": levels, "firewall_on": firewall_on})
	_sim.call("start_wave")


## Corre la oleada 1 de Enterprise a través del primer pico. Los servidores se dimensionan para que el
## tráfico legítimo los deje en LEGIT_UTILIZATION, así lo que cambia es solo el ataque.
## Devuelve el uso antes y en la cima del pico, y el SLA antes y después.
func _run_spike(firewall_on: bool) -> Dictionary:
	_start(&"enterprise", 1, firewall_on)
	var spike: Vector3 = (_sim.get("ddos_spikes") as Array)[0]
	var wave: WaveData = _sim.get("wave")
	var stage: StageData = _sim.get("stage")
	_size_servers_for(stage.base_rps * wave.traffic_multiplier(spike.x + spike.y))
	_run_until(spike.x - 0.5)
	var web: ServerState = (_sim.get("servers") as Array)[0]
	var before := _utilization(web)
	var sla_before: float = _sim.get("sla")
	_run_until(spike.x + spike.y * 0.5)
	var peak := _utilization(web)
	_run_until(spike.x + spike.y)
	var sla_after: float = _sim.get("sla")
	return {"before": before, "peak": peak, "sla_before": sla_before, "sla_after": sla_after, "sla_drop": sla_before - sla_after}


func _run_until(wave_time: float) -> void:
	while _sim.get("phase") == PHASE_RUNNING and float(_sim.get("wave_time")) < wave_time:
		_sim.call("step")


## Mayor tráfico legítimo de la oleada en curso (la rampa crece hasta el final).
func _max_legit_rps() -> float:
	var wave: WaveData = _sim.get("wave")
	var stage: StageData = _sim.get("stage")
	var most := 0.0
	var t := 0.0
	while t <= wave.duration_s:
		most = maxf(most, wave.traffic_multiplier(t))
		t += 1.0
	return stage.base_rps * most


## Ajusta la capacidad del servidor y de la BD para que `legit_rps` deje CPU, RAM y red en LEGIT_UTILIZATION.
func _size_servers_for(legit_rps: float) -> void:
	var config: SimulationConfig = _sim.get("config")
	for server: ServerState in _sim.get("servers"):
		server.cpu_cap = legit_rps / LEGIT_UTILIZATION
		server.net_cap = legit_rps / LEGIT_UTILIZATION
		server.ram_slots = legit_rps * config.service_time_s / LEGIT_UTILIZATION
	var db: DbState = _sim.get("db")
	db.iops = 1e6
	db.disk_gb_cap = 1e6


func _utilization(server: ServerState) -> Dictionary:
	return {&"cpu": server.u_cpu, &"ram": server.u_ram, &"net": server.u_net}


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)

#endregion
