extends SceneTree
## Prueba de humo: instancia todas las escenas y recorre el flujo completo sin ventana:
## título → nombres → garage → pincel → PC → dashboard → comprar → post-mortem → siguiente oleada
## → game over → reintentar → volver al cuarto → continuar.
## Uso: godot --headless --path . -s res://tests/smoke_test.gd
## Usa un archivo de guardado propio para no tocar la partida real.
## Nota: con -s los autoloads se registran después de compilar este script, así que aquí
## no se usan como identificadores globales ni se tipan clases que dependan de ellos.

const TEST_SAVE_PATH := "user://smoke_test_save.cfg"
const PHASE_READY := 1
const PHASE_RUNNING := 2
const PHASE_GAME_OVER := 4
## Tope de pasos para terminar una oleada en la prueba.
const MAX_WAVE_STEPS := 5000
const SCENES: Array[String] = [
	Paths.TITLE_MENU,
	Paths.LOADING_SCREEN,
	Paths.NEW_GAME_SETUP,
	Paths.DASHBOARD,
	"res://scenes/ui/hud.tscn",
	"res://scenes/ui/customize_panel.tscn",
	"res://scenes/characters/avatar.tscn",
	"res://scenes/rooms/garage.tscn",
	"res://scenes/dashboard/postmortem.tscn",
	"res://scenes/dashboard/game_over.tscn",
	"res://scenes/dashboard/victory.tscn",
	"res://scenes/dashboard/upgrade_button.tscn",
	"res://scenes/dashboard/traffic_node.tscn",
	"res://scenes/dashboard/byte_bubble.tscn",
]

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("GameState")
	var save_system: Node = root.get_node("SaveSystem")
	var simulation: Node = root.get_node("Simulation")
	var customization: Node = root.get_node("Customization")
	save_system.set("save_path", TEST_SAVE_PATH)
	save_system.call("delete_save")

	# Catálogo
	_check(customization.call("get_options", &"pared_izq").size() == 10, "10 colores de pared izquierda")
	_check(customization.call("get_options", &"pared_der").size() == 10, "10 colores de pared derecha")
	_check(customization.call("get_options", &"piso").size() == 3, "3 pisos")
	_check(customization.call("get_options", &"puerta").size() == 6, "6 puertas")
	_check(customization.call("get_options", &"mesa").size() == 3, "3 mesas")
	for layer: StringName in customization.get("LAYER_ORDER"):
		for option: CustomizationOption in customization.call("get_options", layer):
			var path: String = customization.call("get_layer_texture_path", &"garage", layer, option.id)
			_check(ResourceLoader.exists(path), "existe %s" % path)

	# Partida nueva, guardado y carga
	game_state.call("start_new_game", "Prueba", "TestCorp")
	_check(game_state.get("colors")[&"piso"] == &"concreto_calido", "piso por defecto")
	_check(game_state.get("colors")[&"puerta"] == &"madera_natural", "puerta por defecto")
	game_state.call("set_color", &"pared_izq", &"menta")
	_check(save_system.call("save_game"), "guardar partida")
	game_state.call("set_color", &"pared_izq", &"grafito")
	_check(save_system.call("load_game"), "cargar partida")
	_check(game_state.get("avatar_name") == "Prueba", "nombre del avatar guardado")
	_check(game_state.get("colors")[&"pared_izq"] == &"menta", "color guardado")

	# Id desconocido → valor por defecto
	var sanitized: Dictionary = customization.call("sanitize_colors", {&"mesa": &"no_existe"})
	_check(sanitized[&"mesa"] == &"roble", "id desconocido usa el valor por defecto")

	# Instanciar todas las escenas
	for scene_path: String in SCENES:
		var packed := load(scene_path) as PackedScene
		_check(packed != null, "cargar %s" % scene_path)
		if packed == null:
			continue
		var instance := packed.instantiate()
		root.add_child(instance)
		await process_frame
		instance.queue_free()
		await process_frame

	# Garage: colores en vivo y saturación
	var garage := (load("res://scenes/rooms/garage.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	await process_frame
	var wall: Sprite2D = garage.get_node("%WallLeft")
	game_state.call("set_color", &"pared_izq", &"lavanda")
	_check(wall.texture.resource_path.ends_with("pared_izq/lavanda.png"), "la pared cambia en vivo")

	simulation.call("start_wave")
	simulation.set("overload_enabled", true)
	for i in 15:
		simulation.call("step")
	var rack: Sprite2D = garage.get_node("%Rack")
	var avatar: Avatar = garage.get_node("%Avatar")
	_check(simulation.get("is_saturated"), "la sobrecarga satura el servidor")
	_check(rack.texture.resource_path.ends_with("rack_saturado.png"), "rack saturado")
	_check(avatar.is_stressed(), "Alex estresado")
	simulation.set("overload_enabled", false)
	# La oleada 1 empieza con la red al 90 % (tutorial): con Ancho de banda baja de 85 %.
	_check(simulation.call("purchase", &"bandwidth"), "comprar Ancho de banda desde código")
	for i in 30:
		simulation.call("step")
	_check(not simulation.get("is_saturated"), "la carga regresa a normal")
	_check(rack.texture.resource_path.ends_with("rack_ok.png"), "rack normal")
	garage.queue_free()

	# Filtro de nombres
	var prompt := (load("res://scenes/ui/name_prompt.tscn") as PackedScene).instantiate() as NamePrompt
	root.add_child(prompt)
	await process_frame
	var edit: LineEdit = prompt.get_node("%NameEdit")
	edit.text = "Ana<>María_1!"
	edit.text_changed.emit(edit.text)
	_check(edit.text == "AnaMaría_1", "el filtro quita caracteres no permitidos (%s)" % edit.text)
	edit.text = "   "
	edit.text_changed.emit(edit.text)
	_check(not prompt.is_value_valid(), "solo espacios no es válido")
	prompt.queue_free()

	await _test_full_flow(game_state, save_system, simulation)

	save_system.call("delete_save")
	await process_frame
	if _failures.is_empty():
		print("SMOKE TEST OK")
		quit(0)
	else:
		printerr("SMOKE TEST FALLÓ:\n- " + "\n- ".join(_failures))
		quit(1)


## Recorre el flujo real con las escenas y botones: título → nombres → garage → dashboard → título.
func _test_full_flow(game_state: Node, save_system: Node, simulation: Node) -> void:
	save_system.call("delete_save")
	change_scene_to_file(Paths.TITLE_MENU)
	_check(await _wait_for_scene(&"TitleMenu"), "abre el menú de título")
	_check((current_scene.get_node("%ContinueButton") as Button).disabled, "Continuar deshabilitado sin partida")
	(current_scene.get_node("%NewGameButton") as Button).pressed.emit()
	_check(await _wait_for_scene(&"NewGameSetup", 6.0), "pantalla de carga → nombres")

	var avatar_prompt: NamePrompt = current_scene.get_node("%AvatarPrompt")
	var company_prompt: NamePrompt = current_scene.get_node("%CompanyPrompt")
	_check(avatar_prompt.visible and not company_prompt.visible, "primero se pide el avatar")
	_check((avatar_prompt.get_node("%ConfirmButton") as Button).disabled, "Siguiente deshabilitado con texto vacío")
	_type_name(avatar_prompt, "Said")
	(avatar_prompt.get_node("%ConfirmButton") as Button).pressed.emit()
	_check(company_prompt.visible and not avatar_prompt.visible, "después se pide la empresa")
	(company_prompt.get_node("%BackButton") as Button).pressed.emit()
	_check(avatar_prompt.visible and avatar_prompt.get_value() == "Said", "Atrás conserva el nombre")
	(avatar_prompt.get_node("%ConfirmButton") as Button).pressed.emit()
	_type_name(company_prompt, "Nexus Test")
	(company_prompt.get_node("%ConfirmButton") as Button).pressed.emit()
	_check(await _wait_for_scene(&"Garage"), "Comenzar abre el garage")
	_check(save_system.call("has_save"), "la partida se guardó al comenzar")

	var garage := current_scene
	_check((garage.get_node("%Hud").get_node("%TitleLabel") as Label).text == "Nexus Test · Garage", "HUD con empresa y cuarto")
	_check((garage.get_node("%Avatar").get_node("%NameLabel") as Label).text == "Said", "nombre sobre Alex")

	# Personalizar y cancelar
	var panel: CanvasLayer = garage.get_node("%CustomizePanel")
	(garage.get_node("%Hud").get_node("%BrushButton") as Button).pressed.emit()
	_check(panel.visible and not garage.get("_pc_enabled"), "pincel abre el panel y bloquea la PC")
	var door: Sprite2D = garage.get_node("%Door")
	(panel.get("_swatches")[&"puerta"][&"roja"] as Button).pressed.emit()
	_check(door.texture.resource_path.ends_with("puerta/roja.png"), "la puerta cambia en vivo")
	(panel.get_node("%CancelButton") as Button).pressed.emit()
	_check(door.texture.resource_path.ends_with("puerta/madera_natural.png"), "Cancelar revierte el color")
	_check(game_state.get("colors")[&"puerta"] == &"madera_natural", "Cancelar revierte GameState")
	var door_swatches: Dictionary = panel.get("_swatches")[&"puerta"]
	var pressed_swatches := door_swatches.values().filter(func(swatch: Button) -> bool: return swatch.button_pressed)
	_check(pressed_swatches.size() == 1 and door_swatches[&"madera_natural"].button_pressed, "una sola muestra marcada por capa")

	# Clic en la PC → dashboard → volver
	await create_timer(0.5).timeout
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(garage.get_node("%PcArea") as Area2D).input_event.emit(root, click, 0)
	_check(await _wait_for_scene(&"Dashboard"), "clic en la PC abre el dashboard")
	await _test_dashboard(current_scene, simulation)

	(current_scene.get_node("%BackButton") as Button).pressed.emit()
	_check(await _wait_for_scene(&"Garage"), "Volver al cuarto regresa al garage")
	_check(simulation.get("phase") == PHASE_RUNNING, "la simulación sigue corriendo en el garage (fase %d, oleada %d, SLA %.1f)" % [simulation.get("phase"), simulation.get("wave_number"), simulation.get("sla")])

	change_scene_to_file(Paths.TITLE_MENU)
	_check(await _wait_for_scene(&"TitleMenu"), "regresa al título")
	var continue_button := current_scene.get_node("%ContinueButton") as Button
	_check(not continue_button.disabled, "Continuar habilitado con partida")
	continue_button.pressed.emit()
	_check(await _wait_for_scene(&"Garage"), "Continuar abre el garage")
	_check(simulation.get("phase") == PHASE_READY and simulation.get("wave_number") == 2, "Continuar vuelve al inicio de la oleada 2")
	_check(simulation.call("get_level", &"bandwidth") == 1, "Continuar conserva las mejoras")


## Dashboard: comprar, terminar la oleada (acelerada), post-mortem, siguiente oleada, game over y reintentar.
func _test_dashboard(dashboard: Node, simulation: Node) -> void:
	_check(simulation.get("phase") == PHASE_RUNNING and simulation.get("wave_number") == 1, "el dashboard inicia la oleada 1")
	var monitor: Node = dashboard.get_node("%TrafficMonitor")
	_check(monitor.call("get_server_count") == 1, "el monitor muestra 1 servidor")
	var byte: Control = dashboard.get_node("%ByteBubble")
	_check(byte.visible and str(byte.call("get_text")).contains("BYTE"), "BYTE da el tutorial de la oleada 1")
	await create_timer(0.6).timeout
	_check(monitor.call("get_packet_count") > 0, "viajan paquetes por el monitor")

	var coins: int = simulation.get("coins")
	var bandwidth: Button = dashboard.call("get_upgrade_button", &"bandwidth")
	_check(bandwidth.call("is_highlighted"), "el botón del cuello de botella (Ancho de banda) está resaltado")
	_check(not bandwidth.disabled, "Ancho de banda se puede comprar")
	bandwidth.pressed.emit()
	_check(simulation.call("get_level", &"bandwidth") == 1 and simulation.get("coins") < coins, "comprar Ancho de banda desde la consola")
	var cache: Button = dashboard.call("get_upgrade_button", &"cache")
	_check(cache.disabled, "Optimizar caché está bloqueada en la etapa 1")

	_finish_wave(simulation)
	await process_frame
	var postmortem: Control = dashboard.get_node("%Postmortem")
	_check(postmortem.visible, "al terminar la oleada aparece el post-mortem")
	_check(not (postmortem.get_node("%Summary").get_node("%CauseText") as Label).text.is_empty(), "el post-mortem explica la causa")
	(postmortem.get_node("%NextButton") as Button).pressed.emit()
	await process_frame
	_check(simulation.get("phase") == PHASE_RUNNING and simulation.get("wave_number") == 2, "Siguiente oleada inicia la oleada 2")
	_check(not postmortem.visible, "el post-mortem se cierra")

	# Game over forzado y reintento
	simulation.set("sla", 0.5)
	simulation.set("overload_enabled", true)
	_finish_wave(simulation)
	simulation.set("overload_enabled", false)
	await process_frame
	var game_over: Control = dashboard.get_node("%GameOver")
	_check(simulation.get("phase") == PHASE_GAME_OVER and game_over.visible, "con SLA en 0 aparece el game over")
	_check((game_over.get_node("%TitleLabel") as Label).text == "Nexus Test quebró", "el game over dice que la empresa quebró")
	(game_over.get_node("%RetryButton") as Button).pressed.emit()
	await process_frame
	_check(simulation.get("phase") == PHASE_RUNNING and simulation.get("wave_number") == 2, "Reintentar vuelve a empezar la oleada 2")
	_check(not game_over.visible, "el game over se cierra")


func _finish_wave(simulation: Node) -> void:
	var steps := 0
	while simulation.get("phase") == PHASE_RUNNING and steps < MAX_WAVE_STEPS:
		simulation.call("step")
		steps += 1


func _type_name(prompt: NamePrompt, value: String) -> void:
	var edit: LineEdit = prompt.get_node("%NameEdit")
	edit.text = value
	edit.text_changed.emit(value)


func _wait_for_scene(scene_name: StringName, timeout_seconds: float = 3.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var router: Node = root.get_node("SceneRouter")
		if current_scene != null and current_scene.name == scene_name and not router.call("is_changing"):
			return true
	return false


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
