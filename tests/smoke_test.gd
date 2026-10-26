extends SceneTree
## Prueba de humo: instancia todas las escenas y recorre el flujo completo sin ventana:
## título → personaje (Alexa) → nombres → garage → pincel → PC → dashboard (ajustes, ficha de mejora,
## comprar) → post-mortem → siguiente oleada → game over → reintentar → cuarto (ajustes) → Salir
## → continuar → meta no alcanzada → repetir etapa → victoria → diálogo de Briseida (con Alexa y con Alex).
## Uso: godot --headless --path . -s res://tests/smoke_test.gd -- --save-path=user://test_smoke.cfg
## Exige una partida alterna (SaveSystem --save-path) y falla si se toca la partida real.
## Nota: con -s los autoloads se registran después de compilar este script, así que aquí
## no se usan como identificadores globales ni se tipan clases que dependan de ellos.

const TEST_SETTINGS_PATH := "user://smoke_test_settings.cfg"
const PHASE_READY := 1
const PHASE_RUNNING := 2
const PHASE_GAME_OVER := 4
const PHASE_STAGE_FAILED := 5
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
	"res://scenes/dashboard/goal_missed.tscn",
	"res://scenes/dashboard/upgrade_info_card.tscn",
	"res://scenes/dashboard/upgrade_info_panel.tscn",
	"res://scenes/ui/dialog_box.tscn",
	"res://scenes/ui/settings_menu.tscn",
	"res://scenes/ui/settings_button.tscn",
]

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("GameState")
	var save_system: Node = root.get_node("SaveSystem")
	var simulation: Node = root.get_node("Simulation")
	var customization: Node = root.get_node("Customization")
	if save_system.call("is_using_real_save"):
		printerr("smoke_test: corre la prueba con una partida alterna para no tocar la real, p. ej.: -- --save-path=user://test_smoke.cfg")
		quit(1)
		return
	# La partida real no se debe leer ni escribir: se compara su fecha al final.
	var real_save := ProjectSettings.globalize_path(Paths.SAVE_FILE)
	var real_save_time := FileAccess.get_modified_time(real_save) if FileAccess.file_exists(real_save) else 0
	save_system.call("delete_save")
	var settings: Node = root.get_node("Settings")
	settings.set("settings_path", TEST_SETTINGS_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

	# Catálogo
	_check(customization.call("get_options", &"pared_izq").size() == 10, "10 colores de pared izquierda")
	_check(customization.call("get_options", &"pared_der").size() == 10, "10 colores de pared derecha")
	_check(customization.call("get_options", &"piso_garage").size() == 3, "3 pisos en el garage")
	_check(customization.call("get_options", &"piso_oficina").size() == 3, "3 pisos en la oficina")
	_check(customization.call("get_options", &"puerta").size() == 6, "6 puertas")
	_check(customization.call("get_options", &"mesa").size() == 3, "3 mesas")
	for room_id: StringName in Paths.ROOM_IDS:
		for layer: StringName in customization.call("get_room_layers", room_id):
			for option: CustomizationOption in customization.call("get_options", layer):
				var path: String = customization.call("get_layer_texture_path", room_id, layer, option.id)
				# La puerta y la mesa de la oficina son las del garage.
				if room_id != &"garage" and (layer == &"puerta" or layer == &"mesa"):
					path = customization.call("get_layer_texture_path", &"garage", layer, option.id)
				_check(ResourceLoader.exists(path), "existe %s" % path)

	# Partida nueva, guardado y carga
	game_state.call("start_new_game", "Prueba", "TestCorp")
	_check(game_state.get("colors")[&"piso_garage"] == &"concreto_calido", "piso del garage por defecto")
	_check(game_state.get("colors")[&"piso_oficina"] == &"laminado_claro", "piso de la oficina por defecto")
	var migrated: Dictionary = customization.call("sanitize_colors", {&"piso": &"concreto_oscuro"})
	_check(migrated[&"piso_garage"] == &"concreto_oscuro", "el piso de una partida vieja pasa al garage")
	_check(game_state.get("colors")[&"puerta"] == &"madera_natural", "puerta por defecto")
	game_state.call("set_color", &"pared_izq", &"menta")
	_check(save_system.call("save_game"), "guardar partida")
	game_state.call("set_color", &"pared_izq", &"grafito")
	_check(save_system.call("load_game"), "cargar partida")
	_check(game_state.get("avatar_name") == "Prueba", "nombre del avatar guardado")
	_check(game_state.get("colors")[&"pared_izq"] == &"menta", "color guardado")
	_check(game_state.get("avatar_id") == &"alex", "personaje por defecto: Alex")
	_test_old_save_without_avatar(game_state, save_system)
	_test_gender_text()

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
	var avatar: Node2D = garage.get_node("%Avatar")
	_check(simulation.get("is_saturated"), "la sobrecarga satura el servidor")
	_check(rack.texture.resource_path.ends_with("rack_saturado.png"), "rack saturado")
	_check(avatar.call("is_stressed"), "Alex estresado")
	simulation.set("overload_enabled", false)
	# La oleada 1 empieza con la red al 90 % (tutorial): con Ancho de banda baja de 85 %.
	_check(simulation.call("purchase", &"bandwidth"), "comprar Ancho de banda desde código")
	for i in 30:
		simulation.call("step")
	_check(not simulation.get("is_saturated"), "la carga regresa a normal")
	_check(rack.texture.resource_path.ends_with("rack_ok.png"), "rack normal")
	garage.queue_free()

	await _test_layer_offsets(game_state, customization)

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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	paused = false
	await process_frame
	_check(not save_system.get("real_save_accessed"), "SaveSystem no tocó la partida real")
	var real_save_time_now := FileAccess.get_modified_time(real_save) if FileAccess.file_exists(real_save) else 0
	_check(real_save_time_now == real_save_time, "la partida real (%s) no cambió" % Paths.SAVE_FILE)
	if _failures.is_empty():
		print("SMOKE TEST OK")
		quit(0)
	else:
		printerr("SMOKE TEST FALLÓ:\n- " + "\n- ".join(_failures))
		quit(1)


## Capas recortadas: cada sprite debe quedar en su offset de layer_offsets.json.
## El JSON se lee aquí directamente para no validar Customization consigo mismo.
func _test_layer_offsets(game_state: Node, customization: Node) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Paths.LAYER_OFFSETS_JSON))
	var offsets: Dictionary = data["capas"]
	var canvas := Vector2(float(data["canvas"][0]), float(data["canvas"][1]))
	var layer_order: Array[StringName] = customization.call("get_room_layers", &"garage")

	# Todas las variantes del catálogo tienen offset y su PNG mide lo que dice el JSON.
	for layer: StringName in layer_order:
		for option: CustomizationOption in customization.call("get_options", layer):
			var path: String = customization.call("get_layer_texture_path", &"garage", layer, option.id)
			var entry: Dictionary = offsets.get(_layer_key(path), {})
			_check(not entry.is_empty(), "offset de %s" % path)
			if not entry.is_empty():
				var size := (load(path) as Texture2D).get_size()
				_check(size == Vector2(float(entry["w"]), float(entry["h"])), "tamaño de %s coincide con el JSON" % path)

	var combos: Array[Dictionary] = [
		{},
		{&"pared_izq": &"menta", &"pared_der": &"grafito", &"piso_garage": &"concreto_oscuro", &"puerta": &"roja", &"mesa": &"nogal"},
	]
	for combo: Dictionary in combos:
		for layer: StringName in layer_order:
			game_state.call("set_color", layer, combo.get(layer, customization.call("get_default_option", layer)))
		var garage := (load("res://scenes/rooms/garage.tscn") as PackedScene).instantiate()
		root.add_child(garage)
		await process_frame
		var context := "combinación %s" % ("por defecto" if combo.is_empty() else "alterna")
		for node_name: String in ["Floor", "WallLeft", "WallRight", "Door", "Rack", "Desk", "Boxes"]:
			_check_layer_offset(garage.get_node("%" + node_name), offsets, context)
		# Al cambiar de color en vivo, la posición sigue a la textura nueva.
		game_state.call("set_color", &"piso_garage", &"concreto_gris")
		_check_layer_offset(garage.get_node("%Floor"), offsets, context + " tras cambiar el piso")

		var avatar: Node2D = garage.get_node("%Avatar")
		var alex: Sprite2D = avatar.get_node("%Sprite")
		_check_layer_offset(alex, offsets, context + " (Alex teclea A)")
		avatar.call("_on_frame_timer_timeout")
		_check(alex.texture.resource_path.ends_with("alex_teclea_b.png"), "%s: Alex pasa a teclea B" % context)
		_check_layer_offset(alex, offsets, context + " (Alex teclea B)")
		# Sobrecarga real: el servidor 1 se satura, su rack se pone rojo y el avatar se estresa.
		var simulation: Node = root.get_node("Simulation")
		simulation.set("overload_enabled", true)
		for i in 15:
			simulation.call("step")
		var rack: Sprite2D = garage.get_node("%Rack")
		_check(rack.texture.resource_path.ends_with("rack_saturado.png"), "%s: rack saturado con su servidor" % context)
		_check(alex.texture.resource_path.ends_with("alex_estres.png"), "%s: Alex estresado" % context)
		_check_layer_offset(alex, offsets, context + " (Alex estresado)")
		_check_layer_offset(rack, offsets, context + " (rack saturado)")
		simulation.set("overload_enabled", false)
		for i in 30:
			simulation.call("step")
		_check(rack.texture.resource_path.ends_with("rack_ok.png"), "%s: el rack vuelve a la normalidad" % context)

		# La cámara se centra en el lienzo completo, no en el piso recortado.
		var layers: Node2D = garage.get_node("%Layers")
		var overview: Vector2 = garage.call("_get_overview_position")
		_check(overview.is_equal_approx(layers.to_global(canvas * 0.5)), "%s: cámara centrada en el lienzo" % context)
		garage.free()
		await process_frame


