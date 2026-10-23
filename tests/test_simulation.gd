extends SceneTree
## Pruebas del modelo de simulación, sin ventana y con semilla fija.
## Uso: godot --headless --path . -s res://tests/test_simulation.gd
## Imprime un resumen por oleada que sirve para revisar el balance.
## Nota: con -s los autoloads se registran después de compilar este script,
## así que aquí se usan a través de root.get_node() y no como identificadores globales.

const SEED := 20261023
## Pasos entre decisiones de compra de la estrategia simple (1 s).
const DECISION_STEPS := 10
## La estrategia compra la mejora del recurso más cargado cuando pasa de este valor.
const BUY_THRESHOLD := 0.7
## Y hace un respaldo cuando el disco pasa de este llenado.
const BACKUP_THRESHOLD := 0.8

const PHASE_RUNNING := 2
const PHASE_BETWEEN_WAVES := 3
const PHASE_GAME_OVER := 4

var _failures: Array[String] = []
var _sim: Node
var _reports: Array[WaveReport] = []
var _game_over_report: WaveReport
var _stage_report: WaveReport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_sim = root.get_node("Simulation")
	root.get_node("SaveSystem").set("save_path", "user://test_simulation_save.cfg")
	_sim.connect("wave_finished", func(report: WaveReport) -> void: _reports.append(report))
	_sim.connect("game_over", func(report: WaveReport) -> void: _game_over_report = report)
	_sim.connect("stage_completed", func(report: WaveReport) -> void: _stage_report = report)

	_test_no_purchases_loses()
	_test_simple_strategy_wins()
	_report_later_stages()
	_test_full_disk()
	_test_load_balancer()
	_test_firewall()
	_test_stage_unlocks_match_upgrades()

	_sim.call("end_session")
	root.get_node("SaveSystem").call("delete_save")
	if _failures.is_empty():
		print("TEST SIMULATION OK")
		quit(0)
	else:
		printerr("TEST SIMULATION FALLÓ:\n- " + "\n- ".join(_failures))
		quit(1)


## 1. Sin mejoras, la etapa 1 termina en game over antes de acabar la oleada 3.
func _test_no_purchases_loses() -> void:
	print("\n== Sin compras")
	var lost_wave := _play_stage(false)
	_check(_game_over_report != null, "sin compras hay game over")
	_check(lost_wave >= 1 and lost_wave <= 3, "sin compras se pierde a más tardar en la oleada 3 (perdió en la %d)" % lost_wave)


## 2. Comprando el cuello de botella cuando alcanza, se superan las 5 oleadas de la etapa 1.
func _test_simple_strategy_wins() -> void:
	print("\n== Estrategia simple (compra el cuello de botella)")
	var lost_wave := _play_stage(true)
	_check(lost_wave == 0, "la estrategia simple no pierde (perdió en la oleada %d)" % lost_wave)
	_check(_stage_report != null and _stage_report.wave_number == 5, "la etapa 1 se completa en la oleada 5")
	if _stage_report != null:
		print("   Etapa completada: usuarios %d/%d, SLA promedio %.1f, latencia promedio %.0f ms, %d estrellas, monedas al final %d" % [
			_stage_report.stage_users_served, _stage_report.stage_user_goal, _stage_report.stage_avg_sla,
			_stage_report.stage_avg_latency_ms, _stage_report.stars, _sim.get("coins")])
	_check(_sim.get("stage").id == &"scale_up", "después de la victoria la etapa es Scale-up")


