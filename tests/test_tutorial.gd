extends SceneTree
## Pruebas del tutorial de Briseida y BYTE: guion (data/tutorial/tutorial_steps.json), busto y expresiones,
## estado guardado (solo partidas nuevas, saltar, repetir desde Ajustes) y el recorrido completo en el
## cuarto y el dashboard: caja de Briseida, pasos de acción con "TAP", globo de BYTE, pausa de la simulación
## y pasos que esperan el fin de la oleada.
## Uso: godot --headless --path . -s res://tests/test_tutorial.gd -- --save-path=user://test_tutorial.cfg
## Nota: con -s los autoloads se registran después de compilar este script, así que aquí no se usan como
## identificadores globales (se piden con root.get_node y se llaman con call()).

const PHASE_READY := 1
const PHASE_RUNNING := 2
const PHASE_BETWEEN_WAVES := 3
const MAX_WAVE_STEPS := 5000
const STEP_COUNT := 8
const BUST_SIZE := Vector2i(533, 800)

var _failures: Array[String] = []
var _game_state: Node
var _save_system: Node
var _simulation: Node
var _tutorial: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game_state = root.get_node("GameState")
	_save_system = root.get_node("SaveSystem")
	_simulation = root.get_node("Simulation")
	_tutorial = root.get_node("Tutorial")
	if _save_system.call("is_using_real_save"):
		printerr("test_tutorial: corre la prueba con una partida alterna para no tocar la real, p. ej.: -- --save-path=user://test_tutorial.cfg")
		quit(1)
		return
	_save_system.call("delete_save")

	_test_script()
	_test_bust_art()
	_test_state_machine()
	_test_save_and_old_saves()
	await _test_walkthrough()
	await _test_not_shown_for_old_saves()
	await _test_replay_from_settings()
	await _test_skip_in_dashboard()

	_save_system.call("delete_save")
	if _failures.is_empty():
		print("TEST TUTORIAL OK")
		quit(0)
	else:
		printerr("TEST TUTORIAL FALLÓ:\n- " + "\n- ".join(_failures))
		quit(1)


#region Guion y arte

func _test_script() -> void:
	var steps: Array[TutorialStep] = TutorialStep.load_all()
	_check(steps.size() == STEP_COUNT, "el guion tiene %d pasos (%d)" % [STEP_COUNT, steps.size()])
	var ids := {}
	var has_byte := false
	var has_action := false
	var has_wait := false
	var expressions := {}
	for step: TutorialStep in steps:
		var problems := step.validate()
		_check(problems.is_empty(), "paso válido: %s" % ", ".join(problems))
		_check(not ids.has(step.id), "id repetido: %s" % step.id)
		ids[step.id] = true
		has_byte = has_byte or step.is_byte()
		has_action = has_action or step.needs_action()
		has_wait = has_wait or step.wait_for != &""
		if not step.is_byte():
			expressions[step.expression] = true
		_check(step.text.length() <= 260, "el texto de %s cabe en la caja (%d caracteres)" % [step.id, step.text.length()])
	_check(has_byte and has_action and has_wait, "el guion tiene un paso de BYTE, uno de acción y uno que espera el fin de la oleada")
	_check(expressions.has(&"normal") and expressions.has(&"contenta") and expressions.has(&"preocupada"), "el guion usa las 3 expresiones")
	# Recorrido por escenas: cuarto → dashboard, sin volver atrás.
	var in_dashboard := false
	for step: TutorialStep in steps:
		if step.scene == TutorialStep.SCENE_DASHBOARD:
			in_dashboard = true
		_check(not (in_dashboard and step.scene == TutorialStep.SCENE_ROOM), "%s: después de entrar al dashboard no hay pasos del cuarto" % step.id)
	_check(steps[2].action == &"tap_pc" and steps[2].highlight == &"pc", "el tercer paso pide tocar la PC y la resalta")
	_check(steps[3].is_byte(), "BYTE habla en el cuarto paso")

	# Textos con marcadores: se reemplazan {jugador}, {empresa} y el género.
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	var greeting: String = _tutorial.call("format", "Hola {jugador}, bienvenid{o|a} a {empresa}")
	_check(greeting == "Hola Sayola, bienvenido a NexusSoft", "format reemplaza jugador, empresa y género (%s)" % greeting)
	_game_state.call("start_new_game", "Alexa", "NexusSoft", &"alexa")
	greeting = _tutorial.call("format", "bienvenid{o|a}")
	_check(greeting == "bienvenida", "el género sigue al personaje (%s)" % greeting)
	for step: TutorialStep in steps:
		_check(not (_tutorial.call("format", step.text) as String).contains("{"), "%s: no quedan marcadores sin reemplazar" % step.id)