## La posición se mide en el lienzo 2x (local a Layers), sumando los nodos del y-sort que la contienen.
## `extra` es el desplazamiento de un sprite reutilizado del garage en otro cuarto.
func _check_layer_offset(sprite: Sprite2D, offsets: Dictionary, context: String, extra: Vector2 = Vector2.ZERO) -> void:
	var key := _layer_key(sprite.texture.resource_path)
	var entry: Dictionary = offsets.get(key, {})
	_check(not entry.is_empty(), "%s: %s tiene offset" % [context, key])
	if entry.is_empty():
		return
	var expected := Vector2(float(entry["x"]), float(entry["y"])) + extra
	var actual := _canvas_position(sprite)
	_check(not sprite.centered and actual.is_equal_approx(expected),
			"%s: %s en %s (está en %s)" % [context, key, expected, actual])


func _canvas_position(sprite: Sprite2D) -> Vector2:
	var position := sprite.position
	var node := sprite.get_parent() as Node2D
	while node != null and node.name != &"Layers":
		position += node.position
		node = node.get_parent() as Node2D
	return position


## "res://.../piso/concreto_calido.png" → "piso/concreto_calido"
func _layer_key(texture_path: String) -> String:
	return "%s/%s" % [texture_path.get_base_dir().get_file(), texture_path.get_file().get_basename()]


