extends SceneTree
## Pruebas de la paleta pastel, las texturas de pared y piso y los colores de camiseta: catálogo, precios,
## compra, guardado (versión 7 y partidas viejas), recoloreado con shader y panel de personalización.
## Uso: godot --headless --path . -s res://tests/test_customization.gd -- --save-path=user://test_customization.cfg
## Nota: con -s los autoloads no son identificadores globales; se piden con root.get_node y se llaman con call().

const PASTEL_COUNT := 12
const PATTERN_COUNT := 8
const ROOMS: Array[StringName] = [&"garage", &"oficina", &"data_center"]

var _failures: Array[String] = []
var _game_state: Node
var _save_system: Node
var _simulation: Node
var _customization: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game_state = root.get_node("GameState")
	_save_system = root.get_node("SaveSystem")
	_simulation = root.get_node("Simulation")
	_customization = root.get_node("Customization")
	if _save_system.call("is_using_real_save"):
		printerr("test_customization: corre la prueba con una partida alterna, p. ej.: -- --save-path=user://test_customization.cfg")
		quit(1)
		return
	_save_system.call("delete_save")

	_test_catalog()
	_test_purchase()
	_test_save()
	_test_shirt()
	await _test_panel()

	_save_system.call("delete_save")
	if _failures.is_empty():
		print("test_customization: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("FALLO: ", failure)
		quit(1)


func _options(layer: StringName) -> Array:
	return _customization.call("get_options", layer)


func _test_catalog() -> void:
	var seen := {}
	for layer: StringName in _customization.call("get_all_layers"):
		for option: CustomizationOption in _options(layer):
			if option.price > 0 or option.is_procedural():
				var key := "%s/%s" % [layer, option.id]
				_check(not seen.has(key), "id repetido %s" % key)
				seen[key] = true
			if option.kind == "tinte":
				_check(option.base_id != &"" and _customization.call("is_valid_option", layer, option.base_id), "tinte %s tiene base válida" % option.id)
				_check(option.price > 0, "tinte %s es de pago" % option.id)
			if option.kind == "patron":
				_check(ResourceLoader.exists(Paths.PATTERN_TEXTURE % option.pattern), "existe la textura %s" % option.pattern)
				_check(option.price > 0, "patrón %s es de pago" % option.id)
	var pastel := 0
	var patterns := 0
	for option: CustomizationOption in _options(&"pared_izq"):
		if option.kind == "tinte":
			pastel += 1
		elif option.kind == "patron":
			patterns += 1
	_check(pastel == PASTEL_COUNT, "paredes: %d colores pastel (%d)" % [PASTEL_COUNT, pastel])
	_check(patterns == PATTERN_COUNT, "paredes: %d texturas (%d)" % [PATTERN_COUNT, patterns])
	# Los colores que ya existían siguen gratis.
	for option: CustomizationOption in _options(&"pared_izq"):
		if option.kind == "render":
			_check(option.price == 0, "pared %s sigue gratis" % option.id)
	for room_id in ROOMS:
		var floor_layer: StringName = _customization.call("get_floor_layer", room_id)
		_check(not _options(floor_layer).is_empty(), "el piso de %s tiene opciones" % room_id)
	var shirts := _options(&"camiseta")
	_check(shirts.size() == PASTEL_COUNT + 1, "camiseta: original + %d colores (%d)" % [PASTEL_COUNT, shirts.size()])
	for option: CustomizationOption in shirts:
		_check(option.price == 0, "camiseta %s es gratis" % option.id)


func _test_purchase() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	var pastel: CustomizationOption = _customization.call("find_option", &"pared_izq", &"pastel_menta_fresca")
	_check(pastel != null and pastel.price > 0, "pastel_menta existe y cuesta")
	var unlocked: Array[StringName] = _game_state.get("unlocked_options")
	_check(unlocked.is_empty(), "una partida nueva no trae opciones desbloqueadas")
	var cart: Array[CustomizationOption] = _customization.call("get_locked_options", {&"pared_izq": pastel.id, &"pared_der": pastel.id}, unlocked)
	_check(cart.size() == 1 or cart.size() == 2, "el carrito no repite la misma opción por capa")
	_simulation.set("coins", pastel.price - 1)
	_check(not _game_state.call("purchase_options", [pastel] as Array[CustomizationOption]), "sin monedas suficientes no se compra")
	_check(_simulation.get("coins") == pastel.price - 1, "una compra rechazada no cobra")
	_simulation.set("coins", pastel.price + 7)
	_check(_game_state.call("purchase_options", [pastel] as Array[CustomizationOption]), "con monedas suficientes se compra")
	_check(_simulation.get("coins") == 7, "la compra cobra el precio exacto (%s)" % _simulation.get("coins"))
	_check(_game_state.call("is_option_unlocked", pastel), "la opción queda desbloqueada")
	_check(_game_state.call("purchase_options", [pastel] as Array[CustomizationOption]), "volver a comprarla no falla")
	_check(_simulation.get("coins") == 7, "volver a comprarla no cobra otra vez")
	var total: int = _customization.call("get_total_price", [pastel] as Array[CustomizationOption])
	_check(total == pastel.price, "total del carrito")


func _test_save() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	var pastel: CustomizationOption = _customization.call("find_option", &"pared_izq", &"pastel_rosa")
	var pattern: CustomizationOption = _customization.call("find_option", &"pared_izq", &"patron_lunares")
	_simulation.set("coins", 10000)
	_check(_game_state.call("purchase_options", [pastel] as Array[CustomizationOption]), "compra pastel_rosa")
	_game_state.call("set_color", &"pared_izq", pastel.id)
	_game_state.call("set_color", &"pared_der", pastel.id)
	_check(_save_system.call("save_game"), "se guarda la partida")
	# Una partida nueva guarda sola (arranca el tutorial): se respalda el archivo para cargar el de la prueba.
	var save_path: String = _save_system.get("save_path")
	var backup := save_path + ".bak"
	DirAccess.copy_absolute(save_path, backup)
	_game_state.call("start_new_game", "Otro", "Otra", &"alex")
	DirAccess.copy_absolute(backup, save_path)
	DirAccess.remove_absolute(backup)
	_check(_save_system.call("load_game"), "se carga la partida")
	_check(_game_state.call("get_color", &"pared_izq") == &"pastel_rosa", "el color pastel comprado se conserva")
	_check(_game_state.call("is_option_unlocked", pastel), "la compra se conserva")
	_check(not _game_state.call("is_option_unlocked", pattern), "lo no comprado sigue bloqueado")
	# Una opción de pago sin comprar en un guardado cae al color por defecto.
	var raw := {&"pared_izq": pattern.id}
	var clean: Dictionary = _customization.call("sanitize_colors", raw, [] as Array[StringName])
	_check(clean[&"pared_izq"] == _customization.call("get_default_option", &"pared_izq"), "opción de pago sin comprar vuelve al color por defecto")
	var clean_ok: Dictionary = _customization.call("sanitize_colors", raw, [pattern.id] as Array[StringName])
	_check(clean_ok[&"pared_izq"] == pattern.id, "opción comprada se respeta")
	# Un guardado sin camiseta ni desbloqueos (versión anterior) usa los valores por defecto.
	var old: Dictionary = _customization.call("sanitize_colors", {&"pared_izq": &"blanco_hueso"})
	_check(old[&"camiseta"] == &"original", "guardado viejo: camiseta original")


func _test_shirt() -> void:
	var avatars := {&"alex": 0, &"alexa": 0}
	for avatar_id: StringName in avatars:
		var data: AvatarData = load("res://resources/avatars/%s.tres" % avatar_id)
		_check(data != null, "existe el avatar %s" % avatar_id)
		var avatar: Node2D = load("res://scenes/characters/avatar.tscn").instantiate()
		root.add_child(avatar)
		avatar.call("set_avatar", data)
		_check(not avatar.call("is_shirt_recolored"), "%s empieza con la camiseta original" % avatar_id)
		avatar.call("set_shirt", &"cam_coral")
		_check(avatar.call("is_shirt_recolored"), "%s cambia de camiseta" % avatar_id)
		avatar.call("set_shirt", &"original")
		_check(not avatar.call("is_shirt_recolored"), "%s vuelve a la original" % avatar_id)
		avatar.free()


func _test_panel() -> void:
	_game_state.call("start_new_game", "Sayola", "NexusSoft", &"alex")
	var panel: CanvasLayer = load("res://scenes/ui/customize_panel.tscn").instantiate()
	root.add_child(panel)
	await process_frame
	_simulation.set("coins", 0)
	panel.call("open", &"garage")
	await process_frame
	var save_button: Button = panel.get_node("%SaveButton")
	var status: Label = panel.get_node("%StatusLabel")
	_check(save_button.text == "Guardar" and not save_button.disabled, "sin carrito el botón dice Guardar")
	_game_state.call("set_color", &"pared_izq", &"pastel_coral")
	var coral: CustomizationOption = _customization.call("find_option", &"pared_izq", &"pastel_coral")
	_check(save_button.disabled and status.text.contains("Te faltan"), "sin monedas no se puede comprar (%s)" % status.text)
	_simulation.set("coins", coral.price + 3)
	panel.call("_refresh_cart")
	_check(not save_button.disabled and save_button.text.contains(str(coral.price)), "con monedas el botón compra (%s)" % save_button.text)
	panel.call("_on_cancel_pressed")
	_check(_game_state.call("get_color", &"pared_izq") != &"pastel_coral", "cancelar revierte la compra no guardada")
	_check(_simulation.get("coins") == coral.price + 3, "cancelar no cobra")
	panel.call("open", &"garage")
	_game_state.call("set_color", &"pared_izq", &"pastel_coral")
	panel.call("_on_save_pressed")
	_check(_game_state.call("is_option_unlocked", coral), "guardar compra la opción")
	_check(_simulation.get("coins") == 3, "guardar cobra el precio (%s)" % _simulation.get("coins"))
	panel.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
