extends SceneTree
## Pruebas del modelo de simulación, sin ventana y con semilla fija.
## Uso: godot --headless --path . -s res://tests/test_simulation.gd -- --save-path=user://test_simulation.cfg
## Imprime un resumen por oleada que sirve para revisar el balance.
## Nota: con -s los autoloads se registran después de compilar este script,
## así que aquí se usan a través de root.get_node() y no como identificadores globales.

const SEED := 20261023
## Pasos entre decisiones de compra de las estrategias (1 s).
const DECISION_STEPS := 10
## La estrategia buena compra la mejora del recurso más cargado cuando pasa de este valor.
const BUY_THRESHOLD := 0.7
## Y hace un respaldo cuando el disco pasa de este llenado.
const BACKUP_THRESHOLD := 0.8
## Holgura mínima y máxima de usuarios contra la meta al terminar la oleada 4 (estrategia buena).
const MIN_GOAL_SLACK_AT_WAVE_4 := 1.15
const MAX_GOAL_SLACK_AT_WAVE_4 := 1.4
## SLA mínimo al final de la oleada 5 con la estrategia buena.
const GOOD_FINAL_SLA := 90.0

const PHASE_RUNNING := 2
const PHASE_BETWEEN_WAVES := 3
const PHASE_GAME_OVER := 4
const PHASE_STAGE_FAILED := 5

enum Strategy {
	## No compra nada.
	NONE,
	## Compra la mejora que arregla el recurso más cargado (y respaldos/firewall cuando hacen falta).
	BOTTLENECK,
	## Compra siempre la mejora más barata que alcance, sin mirar el cuello de botella.
	CHEAPEST,
}

var _failures: Array[String] = []
var _sim: Node
var _reports: Array[WaveReport] = []
var _game_over_report: WaveReport
var _stage_report: WaveReport
var _stage_failed_report: WaveReport


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_sim = root.get_node("Simulation")
	var save_system: Node = root.get_node("SaveSystem")
	if save_system.call("is_using_real_save"):
		printerr("test_simulation: corre la prueba con una partida alterna para no tocar la real, p. ej.: -- --save-path=user://test_simulation.cfg")
		quit(1)
		return

	_sim.connect("wave_finished", func(report: WaveReport) -> void: _reports.append(report))
	_sim.connect("game_over", func(report: WaveReport) -> void: _game_over_report = report)
	_sim.connect("stage_completed", func(report: WaveReport) -> void: _stage_report = report)
	_sim.connect("stage_failed", func(report: WaveReport) -> void: _stage_failed_report = report)

	_test_no_purchases_loses()
	var good_avg_sla := _test_bottleneck_strategy_wins()
	_report_later_stages()
	_test_cheapest_strategy_suffers(good_avg_sla)
	_test_goal_missed_and_repeat_stage()
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


## 1. Sin mejoras, la etapa 1 termina en quiebra (SLA en 0) en la oleada 2.
func _test_no_purchases_loses() -> void:
	print("\n== Sin compras")
	var lost_wave := _play_stage(Strategy.NONE)
	_check(_game_over_report != null and _game_over_report.outcome == WaveReport.Outcome.SLA_ZERO, "sin compras se quiebra por SLA")
	_check(lost_wave == 2, "sin compras se pierde en la oleada 2 (perdió en la %d)" % lost_wave)


## 2. Comprando el cuello de botella se llega a la meta al terminar la oleada 4 (con holgura)
## y se termina la oleada 5 con SLA alto. Devuelve el SLA promedio de la etapa.
func _test_bottleneck_strategy_wins() -> float:
	print("\n== Estrategia buena (compra el cuello de botella)")
	var lost_wave := _play_stage(Strategy.BOTTLENECK)
	_check(lost_wave == 0, "la estrategia buena no pierde (perdió en la oleada %d)" % lost_wave)
	_check(_stage_report != null and _stage_report.wave_number == 5, "la etapa 1 se completa al terminar la oleada 5")
	var wave_4 := _find_report(4)
	if wave_4 != null:
		var slack := float(wave_4.stage_users_served) / wave_4.stage_user_goal
		print("   Al terminar la oleada 4: %d / %d usuarios (%.0f %% de la meta)" % [wave_4.stage_users_served, wave_4.stage_user_goal, slack * 100.0])
		_check(slack >= MIN_GOAL_SLACK_AT_WAVE_4 and slack <= MAX_GOAL_SLACK_AT_WAVE_4,
			"al terminar la oleada 4 se tiene la meta con 15–40 %% de holgura (%.0f %%)" % (slack * 100.0))
	if _stage_report == null:
		return 0.0
	print("   Etapa completada: usuarios %d/%d, SLA final %.1f, SLA promedio %.1f, latencia promedio %.0f ms, %d estrellas, monedas al final %d" % [
		_stage_report.stage_users_served, _stage_report.stage_user_goal, _stage_report.sla_end, _stage_report.stage_avg_sla,
		_stage_report.stage_avg_latency_ms, _stage_report.stars, _sim.get("coins")])
	_check(_stage_report.sla_end >= GOOD_FINAL_SLA, "la estrategia buena termina la oleada 5 con SLA alto (%.1f)" % _stage_report.sla_end)
	_check(_sim.get("stage").id == &"scale_up", "después de la victoria la etapa es Scale-up")
	return _stage_report.stage_avg_sla