## Recorre el flujo real con las escenas y botones: título → nombres → garage → dashboard → título.
func _test_full_flow(game_state: Node, save_system: Node, simulation: Node) -> void:
	save_system.call("delete_save")
	change_scene_to_file(Paths.TITLE_MENU)
	_check(await _wait_for_scene(&"TitleMenu"), "abre el menú de título")
	_check((current_scene.get_node("%ContinueButton") as Button).disabled, "Continuar deshabilitado sin partida")
	(current_scene.get_node("%NewGameButton") as Button).pressed.emit()
	_check(await _wait_for_scene(&"NewGameSetup", 6.0), "pantalla de carga → partida nueva")

	var character_select: Control = current_scene.get_node("%CharacterSelect")
	var avatar_prompt: NamePrompt = current_scene.get_node("%AvatarPrompt")
	var company_prompt: NamePrompt = current_scene.get_node("%CompanyPrompt")
	_check(character_select.visible and not avatar_prompt.visible, "paso 1: elegir personaje")
	_check((character_select.get_node("%StepLabel") as Label).text == "Paso 1 de 3", "la selección dice Paso 1 de 3")
	_check(character_select.call("get_selected_id") == &"alex", "Alex viene seleccionado")
	(character_select.call("get_card", &"alexa") as Button).button_pressed = true
	_check(character_select.call("get_selected_id") == &"alexa", "tocar la tarjeta elige a Alexa")
	_check(not (character_select.call("get_card", &"alex") as Button).button_pressed, "solo una tarjeta seleccionada")
	(character_select.get_node("%NextButton") as Button).pressed.emit()
	_check(avatar_prompt.visible and not character_select.visible, "paso 2: nombre del avatar")
	_check((avatar_prompt.get_node("%StepLabel") as Label).text == "Paso 2 de 3", "el nombre dice Paso 2 de 3")
	_check((avatar_prompt.get_node("%NameEdit") as LineEdit).placeholder_text == "Alexa", "el placeholder es Alexa")
	(avatar_prompt.get_node("%BackButton") as Button).pressed.emit()
	_check(character_select.visible and character_select.call("get_selected_id") == &"alexa", "Atrás regresa a la selección con Alexa elegida")
	(character_select.get_node("%NextButton") as Button).pressed.emit()
	_check(avatar_prompt.visible, "Siguiente vuelve al nombre")
	_check((company_prompt.get_node("%StepLabel") as Label).text == "Paso 3 de 3", "la empresa dice Paso 3 de 3")
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
	_check((garage.get_node("%Hud").get_node("%TitleLabel") as Label).text == "Nexus Test · Startup", "HUD con empresa y etapa")
	_check((garage.get_node("%Avatar").get_node("%NameLabel") as Label).text == "Said", "nombre sobre el avatar")
	_check(game_state.get("avatar_id") == &"alexa", "la partida es de Alexa")
	_check_avatar_sprite(garage, "alexa", "garage nuevo")

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

	_test_mobile_lifecycle(current_scene, save_system)
	_test_settings_in_room(current_scene)
	_check(await _wait_for_scene(&"TitleMenu"), "Salir lleva al menú de título")
	_test_title_quit_confirmation(current_scene)
	var continue_button := current_scene.get_node("%ContinueButton") as Button
	_check(not continue_button.disabled, "Continuar habilitado con partida")
	continue_button.pressed.emit()
	_check(await _wait_for_scene(&"Garage"), "Continuar abre el garage")
	_check(simulation.get("phase") == PHASE_READY and simulation.get("wave_number") == 2, "Continuar vuelve al inicio de la oleada 2")
	_check(simulation.call("get_level", &"bandwidth") == 1, "Continuar conserva las mejoras")
	_check(game_state.get("avatar_id") == &"alexa", "Continuar conserva a Alexa")
	_check_avatar_sprite(current_scene, "alexa", "después de Continuar")

	await _test_goal_missed(simulation)
	await _test_victory_and_investment(simulation, "la mejor SysAdmin")
	game_state.call("_set_avatar", &"alex")
	await _test_victory_and_investment(simulation, "el mejor SysAdmin")
	await _test_office_and_shop(game_state, simulation)
	await _test_stage_name_in_huds(simulation)