## Los 3 bustos existen con el tamaño esperado, fondo transparente y su silueta de cintura para arriba.
func _test_bust_art() -> void:
	for expression: StringName in TutorialStep.EXPRESSIONS:
		var path: String = Paths.CEO_BUST % expression
		var texture := load(path) as Texture2D
		_check(texture != null, "existe el busto %s" % path)
		if texture == null:
			continue
		_check(texture.get_size() == Vector2(BUST_SIZE), "%s mide %s (%s)" % [expression, BUST_SIZE, texture.get_size()])
		var image := texture.get_image()
		_check(image.get_pixel(2, 2).a == 0.0 and image.get_pixel(BUST_SIZE.x - 3, 2).a == 0.0, "%s: el fondo es transparente" % expression)
		_check(image.get_pixel(BUST_SIZE.x / 2, BUST_SIZE.y - 3).a == 1.0, "%s: el cuerpo llega al borde de abajo (cintura)" % expression)

#endregion


#region Estado

func _test_state_machine() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	_check(_game_state.get("tutorial_step") == 0 and _tutorial.call("is_active"), "una partida nueva empieza el tutorial")
	var step: TutorialStep = _tutorial.call("current")
	_check(step != null and step.id == &"bienvenida", "el primer paso es la bienvenida")

	# Una acción que el paso no espera no hace nada.
	_tutorial.call("notify_action", &"tap_pc")
	_check(_game_state.get("tutorial_step") == 0, "tocar la PC no avanza un paso de lectura")
	_tutorial.call("advance")
	_tutorial.call("advance")
	_check((_tutorial.call("current") as TutorialStep).id == &"toca_pc", "dos avances llegan a 'toca la PC'")
	_tutorial.call("notify_action", &"buy_upgrade")
	_check(_game_state.get("tutorial_step") == 2, "comprar no completa el paso de la PC")
	_tutorial.call("notify_action", &"tap_pc")
	_check((_tutorial.call("current") as TutorialStep).id == &"trafico", "tocar la PC avanza a BYTE")

	# El paso de la mejora se completa comprando o terminando la oleada.
	_game_state.set("tutorial_step", 5)
	_tutorial.call("notify_action", &"buy_upgrade")
	_check((_tutorial.call("current") as TutorialStep).id == &"alerta", "comprar completa el paso de la mejora")
	_game_state.set("tutorial_step", 5)
	_tutorial.call("notify_action", &"wave_finished")
	_check((_tutorial.call("current") as TutorialStep).id == &"alerta", "terminar la oleada también completa el paso de la mejora")
	_tutorial.call("notify_action", &"wave_finished")
	_check(_game_state.get("tutorial_step") == 6, "el paso de alerta no se completa con el evento (solo espera)")

	# Pasos que esperan el fin de la oleada.
	var alert: TutorialStep = _tutorial.call("current")
	_simulation.call("new_game")
	_check(not _tutorial.call("is_ready", alert), "la alerta no está lista con la oleada sin empezar")
	_simulation.call("start_wave")
	_check(not _tutorial.call("is_ready", alert), "la alerta no está lista con la oleada en curso")
	_run_wave()
	_check(_simulation.get("phase") != PHASE_RUNNING and _tutorial.call("is_ready", alert), "la alerta está lista al terminar la oleada")

	# Saltar y terminar.
	var finished: Array = []
	_tutorial.connect("finished", func(skipped: bool) -> void: finished.append(skipped))
	_tutorial.call("skip")
	_check(_game_state.get("tutorial_step") == -1 and not _tutorial.call("is_active") and finished == [true], "saltar termina el tutorial")
	_tutorial.call("advance")
	_tutorial.call("notify_action", &"tap_pc")
	_check(_game_state.get("tutorial_step") == -1, "terminado, avanzar o notificar no lo revive")
	_tutorial.call("start")
	_check(_game_state.get("tutorial_step") == 0, "start() lo repite desde el principio")
	_game_state.set("tutorial_step", STEP_COUNT - 1)
	_tutorial.call("advance")
	_check(_game_state.get("tutorial_step") == -1 and finished == [true, false], "pasar del último paso lo termina sin saltarlo")
	# Sin partida activa no hay tutorial.
	_game_state.call("end_session")
	_game_state.set("tutorial_step", 0)
	_check(not _tutorial.call("is_active"), "sin partida no hay tutorial")