## La estrategia buena sigue con las etapas 2 y 3: su balance fino está pendiente,
## pero se comprueba que sigan siendo ganables.
func _report_later_stages() -> void:
	_sim.call("acknowledge_stage_report")
	for stage_name: String in ["Scale-up", "Enterprise"]:
		print("\n== %s con la estrategia buena" % stage_name)
		_stage_report = null
		_game_over_report = null
		_stage_failed_report = null
		var lost_wave := _play_current_stage(Strategy.BOTTLENECK)
		_check(lost_wave == 0 and _stage_report != null, "%s se puede ganar con la estrategia buena" % stage_name)
		if _stage_report == null:
			return
		print("   Etapa completada: usuarios %d/%d, SLA promedio %.1f, %d estrellas" % [
			_stage_report.stage_users_served, _stage_report.stage_user_goal, _stage_report.stage_avg_sla, _stage_report.stars])
		_sim.call("acknowledge_stage_report")


## 3. Comprando siempre lo más barato el SLA sufre: se gana con SLA más bajo o se quiebra,
## pero nunca se pierde "por meta".
func _test_cheapest_strategy_suffers(good_avg_sla: float) -> void:
	print("\n== Estrategia mediocre (compra siempre lo más barato)")
	var lost_wave := _play_stage(Strategy.CHEAPEST)
	_check(_stage_failed_report == null, "la estrategia mediocre no pierde por meta")
	if lost_wave > 0:
		print("   Quebró en la oleada %d (causa: %s)" % [lost_wave, _game_over_report.get_main_cause()])
		_check(_game_over_report.outcome == WaveReport.Outcome.SLA_ZERO, "si la mediocre pierde, es por SLA")
		return
	if _stage_report != null:
		print("   Ganó apenas: usuarios %d/%d, SLA final %.1f, SLA promedio %.1f, %d estrellas" % [
			_stage_report.stage_users_served, _stage_report.stage_user_goal, _stage_report.sla_end, _stage_report.stage_avg_sla, _stage_report.stars])
		_check(_stage_report.stage_avg_sla < good_avg_sla, "la mediocre tiene peor SLA promedio que la buena")


## Meta no alcanzada no es quiebra: "Repetir etapa" vuelve a la oleada 1 con las monedas del inicio de la etapa.
func _test_goal_missed_and_repeat_stage() -> void:
	_stage_failed_report = null
	_game_over_report = null
	_sim.call("set_seed", SEED)
	_sim.call("load_checkpoint", {"stage": "startup", "wave": 5, "coins": 777, "users_served": 0})
	_sim.call("start_wave")
	_set_huge_server_capacity()
	(_sim.get("db") as DbState).iops = 1e6
	_sim.call("run_for", 1000.0)
	_check(_sim.get("phase") == PHASE_STAGE_FAILED, "terminar la oleada 5 sin la meta da Meta no alcanzada (fase %d)" % _sim.get("phase"))
	_check(_game_over_report == null, "no alcanzar la meta no es quiebra")
	_check(_stage_failed_report != null and _stage_failed_report.outcome == WaveReport.Outcome.GOAL_MISSED, "el reporte dice meta no alcanzada")
	_sim.call("purchase", &"ram")
	_sim.call("repeat_stage")
	_check(_sim.get("phase") == PHASE_RUNNING and _sim.get("wave_number") == 1, "Repetir etapa vuelve a la oleada 1")
	_check(_sim.get("coins") == 777 and _sim.call("get_level", &"ram") == 0, "Repetir etapa restaura las monedas y mejoras del inicio de la etapa")
	_check(_sim.get("users_served") == 0, "Repetir etapa reinicia los usuarios")


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