## El HUD del cuarto y el del dashboard muestran la etapa actual. Startup y Scale-up tienen su cuarto;
## la etapa 3 (sin cuarto propio) usa la oficina y avisa que es un cuarto temporal.
func _test_stage_name_in_huds(simulation: Node) -> void:
	var scene_router: Node = root.get_node("SceneRouter")
	var rooms := {"startup": &"Garage", "scale_up": &"Oficina", "enterprise": &"Oficina"}
	for stage_id: String in rooms:
		simulation.call("load_checkpoint", {"stage": stage_id, "wave": 1, "coins": 100})
		var stage_name: String = simulation.get("stage").get("display_name")
		change_scene_to_file(scene_router.call("get_current_room_path"))
		_check(await _wait_for_scene(rooms[stage_id]), "%s: abre %s" % [stage_name, rooms[stage_id]])
		var hud: Node = current_scene.get_node("%Hud")
		var room_title := (hud.get_node("%TitleLabel") as Label).text
		var temporary := hud.get_node("%TemporaryRoomLabel") as Label
		if stage_id != "enterprise":
			_check(not temporary.visible, "%s: es su propio cuarto, sin aviso de cuarto temporal" % stage_name)
		else:
			_check(temporary.visible and temporary.text == "Cuarto temporal: oficina", "%s: aviso de cuarto temporal (%s)" % [stage_name, temporary.text])

		change_scene_to_file(Paths.DASHBOARD)
		_check(await _wait_for_scene(&"Dashboard"), "%s: abre el dashboard" % stage_name)
		var dashboard_title := (current_scene.get_node("%TitleLabel") as Label).text
		_check(room_title.get_slice(" · ", 1) == stage_name and dashboard_title.get_slice(" · ", 1) == stage_name,
				"misma etapa en los dos HUD (garage: %s, dashboard: %s)" % [room_title, dashboard_title])


## Dashboard: comprar, terminar la oleada (acelerada), post-mortem, siguiente oleada, game over y reintentar.
func _test_dashboard(dashboard: Node, simulation: Node) -> void:
	_check(simulation.get("phase") == PHASE_RUNNING and simulation.get("wave_number") == 1, "el dashboard inicia la oleada 1")
	var monitor: Node = dashboard.get_node("%TrafficMonitor")
	_check(monitor.call("get_server_count") == 1, "el monitor muestra 1 servidor")
	var byte: Control = dashboard.get_node("%ByteBubble")
	_check(byte.visible and str(byte.call("get_text")).contains("BYTE"), "BYTE da el tutorial de la oleada 1")
	await _test_settings_in_dashboard(dashboard, simulation)
	await _test_upgrade_info(dashboard, simulation)
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


