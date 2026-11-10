extends SceneTree
## Pruebas de las mascotas (PR E): catálogo, rejilla de rutas A* por cuarto, comportamiento (pasea, duerme, se asusta),
## compra en la Tienda, guardado v8 y el cuarto real con sus mascotas.
## Uso: godot --headless --path . -s res://tests/test_pets.gd -- --save-path=user://test_pets.cfg
## Nota: con -s los autoloads no son identificadores globales; Pet, PetKeeper y PetShop dependen de ellos, así que se
## cargan como scripts (load + new/call) y GameState/Simulation se piden con root.get_node.

const PHASE_READY := 1
const ROOMS: Array[StringName] = [&"garage", &"oficina", &"data_center"]
const STEP := 1.0 / 30.0

var _failures: Array[String] = []
var _game_state: Node
var _save_system: Node
var _simulation: Node
var _pet_script: GDScript
var _shop_script: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_game_state = root.get_node("GameState")
	_save_system = root.get_node("SaveSystem")
	_simulation = root.get_node("Simulation")
	if _save_system.call("is_using_real_save"):
		printerr("test_pets: corre la prueba con una partida alterna, p. ej.: -- --save-path=user://test_pets.cfg")
		quit(1)
		return
	_save_system.call("delete_save")
	_pet_script = load("res://scripts/characters/pet.gd")
	_shop_script = load("res://scripts/rooms/pet_shop.gd")

	_test_catalog()
	_test_grids()
	_test_decor_blocks()
	_test_behavior()
	_test_shop()
	_test_save()
	await _test_room_scene()

	_save_system.call("delete_save")
	if _failures.is_empty():
		print("test_pets: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("FALLO: ", failure)
		quit(1)


func _test_catalog() -> void:
	var catalog := PetData.load_catalog()
	_check(catalog.size() == 2, "el catálogo trae gato y perro (%d)" % catalog.size())
	_check(PetData.find(&"gato") != null and PetData.find(&"perro") != null, "gato y perro existen")
	_check(PetData.find(&"no_existe") == null, "un id desconocido no existe")
	for pet: PetData in catalog:
		_check(pet.price > 0, "%s tiene precio" % pet.id)
		_check(ResourceLoader.exists(pet.get_sheet_path()), "existe la hoja de %s" % pet.id)
		var sheet := pet.load_sheet()
		var frame := PetData.get_frame_size()
		_check(sheet != null and sheet.get_width() == frame.x * 7 and sheet.get_height() == frame.y, "la hoja de %s son 7 cuadros de %s" % [pet.id, frame])
		_check(pet.scared_speed_m_s > pet.walk_speed_m_s, "%s corre más asustada" % pet.id)
		_check(pet.get_frame_texture(PetData.FRAME_IDLE) != null, "%s tiene miniatura" % pet.id)
	_check(PetData.get_max_total() >= 2, "el máximo de mascotas es razonable")
	for decor in DecorData.load_catalog():
		_check(decor.id != &"gato" and decor.id != &"perro", "el id %s no choca con la decoración" % decor.id)


func _grid(room_id: StringName, placed: Array = []) -> PetGrid:
	return PetGrid.new(RoomData.load_room(room_id), placed)


func _test_grids() -> void:
	for room_id in ROOMS:
		var room := RoomData.load_room(room_id)
		_check(room.has_pet_area(), "%s trae zona para mascotas" % room_id)
		var grid := _grid(room_id)
		var rest := grid.cell_of(room.pet_rest_point)
		_check(grid.is_free(rest), "%s: el punto de descanso está libre" % room_id)
		for pet_id: StringName in room.pet_shelters:
			var shelter := grid.cell_of(room.pet_shelters[pet_id])
			_check(grid.is_free(shelter), "%s: el refugio de %s está libre" % [room_id, pet_id])
			var path := grid.find_path(room.pet_rest_point, room.pet_shelters[pet_id])
			_check(path.size() >= 2, "%s: hay ruta del descanso al refugio de %s" % [room_id, pet_id])
			for point in path:
				_check(grid.is_free(grid.cell_of(point)), "%s: la ruta a %s no pisa casillas ocupadas" % [room_id, pet_id])
		# El escritorio, la puerta y los racks estorban.
		_check(not grid.is_free(grid.cell_of(Vector2(1.0, 2.0))), "%s: el escritorio está ocupado" % room_id)
		_check(not grid.is_free(grid.cell_of(Vector2(0.5, 5.0))), "%s: la puerta está ocupada" % room_id)
	var garage := _grid(&"garage")
	_check(garage.get_size() == Vector2i(12, 12), "el garage mide 12×12 casillas (%s)" % garage.get_size())
	_check(not garage.is_free(garage.cell_of(Vector2(1.5, 5.5))), "garage: el rack está ocupado")
	_check(not garage.is_free(garage.cell_of(Vector2(4.5, 1.5))), "garage: las cajas están ocupadas")
	_check(garage.is_free(garage.cell_of(Vector2(3.25, 3.25))), "garage: el centro del piso está libre")
	var office := _grid(&"oficina")
	_check(office.get_size() == Vector2i(18, 18), "la oficina mide 18×18 casillas (%s)" % office.get_size())
	_check(not office.is_free(office.cell_of(Vector2(1.5, 8.5))), "oficina: los racks están ocupados")
	var data_center := _grid(&"data_center")
	_check(data_center.get_size() == Vector2i(24, 24), "el data center mide 24×24 casillas (%s)" % data_center.get_size())
	# El vidrio separa el cuarto: del lado del escritorio no se llega al bay.
	var across := data_center.find_path(Vector2(2.25, 4.25), Vector2(8.25, 3.25))
	_check(across.is_empty(), "data center: no hay ruta a través del vidrio")
	var reachable := data_center.get_reachable_cells(data_center.cell_of(Vector2(2.25, 4.25)))
	for cell in reachable:
		_check(data_center.center_of(cell).x < 5.3, "data center: lo alcanzable queda antes del vidrio")
	# Una ruta rodea el escritorio sin cruzarlo.
	var around := garage.find_path(Vector2(0.25, 0.25), Vector2(2.25, 4.25))
	_check(around.size() >= 2, "garage: hay ruta que rodea el escritorio")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var target := garage.pick_random_point(Vector2(3.25, 3.25), rng)
		_check(target != Vector2.INF and garage.is_free(garage.cell_of(target)), "un destino al azar está libre")


func _test_decor_blocks() -> void:
	var sofa := {"id": "sillon", "ori": String(DecorData.find(&"sillon").get_default_orientation()), "x": 4.0, "y": 4.0}
	var rug := {"id": "tapete", "ori": String(DecorData.find(&"tapete").get_default_orientation()), "x": 6.0, "y": 2.0}
	var plain := _grid(&"oficina")
	var with_sofa := _grid(&"oficina", [sofa])
	var with_rug := _grid(&"oficina", [rug])
	_check(plain.is_free(plain.cell_of(Vector2(4.75, 4.75))), "oficina sin sillón: la casilla está libre")
	_check(not with_sofa.is_free(with_sofa.cell_of(Vector2(4.75, 4.75))), "el sillón ocupa su casilla")
	_check(with_rug.is_free(with_rug.cell_of(Vector2(6.75, 2.75))), "un tapete no estorba")
	var path := with_sofa.find_path(Vector2(3.25, 5.25), Vector2(7.25, 5.25))
	_check(path.size() >= 2, "hay ruta alrededor del sillón")
	for point in path:
		_check(with_sofa.is_free(with_sofa.cell_of(point)), "la ruta no cruza el sillón")


func _make_pet(pet_id: StringName, room_id: StringName, seed_value: int, sleep_chance: float = -1.0) -> Array:
	var data := PetData.find(pet_id).duplicate() as PetData
	if sleep_chance >= 0.0:
		data.sleep_chance = sleep_chance
	var room := RoomData.load_room(room_id)
	var grid := PetGrid.new(room, [])
	var pet: Node2D = _pet_script.new()
	root.add_child(pet)
	pet.call("setup", data, room, grid, grid.center_of(grid.cell_of(room.pet_rest_point)), seed_value)
	return [pet, grid, room]


func _test_behavior() -> void:
	for room_id in ROOMS:
		var parts := _make_pet(&"perro", room_id, 11)
		var pet: Node2D = parts[0]
		var grid: PetGrid = parts[1]
		var start: Vector2 = pet.call("get_position_m")
		var walked := 0.0
		var last := start
		var always_free := true
		for i in 3000:
			pet.call("step", STEP)
			var now: Vector2 = pet.call("get_position_m")
			walked += last.distance_to(now)
			last = now
			if not grid.is_free(grid.cell_of(now)):
				always_free = false
		_check(walked > 5.0, "%s: el perro pasea (%.1f m en 100 s)" % [room_id, walked])
		_check(always_free, "%s: el perro nunca pisa una casilla ocupada" % room_id)
		pet.queue_free()

	# El gato con probabilidad 1 se va a dormir al punto de descanso.
	var cat_parts := _make_pet(&"gato", &"oficina", 5, 1.0)
	var cat: Node2D = cat_parts[0]
	var cat_grid: PetGrid = cat_parts[1]
	var cat_room: RoomData = cat_parts[2]
	var slept := false
	for i in 3000:
		cat.call("step", STEP)
		if cat.call("is_sleeping"):
			slept = true
			break
	_check(slept, "el gato se echa a dormir")
	_check(cat_grid.cell_of(cat.call("get_position_m")) == cat_grid.cell_of(cat_room.pet_rest_point), "el gato duerme en el punto de descanso")
	# Se despierta solo.
	var woke := false
	for i in 1000:
		cat.call("step", STEP)
		if not cat.call("is_sleeping"):
			woke = true
			break
	_check(woke, "el gato se despierta")

	# Susto: corre al refugio, se queda ahí y al terminar vuelve a pasear.
	for pet_id: StringName in [&"gato", &"perro"]:
		var parts := _make_pet(pet_id, &"garage", 3, 0.0)
		var pet: Node2D = parts[0]
		var grid: PetGrid = parts[1]
		var room: RoomData = parts[2]
		for i in 90:
			pet.call("step", STEP)
		pet.call("set_scared", true)
		_check(pet.call("is_scared"), "%s se asusta" % pet_id)
		for i in 900:
			pet.call("step", STEP)
		var shelter_cell := grid.cell_of(room.pet_shelters[pet_id])
		_check(grid.cell_of(pet.call("get_position_m")) == shelter_cell, "%s se refugia en su casilla" % pet_id)
		_check(pet.call("get_target_m") == Vector2.INF, "%s se queda quieto en el refugio" % pet_id)
		var held: Vector2 = pet.call("get_position_m")
		for i in 300:
			pet.call("step", STEP)
		_check(pet.call("get_position_m") == held, "%s no se mueve mientras dura la saturación" % pet_id)
		pet.call("set_scared", false)
		var moved := false
		for i in 1500:
			pet.call("step", STEP)
			if pet.call("get_position_m") != held:
				moved = true
				break
		_check(moved and not pet.call("is_scared"), "%s vuelve a pasear al terminar" % pet_id)
		pet.queue_free()

	# Si colocan un mueble encima, se aparta.
	var parts2 := _make_pet(&"perro", &"oficina", 9, 0.0)
	var dog: Node2D = parts2[0]
	var room2: RoomData = parts2[2]
	var dog_grid: PetGrid = parts2[1]
	var cell := dog_grid.cell_of(dog.call("get_position_m"))
	var rect := Rect2(dog_grid.center_of(cell) - Vector2(0.25, 0.25), Vector2(0.5, 0.5))
	room2.pet_blocked.append(rect)
	dog_grid.rebuild([])
	dog.call("on_grid_changed")
	_check(dog_grid.is_free(dog_grid.cell_of(dog.call("get_position_m"))), "la mascota se aparta del mueble nuevo")
	room2.pet_blocked.erase(rect)
	dog.queue_free()
	cat.queue_free()


func _test_shop() -> void:
	_game_state.call("start_new_game", "Prueba", "TestCorp")
	var cat := PetData.find(&"gato")
	var dog := PetData.find(&"perro")
	_check(_game_state.get("pets").is_empty(), "una partida nueva no trae mascotas")
	_check(not _shop_script.call("can_buy", cat), "etapa 1: la tienda de mascotas está cerrada")
	_simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": cat.price + dog.price + 100})
	_check(_simulation.get("phase") == PHASE_READY, "etapa 2 entre oleadas")
	_check(_shop_script.call("can_buy", cat), "con monedas se puede comprar el gato")
	_check(_shop_script.call("buy", cat), "se compra el gato")
	_check(_simulation.get("coins") == dog.price + 100, "comprar cobra el precio exacto (%s)" % _simulation.get("coins"))
	_check(_game_state.call("count_pets", &"gato") == 1, "el gato quedó en la empresa")
	_check(_shop_script.call("buy", dog), "se compra el perro")
	_check(_simulation.get("coins") == 100, "el perro cobró su precio")
	_check(not _shop_script.call("buy", dog), "sin monedas no se compra")
	_check(_shop_script.call("get_buy_block_reason", dog) == "Faltan monedas", "el motivo es 'Faltan monedas'")
	_check(_simulation.get("coins") == 100 and _game_state.get("pets").size() == 2, "una compra rechazada no cobra")
	# Varias del mismo tipo.
	_simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 100000})
	_check(_shop_script.call("buy", cat), "se puede comprar un segundo gato")
	_check(_game_state.call("count_pets", &"gato") == 2, "hay dos gatos")
	# Máximo.
	while _game_state.get("pets").size() < PetData.get_max_total():
		_game_state.call("add_pet", &"perro")
	_check(not _shop_script.call("can_buy", cat), "con el máximo de mascotas ya no se compra")
	_check(str(_shop_script.call("get_buy_block_reason", cat)).begins_with("Máximo"), "el motivo es el máximo")
	# Vender: devuelve venta_pct del precio y libera un lugar para comprar otra.
	_game_state.set("pets", [] as Array[StringName])
	_simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 100000})
	_check(PetData.get_sell_percent() == 50, "venta_pct del JSON = 50")
	_check(cat.get_sell_price() == 200 and dog.get_sell_price() == 250, "vender devuelve la mitad (%d / %d)" % [cat.get_sell_price(), dog.get_sell_price()])
	_check(not _shop_script.call("can_sell", cat), "sin gatos no se puede vender uno")
	_check(_shop_script.call("get_sell_block_reason", cat) == "No tienes ninguno", "el motivo es 'No tienes ninguno'")
	_check(not _shop_script.call("sell", cat), "vender sin tener no hace nada")
	_check(_simulation.get("coins") == 100000, "vender sin tener no mueve monedas")
	for i in 3:
		_shop_script.call("buy", cat)
		_shop_script.call("buy", dog)
	_check(_game_state.get("pets").size() == PetData.get_max_total(), "3 gatos y 3 perros llenan el máximo")
	_check(not _shop_script.call("can_buy", cat), "con 6 mascotas no se compra otra")
	var coins_before: int = _simulation.get("coins")
	_check(_shop_script.call("sell", dog), "se vende un perro")
	_check(_simulation.get("coins") == coins_before + dog.get_sell_price(), "vender un perro paga 250")
	_check(_game_state.call("count_pets", &"perro") == 2 and _game_state.call("count_pets", &"gato") == 3, "quedan 3 gatos y 2 perros")
	_check(_shop_script.call("can_buy", cat), "al vender se libera un lugar")
	_check(_shop_script.call("buy", cat), "con el lugar libre se compra otro gato")
	_check(_game_state.call("count_pets", &"gato") == 4, "ahora hay 4 gatos")
	# Cambiar todos los perros por gatos hasta tener 6 gatos.
	while _game_state.call("count_pets", &"perro") > 0:
		_shop_script.call("sell", dog)
	while _game_state.call("count_pets", &"gato") < PetData.get_max_total():
		_check(_shop_script.call("buy", cat), "se compra un gato más")
	_check(_game_state.call("count_pets", &"gato") == 6 and _game_state.call("count_pets", &"perro") == 0, "se llegó a 6 gatos y 0 perros")
	_check(not _shop_script.call("can_sell", dog), "sin perros no se puede vender uno")
	# Durante una oleada la tienda está cerrada, también para vender.
	_simulation.call("start_wave")
	_check(not _shop_script.call("can_sell", cat), "durante una oleada no se vende")
	_simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 100000})
	_game_state.set("pets", [] as Array[StringName])
	# Durante una oleada la tienda está cerrada.
	_game_state.set("pets", [] as Array[StringName])
	_simulation.call("start_wave")
	_check(not _shop_script.call("can_buy", cat), "durante una oleada no se compra")