## Informativo (no falla): la misma estrategia sigue con las etapas 2 y 3.
## Sirve para revisar el balance de esas etapas, que todavía no está afinado.
func _report_later_stages() -> void:
	for stage_name: String in ["Scale-up", "Enterprise"]:
		print("
== %s con la estrategia simple (informativo)" % stage_name)
		_stage_report = null
		_game_over_report = null
		var lost_wave := _play_current_stage(true)
		if lost_wave > 0:
			print("   Perdió en la oleada %d (causa: %s)" % [lost_wave, _game_over_report.get_main_cause()])
			return
		print("   Etapa completada: usuarios %d/%d, SLA promedio %.1f, %d estrellas" % [
			_stage_report.stage_users_served, _stage_report.stage_user_goal, _stage_report.stage_avg_sla, _stage_report.stars])


## 3. Con el disco al 100 %, las escrituras fallan y la causa principal es el disco.
func _test_full_disk() -> void:
	_new_game()
	_sim.call("start_wave")
	_set_huge_server_capacity()
	var db: DbState = _sim.get("db")
	db.iops = 1000.0
	db.disk_gb_used = db.disk_gb_cap
	_sim.call("run_for", 20.0)
	var report: WaveReport = _sim.get("report")
	_check(report.errors_500 > 0.0, "con el disco lleno hay errores 500")
	_check(report.get_main_cause() == &"disk", "la causa principal es el disco (fue %s)" % report.get_main_cause())


## 4. Con 2 servidores y Load Balancer, cada servidor recibe la mitad de la carga.
func _test_load_balancer() -> void:
	var single := _load_after_one_step({})
	var balanced_servers := _servers_after_one_step({"web_server": 1})
	_check(balanced_servers.size() == 2, "con un servidor extra hay 2 servidores")
	_check(_sim.call("has_load_balancer"), "con 2 servidores hay Load Balancer")
	for server: ServerState in balanced_servers:
		var ratio := server.load_rps / single
		_check(absf(ratio - 0.5) < 0.05, "cada servidor recibe ~50 %% de la carga (recibió %.0f %%)" % (ratio * 100.0))


## 5. El firewall deja pasar el 15 % del tráfico malicioso y suma latencia.
func _test_firewall() -> void:
	var off := _ddos_sample(false)
	var on := _ddos_sample(true)
	_check(off.x > 0.0, "la oleada de prueba tiene DDoS")
	_check(absf(on.x / off.x - 0.15) < 0.01, "con firewall llega el 15 %% del tráfico malicioso (llegó %.1f %%)" % (on.x / off.x * 100.0))
	_check(absf(on.y - off.y - 15.0) < 1.0, "el firewall suma ~15 ms de latencia (sumó %.1f ms)" % (on.y - off.y))


## Las mejoras que lista cada etapa en `unlocks` coinciden con su `unlock_stage`.
func _test_stage_unlocks_match_upgrades() -> void:
	for stage_id: StringName in Paths.STAGE_ORDER:
		var stage: StageData = _sim.call("load_stage", stage_id)
		for upgrade_id: StringName in stage.unlocks:
			var upgrade: UpgradeData = _sim.call("get_upgrade", upgrade_id)
			_check(upgrade != null and upgrade.unlock_stage == stage.number, "%s se desbloquea en la etapa %d" % [upgrade_id, stage.number])


#region Ayudantes

## Juega la etapa 1 completa desde una partida nueva. Devuelve la oleada en que perdió (0 = no perdió).
func _play_stage(buy: bool) -> int:
	_new_game()
	return _play_current_stage(buy)


func _play_current_stage(buy: bool) -> int:
	for wave_index in _sim.call("get_wave_count"):
		_sim.call("start_wave")
		var steps := 0
		while _sim.get("phase") == PHASE_RUNNING:
			if buy and steps % DECISION_STEPS == 0:
				_buy_bottleneck()
			_sim.call("step")
			steps += 1
		var report: WaveReport = _sim.get("report")
		_print_wave(report)
		if _sim.get("phase") == PHASE_GAME_OVER:
			return report.wave_number
		if _stage_report != null:
			return 0
		if buy:
			_buy_bottleneck()
	return 0


## Estrategia simple: respaldo si el disco se está llenando, firewall si hay DDoS
## y la mejora más barata que arregle el recurso más cargado.
func _buy_bottleneck() -> void:
	var db: DbState = _sim.get("db")
	if db.get_disk_fill() > BACKUP_THRESHOLD:
		if not _sim.call("purchase", &"backup"):
			_sim.call("purchase", &"disk_expansion")
	if (_sim.get("last_snapshot") as SimSnapshot).malicious_rps > 0.0:
		_sim.call("purchase", &"firewall")
	var web: ServerState = (_sim.get("servers") as Array)[0]
	var resource: StringName = web.get_peak_resource()
	var peak := web.get_peak()
	if db.u_db > peak:
		resource = &"db"
		peak = db.u_db
	if peak < BUY_THRESHOLD:
		return
	var cheapest: UpgradeData = null
	for upgrade: UpgradeData in _sim.call("get_upgrades"):
		if resource in upgrade.fixes and not upgrade.is_action() and _sim.call("can_purchase", upgrade):
			if cheapest == null or _sim.call("get_cost", upgrade) < _sim.call("get_cost", cheapest):
				cheapest = upgrade
	if cheapest != null:
		_sim.call("purchase", cheapest.id)


func _print_wave(report: WaveReport) -> void:
	var levels: Dictionary = _sim.get("upgrade_levels")
	print("   Oleada %d: atendidas %d/%.0f (verde %.0f, amarillo %.0f), timeouts %.0f, 500 %.0f, SLA %.1f → %.1f, +%d monedas (total %d), usuarios %d, causa: %s, mejoras %s" % [
		report.wave_number, report.get_served(), report.requests, report.green, report.yellow, report.timeouts,
		report.errors_500, report.sla_start, report.sla_end, report.coins_earned, _sim.get("coins"),
		report.stage_users_served, report.get_main_cause(), levels])


func _new_game() -> void:
	_reports.clear()
	_game_over_report = null
	_stage_report = null
	_sim.call("set_seed", SEED)
	_sim.call("new_game")


func _set_huge_server_capacity() -> void:
	for server: ServerState in _sim.get("servers"):
		server.cpu_cap = 1e6
		server.net_cap = 1e6
		server.ram_slots = 1e6


func _servers_after_one_step(levels: Dictionary) -> Array:
	_sim.call("set_seed", SEED)
	_sim.call("load_checkpoint", {"stage": "startup", "wave": 1, "upgrade_levels": levels})
	_sim.call("start_wave")
	_sim.call("step")
	return _sim.get("servers")


func _load_after_one_step(levels: Dictionary) -> float:
	var servers := _servers_after_one_step(levels)
	return (servers[0] as ServerState).load_rps


## Corre la oleada 1 de Enterprise hasta la mitad del DDoS. Devuelve (malicioso que llega al servidor, latencia).
func _ddos_sample(firewall_on: bool) -> Vector2:
	_sim.call("set_seed", SEED)
	_sim.call("load_checkpoint", {"stage": "enterprise", "wave": 1, "upgrade_levels": {"firewall": 1}, "firewall_on": firewall_on})
	_sim.call("start_wave")
	_set_huge_server_capacity()
	var db: DbState = _sim.get("db")
	db.iops = 1e6
	var wave: WaveData = _sim.get("wave")
	var attack := wave.ddos[0]
	_sim.call("run_for", attack.x + attack.y * 0.5)
	var web: ServerState = (_sim.get("servers") as Array)[0]
	var snapshot: SimSnapshot = _sim.get("last_snapshot")
	return Vector2(web.malicious_rps, snapshot.latency_ms)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)

#endregion