## Engranaje en el dashboard: pausa la simulación y bloquea la consola mientras está abierto.
func _test_settings_in_dashboard(dashboard: Node, simulation: Node) -> void:
	var settings_button: Node = dashboard.get_node("%SettingsButton")
	var menu: Control = settings_button.get_node("%SettingsMenu")
	(settings_button.get_node("%GearButton") as Button).pressed.emit()
	_check(menu.visible and paused, "el engranaje del dashboard abre Ajustes y pausa el juego")
	var wave_time: float = simulation.get("wave_time")
	await create_timer(0.5).timeout
	_check(is_equal_approx(simulation.get("wave_time"), wave_time), "con Ajustes abierto la simulación no avanza")
	var slot: Control = dashboard.get_node("%UpgradeGrid").get_node("SettingsSlot")
	_check(slot != null, "la consola reserva el espacio del engranaje")
	var sfx_slider: HSlider = menu.get_node("%SfxSlider")
	var sfx_before := sfx_slider.value
	(menu.get_node("%SfxMute") as Button).button_pressed = true
	_check(root.get_node("Settings").get("sfx_muted"), "el botón de silencio apaga los efectos")
	_check(is_zero_approx(sfx_slider.value), "al silenciar, el slider baja a 0")
	(menu.get_node("%SfxMute") as Button).button_pressed = false
	_check(is_equal_approx(sfx_slider.value, sfx_before), "al reactivar, el slider vuelve al volumen anterior")
	sfx_slider.value = 0.0
	_check(root.get_node("Settings").get("sfx_muted") and (menu.get_node("%SfxMute") as Button).button_pressed, "bajar el slider a 0 silencia")
	# Botón "atrás" de Android
	settings_button.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not menu.visible and not paused, "el botón atrás de Android cierra Ajustes y reanuda")
	await create_timer(0.3).timeout
	_check(simulation.get("wave_time") > wave_time, "al cerrar Ajustes la simulación sigue")


## Ficha de la mejora: con la "i" y manteniendo presionado (sin comprar).
func _test_upgrade_info(dashboard: Node, simulation: Node) -> void:
	var info_panel: Control = dashboard.get_node("%UpgradeInfoPanel")
	var ram: Button = dashboard.call("get_upgrade_button", &"ram")
	(ram.get_node("%InfoButton") as Button).pressed.emit()
	await process_frame
	var concept: Label = info_panel.get_node("%Card").get_node("%ConceptLabel")
	_check(info_panel.visible and concept.text.begins_with("Concurrencia"), "la i muestra la ficha con el concepto que enseña")
	(info_panel.get_node("%CloseButton") as Button).pressed.emit()
	_check(not info_panel.visible, "Cerrar oculta la ficha")

	var cache: Button = dashboard.call("get_upgrade_button", &"cache")
	var level_before: int = simulation.call("get_level", &"ram")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	cache.gui_input.emit(press)
	await create_timer(0.6).timeout
	var level_label: Label = info_panel.get_node("%Card").get_node("%LevelLabel")
	_check(info_panel.visible and level_label.text.contains("etapa 2"), "mantener presionada una mejora bloqueada muestra su ficha")
	info_panel.hide()
	ram.gui_input.emit(press)
	await create_timer(0.6).timeout
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	ram.gui_input.emit(release)
	ram.pressed.emit()
	_check(simulation.call("get_level", &"ram") == level_before, "soltar después de mantener presionado no compra")
	info_panel.hide()


## Engranaje en el garage: sliders guardados en settings.cfg, Regresar y Salir con confirmación.
func _test_settings_in_room(room: Node) -> void:
	var settings_button: Node = room.get_node("%SettingsButton")
	var menu: Control = settings_button.get_node("%SettingsMenu")
	(settings_button.get_node("%GearButton") as Button).pressed.emit()
	_check(menu.visible and paused, "el engranaje del garage abre Ajustes y pausa el juego")
	(menu.get_node("%MusicSlider") as HSlider).value = 35.0
	(menu.get_node("%SfxSlider") as HSlider).value = 60.0
	_check(not root.get_node("Settings").get("sfx_muted"), "mover el slider quita el silencio")
	(menu.get_node("%SfxMute") as Button).button_pressed = true
	_check(is_equal_approx(root.get_node("Settings").get("music_volume"), 0.35), "el slider de música cambia el volumen")
	var music_bus := AudioServer.get_bus_index(&"Music")
	_check(music_bus >= 0 and is_equal_approx(AudioServer.get_bus_volume_db(music_bus), linear_to_db(0.35)), "el volumen se aplica al bus Music")
	(menu.get_node("%ReturnButton") as Button).pressed.emit()
	_check(not menu.visible and not paused, "Regresar cierra Ajustes y reanuda")
	var saved := ConfigFile.new()
	_check(saved.load(TEST_SETTINGS_PATH) == OK, "los ajustes se guardan en settings.cfg")
	_check(is_equal_approx(float(saved.get_value("audio", "music_volume", 0.0)), 0.35), "settings.cfg tiene el volumen de música")
	_check(is_equal_approx(float(saved.get_value("audio", "sfx_volume", 0.0)), 0.6), "settings.cfg tiene el volumen de efectos")
	_check(bool(saved.get_value("audio", "sfx_muted", false)), "settings.cfg tiene el silencio de efectos")

	(settings_button.get_node("%GearButton") as Button).pressed.emit()
	(menu.get_node("%QuitButton") as Button).pressed.emit()
	_check(menu.call("is_confirming_quit"), "Salir pide confirmación")
	(menu.get_node("%CancelQuitButton") as Button).pressed.emit()
	_check(menu.visible and not menu.call("is_confirming_quit"), "Cancelar vuelve al panel")
	(menu.get_node("%QuitButton") as Button).pressed.emit()
	(menu.get_node("%ConfirmQuitButton") as Button).pressed.emit()
	_check(not paused, "Salir reanuda el árbol antes de cambiar de escena")