func _test_save() -> void:
	_game_state.call("start_new_game", "Prueba", "TestCorp")
	_simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 5000})
	_game_state.call("add_pet", &"gato")
	_game_state.call("add_pet", &"perro")
	_game_state.call("add_pet", &"gato")
	_check(_save_system.call("save_game"), "se guarda la partida")
	var save_path: String = _save_system.get("save_path")
	var backup := save_path + ".bak"
	DirAccess.copy_absolute(save_path, backup)
	_game_state.call("start_new_game", "Otro", "Otra")
	DirAccess.copy_absolute(backup, save_path)
	DirAccess.remove_absolute(backup)
	_check(_save_system.call("load_game"), "se carga la partida")
	var expected: Array[StringName] = [&"gato", &"perro", &"gato"]
	var loaded_pets: Array = _game_state.get("pets")
	_check(loaded_pets == expected, "las mascotas se conservan (%s)" % [loaded_pets])
	var config := ConfigFile.new()
	_check(config.load(save_path) == OK and int(config.get_value("meta", "version", 0)) == 8, "el guardado es v8")
	# Un guardado anterior (sin sección de mascotas) empieza sin mascotas.
	config.erase_section("pets")
	config.save(save_path)
	_game_state.call("add_pet", &"perro")
	_check(_save_system.call("load_game"), "se carga un guardado sin mascotas")
	_check(_game_state.get("pets").is_empty(), "guardado viejo: sin mascotas")
	# Ids desconocidos y más del máximo se descartan.
	var raw: Array = ["gato", "dragon", "perro"]
	for i in PetData.get_max_total() + 3:
		raw.append("gato")
	_game_state.call("restore", {"pets": raw})
	var restored: Array = _game_state.get("pets")
	_check(restored.size() == PetData.get_max_total(), "no se pasa del máximo (%d)" % restored.size())
	_check(not restored.has(&"dragon"), "los ids desconocidos se descartan")


