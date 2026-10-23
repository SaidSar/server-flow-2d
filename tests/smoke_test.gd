extends SceneTree
## Prueba de humo: instancia todas las escenas y recorre la lógica principal sin ventana.
## Uso: godot --headless --path . -s res://tests/smoke_test.gd
## Usa un archivo de guardado propio para no tocar la partida real.
## Nota: con -s los autoloads se registran después de compilar este script, así que aquí
## no se usan como identificadores globales ni se tipan clases que dependan de ellos.

const TEST_SAVE_PATH := "user://smoke_test_save.cfg"
const SCENES: Array[String] = [
	Paths.TITLE_MENU,
	Paths.LOADING_SCREEN,
	Paths.NEW_GAME_SETUP,
	Paths.DASHBOARD,
	"res://scenes/ui/hud.tscn",
	"res://scenes/ui/customize_panel.tscn",
	"res://scenes/characters/avatar.tscn",
	"res://scenes/rooms/garage.tscn",
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

	simulation.call("stop")
	simulation.call("set_overload", true)
	for i in 15:
		simulation.call("step")
	var rack: Sprite2D = garage.get_node("%Rack")
	var avatar: Avatar = garage.get_node("%Avatar")
	_check(simulation.get("is_saturated"), "la sobrecarga satura el servidor")
	_check(rack.texture.resource_path.ends_with("rack_saturado.png"), "rack saturado")
	_check(avatar.is_stressed(), "Alex estresado")
	simulation.call("set_overload", false)
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

	await _test_full_flow(game_state, save_system)

	save_system.call("delete_save")
	await process_frame
	if _failures.is_empty():
		print("SMOKE TEST OK")
		quit(0)
	else:
		printerr("SMOKE TEST FALLÓ:\n- " + "\n- ".join(_failures))
		quit(1)


## Recorre el flujo real con las escenas y botones: título → nombres → garage → dashboard → título.
func _test_full_flow(game_state: Node, save_system: Node) -> void:
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
	(current_scene.get_node("%BackButton") as Button).pressed.emit()
	_check(await _wait_for_scene(&"Garage"), "Volver al cuarto regresa al garage")

	change_scene_to_file(Paths.TITLE_MENU)
	_check(await _wait_for_scene(&"TitleMenu"), "regresa al título")
	_check(not (current_scene.get_node("%ContinueButton") as Button).disabled, "Continuar habilitado con partida")


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