## Terminar la etapa sin la meta: "Meta no alcanzada" (no es quiebra) → Repetir etapa.
func _test_goal_missed(simulation: Node) -> void:
	simulation.call("load_checkpoint", {"stage": "startup", "wave": 5, "coins": 321, "users_served": 0})
	change_scene_to_file(Paths.DASHBOARD)
	_check(await _wait_for_scene(&"Dashboard"), "abre el dashboard para la oleada 5")
	_make_infrastructure_huge(simulation)
	_finish_wave(simulation)
	await process_frame
	var goal_missed: Control = current_scene.get_node("%GoalMissed")
	_check(simulation.get("phase") == PHASE_STAGE_FAILED and goal_missed.visible, "sin la meta aparece Meta no alcanzada")
	_check(not (current_scene.get_node("%GameOver") as Control).visible, "Meta no alcanzada no es quiebra")
	_check((goal_missed.get_node("%UsersLabel") as Label).text.contains("/ 1,000"), "Meta no alcanzada muestra usuarios / meta")
	(goal_missed.get_node("%RepeatButton") as Button).pressed.emit()
	await process_frame
	_check(simulation.get("phase") == PHASE_RUNNING and simulation.get("wave_number") == 1, "Repetir etapa vuelve a la oleada 1")
	_check(simulation.get("coins") == 321, "Repetir etapa conserva los ahorros del inicio de la etapa")
	_check(not goal_missed.visible, "Meta no alcanzada se cierra")