func _test_room_scene() -> void:
	for room_id in ROOMS:
		_game_state.call("start_new_game", "Prueba", "TestCorp")
		_game_state.set("tutorial_step", -1)
		_simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 5000})
		_game_state.call("add_pet", &"gato")
		_game_state.call("add_pet", &"perro")
		var scene := (load("res://scenes/rooms/%s.tscn" % room_id) as PackedScene).instantiate()
		root.add_child(scene)
		await process_frame
		var keeper: Node = scene.call("get_pet_keeper")
		_check(keeper != null, "%s trae su cuidador de mascotas" % room_id)
		var pets: Array = keeper.call("get_pets")
		_check(pets.size() == 2, "%s muestra las 2 mascotas (%d)" % [room_id, pets.size()])
		for pet in pets:
			_check((pet as Node).get_parent() == scene.get_node("%YSort"), "%s: las mascotas van en el YSort" % room_id)
		# Varias mascotas del mismo tipo no se encimen: ni al aparecer ni en el refugio.
		_game_state.set("pets", [&"gato", &"gato", &"gato", &"perro", &"perro"] as Array[StringName])
		_game_state.emit_signal("pets_changed")
		var crowd: Array = keeper.call("get_pets")
		_check(crowd.size() == 5, "%s: 5 mascotas para probar que no se encimen" % room_id)
		var crowd_grid: PetGrid = keeper.call("get_grid")
		var spawn_cells := {}
		for pet in crowd:
			spawn_cells[crowd_grid.cell_of(pet.call("get_position_m"))] = true
		_check(spawn_cells.size() == crowd.size(), "%s: al aparecer cada mascota tiene su casilla (%d de %d)" % [room_id, spawn_cells.size(), crowd.size()])
		_simulation.emit_signal("saturation_changed", true)
		for i in 1500:
			for pet in crowd:
				pet.call("step", STEP)
		var shelter_cells := {}
		for pet in crowd:
			shelter_cells[crowd_grid.cell_of(pet.call("get_position_m"))] = true
		_check(shelter_cells.size() == crowd.size(), "%s: en el refugio cada mascota tiene su casilla (%d de %d)" % [room_id, shelter_cells.size(), crowd.size()])
		_simulation.emit_signal("saturation_changed", false)
		_game_state.set("pets", [&"gato", &"perro"] as Array[StringName])
		_game_state.emit_signal("pets_changed")
		# Varios gatos que duermen a la vez no lo hacen encimados.
		var cat_data := PetData.find(&"gato")
		var old_chance := cat_data.sleep_chance
		cat_data.sleep_chance = 1.0
		_game_state.set("pets", [&"gato", &"gato", &"gato", &"gato"] as Array[StringName])
		_game_state.emit_signal("pets_changed")
		var sleepers: Array = keeper.call("get_pets")
		var all_asleep := false
		for i in 3000:
			for pet in sleepers:
				pet.call("step", STEP)
			all_asleep = true
			for pet in sleepers:
				if not pet.call("is_sleeping"):
					all_asleep = false
			if all_asleep:
				break
		var sleep_cells := {}
		for pet in sleepers:
			sleep_cells[crowd_grid.cell_of(pet.call("get_position_m"))] = true
		_check(all_asleep, "%s: los 4 gatos llegan a dormir" % room_id)
		_check(sleep_cells.size() == sleepers.size(), "%s: cada gato duerme en su casilla (%d de %d)" % [room_id, sleep_cells.size(), sleepers.size()])
		cat_data.sleep_chance = old_chance
		_game_state.set("pets", [&"gato", &"perro"] as Array[StringName])
		_game_state.emit_signal("pets_changed")
		# Comprar una más la agrega al cuarto en vivo.
		_game_state.call("add_pet", &"gato")
		_check(keeper.call("get_pets").size() == 3, "%s: una compra nueva aparece al momento" % room_id)
		# Saturación: se asustan; al terminar, se calman.
		_simulation.emit_signal("saturation_changed", true)
		for pet in keeper.call("get_pets"):
			_check(pet.call("is_scared"), "%s: se asustan con la saturación" % room_id)
		_simulation.emit_signal("saturation_changed", false)
		for pet in keeper.call("get_pets"):
			_check(not pet.call("is_scared"), "%s: se calman al terminar" % room_id)
		# Decoración nueva: la rejilla se actualiza.
		var grid: PetGrid = keeper.call("get_grid")
		if RoomData.load_room(room_id).has_decor():
			var sofa := {"id": "sillon", "ori": String(DecorData.find(&"sillon").get_default_orientation()), "x": 4.0, "y": 4.0}
			_game_state.call("place_decor", room_id, sofa)
			_check(not grid.is_free(grid.cell_of(Vector2(4.75, 4.75))), "%s: el sillón nuevo ocupa su casilla" % room_id)
			for pet in keeper.call("get_pets"):
				var at: Vector2 = pet.call("get_position_m")
				_check(grid.is_free(grid.cell_of(at)), "%s: ninguna mascota quedó sobre el sillón" % room_id)
		# Quitar mascotas las saca del cuarto.
		_game_state.set("pets", [&"perro"] as Array[StringName])
		_game_state.emit_signal("pets_changed")
		await process_frame
		_check(keeper.call("get_pets").size() == 1, "%s: quitar mascotas las saca del cuarto" % room_id)
		if room_id == &"oficina":
			await _test_shop_panel_sell(scene)
		scene.queue_free()
		await process_frame