## 5. El firewall deja pasar lo que no filtra (100 % − firewall_filter_pct de la etapa) y suma latencia.
func _test_firewall() -> void:
	var off := _ddos_sample(false)
	var on := _ddos_sample(true)
	var passes := 1.0 - (_sim.call("load_stage", &"enterprise") as StageData).firewall_filter_pct / 100.0
	_check(off.x > 0.0, "la oleada de prueba tiene DDoS")
	_check(absf(on.x / off.x - passes) < 0.01, "con firewall llega el %.0f %% del tráfico malicioso (llegó %.1f %%)" % [passes * 100.0, on.x / off.x * 100.0])
	_check(absf(on.y - off.y - 15.0) < 1.0, "el firewall suma ~15 ms de latencia (sumó %.1f ms)" % (on.y - off.y))


## Las mejoras que lista cada etapa en `unlocks` coinciden con su `unlock_stage`.
func _test_stage_unlocks_match_upgrades() -> void:
	for stage_id: StringName in Paths.STAGE_ORDER:
		var stage: StageData = _sim.call("load_stage", stage_id)
		for upgrade_id: StringName in stage.unlocks:
			var upgrade: UpgradeData = _sim.call("get_upgrade", upgrade_id)
			_check(upgrade != null and upgrade.unlock_stage == stage.number, "%s se desbloquea en la etapa %d" % [upgrade_id, stage.number])


#region Ayudantes

## Juega la etapa 1 completa desde una partida nueva. Devuelve la oleada en que quebró (0 = no quebró).
func _play_stage(strategy: Strategy) -> int:
	_new_game()
	return _play_current_stage(strategy)


func _play_current_stage(strategy: Strategy) -> int:
	_reports.clear()
	for wave_index in _sim.call("get_wave_count"):
		_sim.call("start_wave")
		var steps := 0
		while _sim.get("phase") == PHASE_RUNNING:
			if steps % DECISION_STEPS == 0:
				_buy(strategy)
			_sim.call("step")
			steps += 1
		var report: WaveReport = _sim.get("report")
		_print_wave(report)
		if _sim.get("phase") == PHASE_GAME_OVER:
			return report.wave_number
		if _stage_report != null or _sim.get("phase") == PHASE_STAGE_FAILED:
			return 0
		_buy(strategy)
	return 0


func _buy(strategy: Strategy) -> void:
	match strategy:
		Strategy.BOTTLENECK:
			_buy_bottleneck()
		Strategy.CHEAPEST:
			_buy_cheapest()


## Estrategia buena: respaldo si el disco se está llenando, firewall si hay DDoS
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


## Estrategia mediocre: la mejora más barata que alcance, sea cual sea.
func _buy_cheapest() -> void:
	var cheapest: UpgradeData = null
	for upgrade: UpgradeData in _sim.call("get_upgrades"):
		if _sim.call("can_purchase", upgrade):
			if cheapest == null or _sim.call("get_cost", upgrade) < _sim.call("get_cost", cheapest):
				cheapest = upgrade
	if cheapest != null:
		_sim.call("purchase", cheapest.id)


func _find_report(wave_number: int) -> WaveReport:
	for report: WaveReport in _reports:
		if report.wave_number == wave_number:
			return report
	return null


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
	_stage_failed_report = null
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


## Corre la oleada 1 de Enterprise hasta la cima del primer pico de DDoS.
## Devuelve (malicioso que llega al servidor, latencia).
func _ddos_sample(firewall_on: bool) -> Vector2:
	_sim.call("set_seed", SEED)
	_sim.call("load_checkpoint", {"stage": "enterprise", "wave": 1, "upgrade_levels": {"firewall": 1}, "firewall_on": firewall_on})
	_sim.call("start_wave")
	_set_huge_server_capacity()
	var db: DbState = _sim.get("db")
	db.iops = 1e6
	var attack: Vector3 = (_sim.get("ddos_spikes") as Array)[0]
	_sim.call("run_for", attack.x + attack.y * 0.5)
	var web: ServerState = (_sim.get("servers") as Array)[0]
	var snapshot: SimSnapshot = _sim.get("last_snapshot")
	return Vector2(web.malicious_rps, snapshot.latency_ms)


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)

#endregion