## Etapa 2: la oficina con los racks, la mesa y el avatar en su lugar, y la tienda completa:
## comprar sillón → colocarlo → tocarlo → girarlo → guardarlo → colocarlo otra vez → venderlo.
func _test_office_and_shop(game_state: Node, simulation: Node) -> void:
	simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 2, "coins": 2000})
	change_scene_to_file(root.get_node("SceneRouter").call("get_current_room_path"))
	_check(await _wait_for_scene(&"Oficina"), "Scale-up abre la oficina")
	var office := current_scene
	await process_frame

	var offsets: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Paths.LAYER_OFFSETS_JSON))["capas"]
	var room: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Paths.ROOM_DATA % "oficina"))
	var reuse: Dictionary = room["reutilizados_del_garage"]
	var floor_offset: Dictionary = room["capas_offsets"]["oficina/piso/laminado_claro"]
	_check(_canvas_position(office.get_node("%Floor")) == Vector2(float(floor_offset["x"]), float(floor_offset["y"])), "oficina: piso propio en su offset")
	_check_layer_offset(office.get_node("%Rack"), offsets, "oficina: rack 1", _vec(reuse["rack_1 (fijos/rack_ok|rack_saturado)"]))
	_check((office.get_node("%Rack2Holder") as Node2D).visible, "oficina: hay un segundo rack")
	_check_layer_offset(office.get_node("%Rack2"), offsets, "oficina: rack 2", _vec(reuse["rack_2 (fijos/rack_ok|rack_saturado)"]))
	var avatar_id := String(game_state.get("avatar_id"))
	_check_layer_offset(office.get_node("%Avatar").get_node("%Sprite"), offsets, "oficina: avatar", _vec(reuse[avatar_id + "/*"]))
	_check_layer_offset(office.get_node("%Desk"), offsets, "oficina: mesa", _vec(reuse["mesa/*"]))
	_check_layer_offset(office.get_node("%Door"), offsets, "oficina: puerta", _vec(reuse["puerta/*"]))

	var hud: Node = office.get_node("%Hud")
	var shop_button := hud.get_node("%ShopButton") as Button
	_check(not shop_button.disabled, "oficina entre oleadas: Tienda habilitada")
	shop_button.pressed.emit()
	var shop_panel: CanvasLayer = office.get_node("%ShopPanel")
	_check(shop_panel.visible, "Tienda abre el panel")
	(shop_panel.call("get_row_button", &"sillon") as Button).pressed.emit()
	_check(simulation.get("coins") == 1400 and not shop_panel.visible, "Comprar el sillón cobra 600 y entra a colocarlo")
	var placer: Node = office.get_node("%DecorPlacer")
	var toolbar: CanvasLayer = office.get_node("%DecorToolbar")
	placer.call("move_ghost_to", Vector2(5.0, 5.0))
	(toolbar.get_node("%ConfirmButton") as Button).pressed.emit()
	var placed: Array = game_state.call("get_placed_decor", &"oficina")
	_check(placed.size() == 1 and placed[0]["ori"] == "a", "el sillón queda colocado")

	# Un toque sobre el sprite lo selecciona.
	var sprite := (placer.call("get_item_node", 0) as Node2D).get_child(0) as Sprite2D
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.position = sprite.get_global_transform_with_canvas() * (sprite.texture.get_size() * 0.5)
	# Coordenadas del viewport (no de la ventana, que tiene otro tamaño por el stretch).
	root.push_input(tap, true)
	await process_frame
	_check(placer.call("get_selected_index") == 0 and toolbar.visible, "tocar el sillón lo selecciona")
	(toolbar.get_node("%RotatePlacedButton") as Button).pressed.emit()
	_check(placed[0]["ori"] == "b" and placer.call("get_selected_index") == 0, "Girar gira el sillón colocado")
	(toolbar.get_node("%StoreButton") as Button).pressed.emit()
	_check(placed.is_empty() and game_state.call("count_in_inventory", &"sillon") == 1, "Guardar en inventario lo quita del cuarto")

	shop_button.pressed.emit()
	(shop_panel.get_node("%InventoryTab") as Button).pressed.emit()
	(shop_panel.call("get_row_button", &"sillon") as Button).pressed.emit()
	placer.call("move_ghost_to", Vector2(5.0, 5.0))
	_check(placer.call("confirm_placement"), "colocarlo otra vez desde el inventario")
	_check(placed.size() == 1 and game_state.call("count_in_inventory", &"sillon") == 0 and simulation.get("coins") == 1400, "colocar desde el inventario no cobra")
	placer.call("select", 0)
	(toolbar.get_node("%SellButton") as Button).pressed.emit()
	_check(placed.is_empty() and simulation.get("coins") == 1700, "Vender devuelve el 50 %% (%d)" % simulation.get("coins"))
	_check(not toolbar.visible and placer.call("get_mode") == 0, "después de vender no queda nada seleccionado")


func _vec(raw: Array) -> Vector2:
	return Vector2(float(raw[0]), float(raw[1]))


## Ganar la etapa: victoria → diálogo de Briseida → se entrega la ronda de inversión.
## `gendered_text` es la forma con género que debe usar Briseida según el personaje.
func _test_victory_and_investment(simulation: Node, gendered_text: String) -> void:
	simulation.call("load_checkpoint", {"stage": "startup", "wave": 5, "coins": 50, "users_served": 990})
	change_scene_to_file(Paths.DASHBOARD)
	_check(await _wait_for_scene(&"Dashboard"), "abre el dashboard para ganar la etapa")
	_make_infrastructure_huge(simulation)
	_finish_wave(simulation)
	await process_frame
	var dashboard := current_scene
	var victory: Control = dashboard.get_node("%Victory")
	_check(victory.visible, "al llegar a la meta aparece la victoria")
	var coins_before_dialog: int = simulation.get("coins")
	_check((victory.get_node("%StatsLabel") as Label).text.contains("Peticiones atendidas"), "la victoria muestra las peticiones escaladas")
	(victory.get_node("%ContinueButton") as Button).pressed.emit()
	await process_frame
	var dialog: Control = dashboard.get_node("%DialogBox")
	var text: String = dialog.call("get_text")
	_check(dialog.visible and text.contains("Said") and text.contains("Nexus Test") and text.contains("1,500"), "Briseida anuncia la ronda de inversión (%s)" % text)
	_check((dialog.get_node("%SpeakerLabel") as Label).text == "Briseida" and (dialog.get_node("%InitialsLabel") as Label).text == "B", "habla Briseida, con B en el retrato")
	_check(text.contains(gendered_text) and not text.contains("{"), "Briseida usa \"%s\" (%s)" % [gendered_text, text])
	_check(simulation.get("coins") == coins_before_dialog, "las monedas llegan después del diálogo")
	(dialog.get_node("%ContinueButton") as Button).pressed.emit()
	_check(simulation.get("coins") == coins_before_dialog + 1500, "¡Vamos! entrega la ronda de inversión")
	_check(await _wait_for_scene(&"Oficina"), "después del diálogo se vuelve al cuarto de Scale-up (la oficina)")