## Pestaña Mascotas de la Tienda: "Vender" pide un segundo toque y luego vende y libera el lugar.
func _test_shop_panel_sell(scene: Node) -> void:
	_simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 1000})
	_game_state.set("pets", [&"gato", &"gato", &"perro"] as Array[StringName])
	_game_state.emit_signal("pets_changed")
	var panel: CanvasLayer = scene.get_node("%ShopPanel")
	panel.call("open", 2)
	await process_frame
	var sell_cat: Button = panel.call("get_row_button", &"vender_gato")
	var sell_dog: Button = panel.call("get_row_button", &"vender_perro")
	_check(sell_cat != null and not sell_cat.disabled, "el botón Vender del gato está activo")
	_check(sell_cat.text.begins_with("Vender") and "200" in sell_cat.text, "el botón dice 'Vender +200' (%s)" % sell_cat.text)
	_check(sell_dog.text.begins_with("Vender") and "250" in sell_dog.text, "el botón dice 'Vender +250' (%s)" % sell_dog.text)
	await process_frame
	var cat_rect := Rect2(sell_cat.global_position, sell_cat.size)
	var dog_rect := Rect2(sell_dog.global_position, sell_dog.size)
	_check(cat_rect.size.x > 0.0 and sell_cat.get_minimum_size().x <= sell_cat.size.x, "'Vender' cabe en su botón (%s)" % sell_cat.size)
	sell_cat.pressed.emit()
	await process_frame
	await process_frame
	_check(_game_state.call("count_pets", &"gato") == 2, "el primer toque no vende")
	sell_cat = panel.call("get_row_button", &"vender_gato")
	sell_dog = panel.call("get_row_button", &"vender_perro")
	_check(sell_cat.text.begins_with("¿Seguro?"), "el primer toque pide confirmar (%s)" % sell_cat.text)
	_check(sell_cat.get_minimum_size().x <= sell_cat.size.x, "'¿Seguro? +200' cabe en su botón (min %s, tam %s)" % [sell_cat.get_minimum_size().x, sell_cat.size.x])
	_check(Rect2(sell_cat.global_position, sell_cat.size) == cat_rect, "el botón no se mueve ni cambia de tamaño al pedir confirmar")
	_check(Rect2(sell_dog.global_position, sell_dog.size) == dog_rect, "los demás botones tampoco se mueven")
	sell_cat.pressed.emit()
	await process_frame
	_check(_game_state.call("count_pets", &"gato") == 1, "el segundo toque vende el gato")
	_check(_simulation.get("coins") == 1200, "vender el gato paga 200 (%s)" % _simulation.get("coins"))
	sell_cat = panel.call("get_row_button", &"vender_gato")
	_check(sell_cat.text.begins_with("Vender"), "después de vender el botón vuelve a 'Vender'")
	# Un temporizador viejo no cancela una confirmación nueva.
	var old_token: int = panel.get("_confirm_token")
	(panel.call("get_row_button", &"vender_perro") as Button).pressed.emit()
	await process_frame
	panel.call("_cancel_confirmation", old_token)
	await process_frame
	_check((panel.call("get_row_button", &"vender_perro") as Button).text.begins_with("¿Seguro?"), "un temporizador viejo no cancela la confirmación nueva")
	panel.call("_cancel_confirmation", panel.get("_confirm_token"))
	await process_frame
	_check((panel.call("get_row_button", &"vender_perro") as Button).text.begins_with("Vender"), "el temporizador vigente sí cancela")
	# Tocar otra cosa cancela la confirmación.
	sell_dog = panel.call("get_row_button", &"vender_perro")
	sell_dog.pressed.emit()
	await process_frame
	(panel.call("get_row_button", &"gato") as Button).pressed.emit()
	await process_frame
	_check(_game_state.call("count_pets", &"perro") == 1, "comprar cancela la confirmación sin vender el perro")
	sell_dog = panel.call("get_row_button", &"vender_perro")
	_check(sell_dog.text.begins_with("Vender"), "la confirmación se canceló (%s)" % sell_dog.text)
	# Con 0 de un tipo, el botón queda desactivado.
	_game_state.set("pets", [&"gato"] as Array[StringName])
	_game_state.emit_signal("pets_changed")
	await process_frame
	_check((panel.call("get_row_button", &"vender_perro") as Button).disabled, "sin perros el botón Vender está desactivado")
	panel.call("close")


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