func _test_save_and_old_saves() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	_tutorial.call("advance")
	_tutorial.call("advance")
	_check(_save_system.call("save_game") and _save_system.call("load_game"), "guardar y cargar a medio tutorial")
	_check(_game_state.get("tutorial_step") == 2, "el paso del tutorial se guarda con la partida")
	_tutorial.call("skip")
	_check(_save_system.call("load_game") and _game_state.get("tutorial_step") == -1, "saltar el tutorial también se guarda")

	# Una partida guardada antes del tutorial no trae la clave: no lo ve.
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	_check(_save_system.call("save_game"), "guardar partida nueva")
	var config := ConfigFile.new()
	config.load(_save_system.get("save_path"))
	config.erase_section_key("player", "tutorial_step")
	config.save(_save_system.get("save_path"))
	_check(_save_system.call("load_game"), "cargar una partida sin la clave del tutorial")
	_check(_game_state.get("tutorial_step") == -1 and not _tutorial.call("is_active"), "una partida anterior al tutorial no lo ve")
	# Valores raros se corrigen.
	_game_state.call("restore", {"tutorial_step": -7})
	_check(_game_state.get("tutorial_step") == -1, "un paso inválido se corrige")

#endregion


#region Recorrido

func _test_walkthrough() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	var garage: Node = (load("res://scenes/rooms/garage.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	await _frames(3)
	var overlay: Node = garage.get_node("%TutorialOverlay")

	# 1 · Bienvenida: Briseida contenta, busto visible, caja que bloquea y texto que se escribe.
	_check(overlay.call("is_box_visible") and overlay.call("is_bust_visible"), "paso 1: se ven la caja y el busto")
	_check(overlay.call("get_expression") == &"contenta", "paso 1: Briseida contenta")
	_check(overlay.call("is_blocking") and not overlay.call("is_compact"), "paso 1: la caja bloquea la pantalla")
	_check((overlay.call("get_text") as String).begins_with("¡Hola, Sayola! Soy Briseida, la CEO de NexusSoft."), "paso 1: el texto usa el nombre y la empresa (%s)" % overlay.call("get_text"))
	_check(overlay.call("is_typing"), "paso 1: el texto se escribe poco a poco")
	_check(not overlay.call("is_highlighting"), "paso 1: sin recuadro")
	var bust_size := ((overlay.get("_bust") as TextureRect).size)
	var viewport_height := garage.get_viewport().get_visible_rect().size.y
	_check(is_equal_approx(bust_size.y, viewport_height * 0.7), "el busto mide el 70 %% del alto de pantalla (%s de %s)" % [bust_size.y, viewport_height])
	var bust_position := (overlay.get("_bust") as TextureRect).position
	_check(bust_position.x < viewport_height * 0.1 and is_equal_approx(bust_position.y + bust_size.y, viewport_height), "el busto está a la izquierda y pegado abajo (%s)" % bust_position)
	var box := overlay.get("_box") as PanelContainer
	_check(box.position.x > bust_size.x * 0.5 and box.position.x < bust_size.x, "la caja empieza dentro del ancho del busto (se solapan un poco): %s" % box.position.x)
	_check(box.get_rect().end.x <= garage.get_viewport().get_visible_rect().size.x - 100.0, "la caja deja libre el engranaje de Ajustes")

	# Tocar completa el texto; tocar otra vez avanza.
	overlay.call("tap")
	_check(not overlay.call("is_typing") and _game_state.get("tutorial_step") == 0, "el primer toque completa el texto sin avanzar")
	overlay.call("tap")
	await _frames(2)
	_check(_game_state.get("tutorial_step") == 1 and overlay.call("get_expression") == &"normal", "el segundo toque avanza a la expresión normal")
	overlay.call("tap")
	overlay.call("tap")
	await _frames(2)

	# 3 · Toca la PC: caja pequeña, sin busto, con recuadro; los toques pasan.
	_check(_game_state.get("tutorial_step") == 2, "paso 3: toca la PC")
	_check(overlay.call("is_compact") and not overlay.call("is_bust_visible") and not overlay.call("is_blocking"), "paso 3: caja pequeña, sin busto y sin bloquear")
	_check(overlay.call("is_highlighting"), "paso 3: la PC está resaltada con TAP")
	var pc_rect: Rect2 = garage.call("_get_pc_highlight_rect")
	_check(pc_rect.size.x > 0.0 and pc_rect.size.y > 0.0, "el recuadro de la PC tiene tamaño")
	_check(overlay.get("_skip_step_button").visible, "paso 3: se puede omitir el paso")

	# Tocar la PC: el tutorial avanza y la escena se va al dashboard.
	garage.call("_enter_monitor")
	_check(_game_state.get("tutorial_step") == 3, "tocar la PC avanza al paso de BYTE")
	await _frames(2)
	_check(not overlay.call("is_box_visible"), "el cuarto esconde el tutorial mientras hace zoom")
	garage.free()
	await _frames(2)

	# 4 · BYTE en el dashboard: su globo, simulación en pausa.
	var dashboard: Node = (load(Paths.DASHBOARD) as PackedScene).instantiate()
	root.add_child(dashboard)
	await _frames(3)
	var overlay_d: Node = dashboard.get_node("%TutorialOverlay")
	var byte: Control = dashboard.get_node("%ByteBubble")
	_check(_simulation.get("phase") == PHASE_RUNNING, "el dashboard arranca la oleada 1")
	_check(byte.visible and byte.call("is_showing_tutorial") and (byte.call("get_text") as String).begins_with("Soy BYTE"), "paso 4: BYTE se presenta con su globo (%s)" % byte.call("get_text"))
	_check(not overlay_d.call("is_box_visible") and not overlay_d.call("is_bust_visible"), "paso 4: Briseida no aparece cuando habla BYTE")
	_check(_simulation.get("paused") and overlay_d.call("is_pausing_simulation"), "paso 4: la simulación espera mientras se lee")
	var wave_time_before: float = _simulation.get("wave_time")
	for i in 20:
		_simulation.call("_physics_process", 0.1)
	_check(is_equal_approx(_simulation.get("wave_time"), wave_time_before), "en pausa el tiempo de la oleada no corre")

	# BYTE se cierra con su OK → paso 5.
	(byte.get_node("%CloseButton") as Button).pressed.emit()
	await _frames(2)
	_check(_game_state.get("tutorial_step") == 4 and not byte.visible, "el OK de BYTE avanza el tutorial y cierra el globo (paso %s, visible %s, texto %s)" % [_game_state.get("tutorial_step"), byte.visible, byte.call("get_text")])

	# 5 · SLA: Briseida con el bloque de salud resaltado, simulación en pausa.
	_check(overlay_d.call("is_box_visible") and overlay_d.call("is_bust_visible") and overlay_d.call("get_expression") == &"normal", "paso 5: Briseida normal con su busto")
	_check(overlay_d.call("is_highlighting") and overlay_d.call("is_blocking"), "paso 5: resalta el SLA y espera un toque")
	_check(_simulation.get("paused"), "paso 5: la simulación sigue en pausa")
	overlay_d.call("tap")
	overlay_d.call("tap")
	await _frames(2)

	# 6 · Mejora: caja pequeña, consola resaltada, la simulación corre otra vez.
	_check(_game_state.get("tutorial_step") == 5, "paso 6: compra una mejora")
	_check(overlay_d.call("is_compact") and overlay_d.call("is_highlighting") and not overlay_d.call("is_blocking"), "paso 6: caja pequeña con la consola resaltada")
	_check(not _simulation.get("paused") and not overlay_d.call("is_pausing_simulation"), "paso 6: la simulación vuelve a correr")
	var affordable: StringName = &""
	for upgrade: Resource in _simulation.call("get_upgrades"):
		if _simulation.call("can_purchase", upgrade):
			affordable = upgrade.get("id")
			break
	_check(affordable != &"", "hay una mejora que se puede comprar con las monedas iniciales")
	dashboard.call("_on_purchase_requested", affordable)
	await _frames(2)
	_check(_game_state.get("tutorial_step") == 6, "comprar completa el paso de la mejora")
	_check(not overlay_d.call("is_box_visible"), "paso 7: espera a que termine la oleada (no se muestra todavía)")
	_check(not byte.visible and byte.call("get_text") == "", "BYTE no suelta consejos viejos tras comprar la mejora")

	# 7 · Alerta: al terminar la oleada aparece Briseida preocupada sobre el post-mortem.
	_run_wave()
	await _frames(3)
	_check(_simulation.get("phase") == PHASE_BETWEEN_WAVES, "la oleada 1 terminó (fase %d)" % _simulation.get("phase"))
	_check(overlay_d.call("is_box_visible") and overlay_d.call("get_expression") == &"preocupada", "paso 7: Briseida preocupada al terminar la oleada")
	_check(overlay_d.call("is_blocking") and (overlay_d.call("get_text") as String).contains("«!!»"), "paso 7: explica el «!!» y bloquea hasta tocar (%s)" % overlay_d.call("get_text"))
	overlay_d.call("tap")
	overlay_d.call("tap")
	await _frames(2)

	# 8 · Cierre: contenta; al terminar el tutorial ya no aparece.
	_check(_game_state.get("tutorial_step") == 7 and overlay_d.call("get_expression") == &"contenta", "paso 8: Briseida contenta")
	overlay_d.call("tap")
	overlay_d.call("tap")
	await _frames(2)
	_check(_game_state.get("tutorial_step") == -1 and not overlay_d.call("is_box_visible") and not overlay_d.call("is_bust_visible"), "al terminar el tutorial todo desaparece")
	_check(not overlay_d.call("is_pausing_simulation"), "el tutorial no deja la simulación en pausa")
	dashboard.free()
	await _frames(2)

	# Terminado, el cuarto y el dashboard ya no muestran nada.
	garage = (load("res://scenes/rooms/garage.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	await _frames(3)
	_check(not garage.get_node("%TutorialOverlay").call("is_box_visible"), "con el tutorial terminado el cuarto no muestra nada")
	garage.free()
	await _frames(2)

	# Saltarlo desde la caja.
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	garage = (load("res://scenes/rooms/garage.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	await _frames(3)
	var skip := garage.get_node("%TutorialOverlay").get("_skip_button") as Button
	_check(skip.is_visible_in_tree(), "'Saltar tutorial' se ve en la caja")
	skip.pressed.emit()
	await _frames(2)
	_check(_game_state.get("tutorial_step") == -1 and not garage.get_node("%TutorialOverlay").call("is_box_visible"), "'Saltar tutorial' lo termina y esconde la caja")
	garage.free()
	await _frames(2)

	# Salir del dashboard a medio tutorial: el cuarto avisa que hay que volver a la PC.
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	_game_state.set("tutorial_step", 4)
	garage = (load("res://scenes/rooms/garage.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	await _frames(3)
	var overlay_g: Node = garage.get_node("%TutorialOverlay")
	_check(overlay_g.call("is_box_visible") and overlay_g.call("is_compact") and (overlay_g.call("get_text") as String).contains("Vuelve a la computadora"), "a medio tutorial el cuarto pide volver a la PC (%s)" % overlay_g.call("get_text"))
	_check(overlay_g.call("is_highlighting") and not overlay_g.call("is_blocking"), "el aviso resalta la PC y deja pasar el toque")
	garage.free()
	await _frames(2)


## Una partida guardada antes del tutorial no lo ve ni en el cuarto ni en el dashboard.
func _test_not_shown_for_old_saves() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	_game_state.set("tutorial_step", -1)
	for path: String in ["res://scenes/rooms/garage.tscn", Paths.DASHBOARD]:
		var scene: Node = (load(path) as PackedScene).instantiate()
		root.add_child(scene)
		await _frames(3)
		var overlay: Node = scene.get_node("%TutorialOverlay")
		_check(not overlay.call("is_box_visible") and not overlay.call("is_bust_visible") and not overlay.call("is_highlighting"), "%s: una partida sin tutorial no muestra nada" % path)
		_check(not _simulation.get("paused"), "%s: una partida sin tutorial no se pausa" % path)
		scene.free()
		await _frames(2)


## "Ver tutorial otra vez" en Ajustes: aparece en la partida, no en el menú de título, y lo reinicia.
func _test_replay_from_settings() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	_tutorial.call("skip")
	var menu: Control = (load("res://scenes/ui/settings_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await _frames(2)
	var button := menu.get("_tutorial_button") as Button
	menu.call("open", false, false)
	_check(not button.visible, "el menú de título no ofrece repetir el tutorial")
	menu.call("open", true, true)
	_check(button.visible and button.text == "Ver tutorial otra vez", "en la partida, Ajustes ofrece 'Ver tutorial otra vez'")
	var requested: Array = []
	menu.connect("tutorial_replay_requested", func() -> void: requested.append(true))
	button.pressed.emit()
	_check(_game_state.get("tutorial_step") == 0 and _tutorial.call("is_active"), "repetirlo reinicia el tutorial en el primer paso")
	_game_state.set("tutorial_step", -1)
	_check(_save_system.call("load_game") and _game_state.get("tutorial_step") == 0, "repetirlo se guarda: al reabrir la app sigue en el primer paso")
	_check(requested.size() == 1 and not menu.visible, "repetirlo cierra Ajustes y avisa")
	# Se puede repetir a mitad de la partida: el recorrido vuelve a empezar en el cuarto.
	_simulation.call("start_wave")
	var garage: Node = (load("res://scenes/rooms/garage.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	await _frames(3)
	_check(garage.get_node("%TutorialOverlay").call("is_box_visible") and garage.get_node("%TutorialOverlay").call("get_expression") == &"contenta", "al repetirlo, Briseida vuelve a saludar en el cuarto")
	garage.free()
	menu.free()
	await _frames(2)

## Saltar el tutorial en plena oleada 1 del dashboard: BYTE se presenta (el tutorial ya no lo hará).
func _test_skip_in_dashboard() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	_game_state.set("tutorial_step", 4)
	var dashboard: Node = (load(Paths.DASHBOARD) as PackedScene).instantiate()
	root.add_child(dashboard)
	await _frames(3)
	var byte: Control = dashboard.get_node("%ByteBubble")
	_check(not byte.visible, "con el tutorial activo BYTE no repite el texto de la oleada")
	_tutorial.call("skip")
	await _frames(3)
	_check(byte.visible and (byte.call("get_text") as String).begins_with("¡Hola! Soy BYTE."), "al saltar el tutorial BYTE se presenta (%s)" % byte.call("get_text"))
	dashboard.free()
	await _frames(2)

#endregion


func _run_wave() -> void:
	var steps := 0
	while _simulation.get("phase") == PHASE_RUNNING and steps < MAX_WAVE_STEPS:
		_simulation.call("step")
		steps += 1


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