## El sprite del avatar es el del personaje elegido y está en su offset de layer_offsets.json.
func _check_avatar_sprite(room: Node, avatar_id: String, context: String) -> void:
	var sprite: Sprite2D = room.get_node("%Avatar").get_node("%Sprite")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Paths.LAYER_OFFSETS_JSON))
	_check(sprite.texture.resource_path.get_file().begins_with(avatar_id + "_"), "%s: sprite de %s (%s)" % [context, avatar_id, sprite.texture.resource_path])
	_check_layer_offset(sprite, data["capas"], context)


## Una partida guardada antes de la selección de personaje (sin avatar_id) carga con Alex.
func _test_old_save_without_avatar(game_state: Node, save_system: Node) -> void:
	game_state.call("_set_avatar", &"alexa")
	_check(save_system.call("save_game"), "guardar con Alexa")
	var config := ConfigFile.new()
	config.load(save_system.get("save_path"))
	config.erase_section_key("player", "avatar_id")
	config.save(save_system.get("save_path"))
	_check(save_system.call("load_game") and game_state.get("avatar_id") == &"alex", "una partida vieja sin avatar_id es de Alex")


## TextUtil elige la forma según el género. Se carga como recurso porque depende de GameState.
func _test_gender_text() -> void:
	var text_util: GDScript = load("res://scripts/ui/text_util.gd")
	_check(text_util.call("format", "¡Bienvenid{o|a}!", "f") == "¡Bienvenida!", "formato femenino")
	_check(text_util.call("format", "¡Bienvenid{o|a}! {Listo|Lista}", "m") == "¡Bienvenido! Listo", "formato masculino")
	_check(text_util.call("g", "listo", "lista", "f") == "lista", "g() femenino")


func _make_infrastructure_huge(simulation: Node) -> void:
	for server: ServerState in simulation.get("servers"):
		server.cpu_cap = 1e6
		server.net_cap = 1e6
		server.ram_slots = 1e6
	(simulation.get("db") as DbState).iops = 1e6


## Celular: botón "atrás" (primero cierra paneles), salir de la app (guarda y pausa) y contador de FPS.
func _test_mobile_lifecycle(room: Node, save_system: Node) -> void:
	var settings_button: Node = room.get_node("%SettingsButton")
	var menu: Control = settings_button.get_node("%SettingsMenu")
	var customize: CanvasLayer = room.get_node("%CustomizePanel")
	(room.get_node("%Hud").get_node("%BrushButton") as Button).pressed.emit()
	_check(not settings_button.call("is_gear_visible"), "con el pincel abierto el engranaje se oculta")
	settings_button.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not customize.visible and not menu.visible, "atrás con el pincel abierto cierra el pincel (no abre Ajustes)")
	_check(settings_button.call("is_gear_visible"), "al cerrar el pincel vuelve el engranaje")
	settings_button.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(menu.visible and paused, "atrás sin paneles abre Ajustes en pausa")
	settings_button.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not menu.visible and not paused, "atrás otra vez cierra Ajustes")

	save_system.call("delete_save")
	settings_button.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	_check(save_system.call("has_save"), "salir de la app guarda la partida")
	_check(menu.visible and paused, "al volver a la app el juego está en pausa con Ajustes abierto")
	(menu.get_node("%ReturnButton") as Button).pressed.emit()

	var overlay: Node = root.get_node("DebugOverlay")
	var f3 := InputEventKey.new()
	f3.keycode = KEY_F3
	f3.pressed = true
	overlay.call("_input", f3)
	_check(overlay.call("is_shown"), "F3 muestra el contador de FPS (build de depuración)")
	overlay.call("_input", f3)
	_check(not overlay.call("is_shown"), "F3 otra vez lo oculta")


## Título: Salir y el botón "atrás" piden confirmación (aquí nunca se confirma, cerraría el juego).
func _test_title_quit_confirmation(title: Node) -> void:
	var confirm: Control = title.get_node("%QuitConfirmPanel")
	(title.get_node("%QuitButton") as Button).pressed.emit()
	_check(confirm.visible, "Salir en el título pregunta si quieres salir")
	(title.get_node("%CancelQuitButton") as Button).pressed.emit()
	_check(not confirm.visible, "Cancelar cierra la pregunta")
	title.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(confirm.visible, "atrás en el título también pregunta")
	title.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not confirm.visible, "atrás otra vez cancela la pregunta")
	(title.get_node("%OptionsButton") as Button).pressed.emit()
	title.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not (title.get_node("%OptionsPanel") as Control).visible and not confirm.visible, "atrás con Opciones abierto solo cierra Opciones")
