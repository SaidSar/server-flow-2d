extends SceneTree
## Pruebas de la tienda y la decoración de la oficina y del data center: reglas de colocación (DecorLayout), monedas,
## inventario, guardado y cuándo abre la tienda.
## Uso: godot --headless --path . -s res://tests/test_decor.gd -- --save-path=user://test_decor.cfg
## Nota: con -s los autoloads se registran después de compilar este script; DecorShop depende de
## ellos, así que se carga como recurso y se llama con call().

const PHASE_READY := 1
const PHASE_RUNNING := 2

var _failures: Array[String] = []
var _shop: GDScript


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state: Node = root.get_node("GameState")
	var save_system: Node = root.get_node("SaveSystem")
	var simulation: Node = root.get_node("Simulation")
	if save_system.call("is_using_real_save"):
		printerr("test_decor: corre la prueba con una partida alterna para no tocar la real, p. ej.: -- --save-path=user://test_decor.cfg")
		quit(1)
		return
	save_system.call("delete_save")
	_shop = load("res://scripts/rooms/decor_shop.gd")

	_test_projection()
	_test_layout()
	_test_room_sizes()
	_test_shop_availability(game_state, simulation)
	await _test_buy_place_cancel(game_state, simulation)
	await _test_data_center_layers(game_state, simulation)
	await _test_stage_change_keeps_decor(game_state, save_system, simulation)
	_test_save_load(game_state, save_system, simulation)

	save_system.call("delete_save")
	if _failures.is_empty():
		print("TEST DECOR OK")
		quit(0)
	else:
		printerr("TEST DECOR FALLÓ:\n- " + "\n- ".join(_failures))
		quit(1)


## Cada cuarto lee el tamaño de su cuadrícula de su JSON: la oficina mide 9×9 m y el data center
## 12×12 m. En el data center el vidrio y el sector de los racks están ocupados; delante de ellos no.
func _test_room_sizes() -> void:
	var office := RoomData.load_room(&"oficina")
	var data_center := RoomData.load_room(&"data_center")
	_check(office.projection.bounds == Rect2(0, 0, 9, 9), "la oficina mide 9×9 m (%s)" % office.projection.bounds)
	_check(data_center.has_decor() and data_center.projection.bounds == Rect2(0, 0, 12, 12), "el data center mide 12×12 m (%s)" % data_center.projection.bounds)
	_check(is_equal_approx(data_center.projection.cell_m, 0.5), "el data center usa la cuadrícula de 0.5 m")

	var sofa := DecorData.find(&"sillon")
	var picture := DecorData.find(&"cuadro")
	var in_office := DecorLayout.new(office)
	var in_data_center := DecorLayout.new(data_center)
	_check(not in_office.can_place(sofa, &"a", Vector2(3.0, 10.0)), "y = 10 m queda fuera de la oficina")
	_check(in_data_center.can_place(sofa, &"a", Vector2(3.0, 10.0)), "y = 10 m sí cabe en el data center")
	# Zona azul del playtest: x 5.5–12, y 0–7. Zona roja: x 5.5–12, y 7–12.
	_check(in_data_center.can_place(sofa, &"a", Vector2(7.0, 2.0)), "data center: se decora delante del sector de los racks")
	_check(in_data_center.can_place(sofa, &"a", Vector2(5.5, 0.0)), "data center: esquina junto al vidrio")
	_check(in_data_center.can_place(sofa, &"a", Vector2(10.5, 6.0)), "data center: esquina hasta el límite (x 12, y 7)")
	_check(not in_data_center.can_place(sofa, &"a", Vector2(7.0, 6.5)), "data center: no se cruza el límite y = 7")
	for corner: Vector2 in [Vector2(5.5, 8.0), Vector2(6.0, 10.5), Vector2(10.0, 8.0), Vector2(10.5, 11.0)]:
		_check(not in_data_center.can_place(sofa, &"a", corner), "data center: sector de los racks bloqueado en %s" % corner)
	for x: float in [7.025, 8.15, 9.275]:
		for y: float in [7.025, 9.025, 11.025]:
			_check(not in_data_center.can_place(DecorData.find(&"planta"), &"a", Vector2(x, y)), "data center: no sobre el rack en (%.3f, %.3f)" % [x, y])
	_check(not in_data_center.can_place(sofa, &"a", Vector2(4.0, 1.0)), "data center: no se encima con el vidrio")
	_check(not in_data_center.can_place(sofa, &"a", Vector2(7.5, 8.0)), "data center: no sobre el bay de racks")
	_check(not in_data_center.can_place(sofa, &"a", Vector2(0.5, 1.5)), "data center: no sobre el escritorio")
	var on_right := in_data_center.snap_position(picture, &"der", Vector2(3.2, 0.0))
	_check(on_right.is_equal_approx(Vector2(3.0, 11.95)), "data center: el cuadro se pega al muro derecho en y = 12 (%s)" % on_right)
	_check(in_data_center.can_place(picture, &"der", on_right), "data center: cuadro en el muro derecho del lado del escritorio")
	_check(not in_data_center.can_place(picture, &"der", Vector2(7.0, 11.95)), "data center: no se cuelga nada en el muro del bay (placa de Firewall)")
	_check(not in_data_center.can_place(picture, &"izq", Vector2(0.0, 4.5)), "data center: no sobre la puerta")
	_check(in_data_center.can_place(picture, &"izq", Vector2(0.0, 9.0)), "data center: el muro izquierdo es más largo que en la oficina")

	# El tapete respeta las mismas zonas que los demás objetos de piso.
	var rug := DecorData.find(&"tapete")
	_check(not in_data_center.can_place(rug, &"a", Vector2(4.5, 2.0)), "data center: el tapete no atraviesa el vidrio")
	_check(not in_data_center.can_place(rug, &"a", Vector2(7.5, 8.0)), "data center: el tapete no va sobre los racks")
	_check(not in_data_center.can_place(rug, &"a", Vector2(0.5, 1.5)), "data center: el tapete no va bajo el escritorio")
	_check(not in_data_center.can_place(rug, &"a", Vector2(0.0, 4.5)), "data center: el tapete no va frente a la puerta")
	_check(in_data_center.can_place(rug, &"a", Vector2(2.5, 6.0)), "data center: el tapete cabe del lado del escritorio")
	_check(in_data_center.can_place(rug, &"a", Vector2(6.0, 2.0)), "data center: el tapete cabe en el pasillo")
	_check(not in_office.can_place(rug, &"a", Vector2(0.5, 1.5)), "oficina: el tapete no va bajo el escritorio")

	# Zonas reservadas para el catálogo de referencias personales (todavía sin objetos).
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Paths.ROOM_DATA % "data_center"))
	var zones: Array = raw["cuadricula"]["zonas_catalogo_extra"]
	var kinds := zones.map(func(zone: Dictionary) -> String: return str(zone["tipo"]))
	_check(zones.size() == 3 and kinds.count("pared") == 2 and kinds.count("piso") == 1, "3 zonas reservadas del catálogo extra (2 de pared y 1 de piso)")
	# Las de pared van a los lados del escritorio, sin tramos en común con el monitor ni con la puerta.
	var desk: Dictionary = raw["cuadricula"]["ocupado_m"][0]
	var side_of_desk := {"antes": false, "despues": false}
	for zone: Dictionary in zones:
		if zone["tipo"] != "pared":
			continue
		var start := float(zone["y"][0])
		var end := float(zone["y"][1])
		side_of_desk["antes"] = side_of_desk["antes"] or (start < float(desk["y"][0]) and end <= 1.1)
		side_of_desk["despues"] = side_of_desk["despues"] or (start >= 3.5 and end <= 4.3)
		for forbidden: Rect2 in data_center.wall_forbidden[RoomProjection.WALL_LEFT]:
			_check(end <= forbidden.position.x or start >= forbidden.end.x, "zona %s sin encimarse con un tramo prohibido del muro izquierdo" % zone["id"])
	_check(side_of_desk["antes"] and side_of_desk["despues"], "hay una zona de pared a cada lado del escritorio")


## Lo de piso delante del vidrio se dibuja en RackBay (encima del vidrio, ordenado con los racks);
## lo de atrás, en YSort. Al mover el fantasma cambia de capa.
func _test_data_center_layers(game_state: Node, simulation: Node) -> void:
	simulation.call("load_checkpoint", {"stage": "enterprise", "wave": 1, "coins": 5000})
	var room := (load("res://scenes/rooms/data_center.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	var placer: Node = room.get_node("%DecorPlacer")
	game_state.call("place_decor", &"data_center", {"id": "sillon", "ori": "a", "x": 3.0, "y": 8.0})
	game_state.call("place_decor", &"data_center", {"id": "sillon", "ori": "a", "x": 5.5, "y": 2.0})
	_check((placer.call("get_item_node", 0) as Node2D).get_parent() == room.get_node("%YSort"), "detrás del vidrio se dibuja en YSort")
	_check((placer.call("get_item_node", 1) as Node2D).get_parent() == room.get_node("%RackBay"), "en el pasillo se dibuja en RackBay")
	placer.call("start_placement", DecorData.find(&"planta"), 1)
	placer.call("move_ghost_to", Vector2(3.0, 6.0))
	_check((placer.call("get_ghost") as Node2D).get_parent() == room.get_node("%YSort"), "el fantasma detrás del vidrio va en YSort")
	placer.call("move_ghost_to", Vector2(6.5, 3.0))
	_check((placer.call("get_ghost") as Node2D).get_parent() == room.get_node("%RackBay"), "el fantasma pasa a RackBay al cruzar el vidrio")
	placer.call("cancel_placement")
	game_state.call("remove_placed_decor", &"data_center", 1)
	game_state.call("remove_placed_decor", &"data_center", 0)
	room.free()
	await process_frame


## Al pasar de la oficina al data center, lo colocado pasa al inventario (trofeo incluido), se puede
## volver a colocar y sobrevive a guardar y cargar. No se duplica ni se puede reclamar otro trofeo.
func _test_stage_change_keeps_decor(game_state: Node, save_system: Node, simulation: Node) -> void:
	game_state.call("start_new_game", "Prueba", "TestCorp")
	simulation.get("stage_stats")[&"scale_up"] = {"stars": 1}
	game_state.call("add_to_inventory", &"planta")
	game_state.call("place_decor", &"oficina", {"id": "sillon", "ori": "a", "x": 4.0, "y": 4.0})
	game_state.call("place_decor", &"oficina", {"id": "trofeo", "ori": "a", "x": 6.0, "y": 6.0})
	game_state.call("place_decor", &"oficina", {"id": "cuadro", "ori": "der", "x": 2.5, "y": 8.95})
	simulation.call("load_checkpoint", {"stage": "enterprise", "wave": 1, "coins": 500, "stage_stats": {"scale_up": {"stars": 1}}})
	var room := (load("res://scenes/rooms/data_center.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	_check((game_state.call("get_placed_decor", &"oficina") as Array).is_empty(), "al llegar al data center ya nada queda en la oficina")
	for decor_id: StringName in [&"planta", &"sillon", &"trofeo", &"cuadro"]:
		_check(game_state.call("count_in_inventory", decor_id) == 1, "%s está una sola vez en el inventario" % decor_id)
	_check(not _shop.call("is_trophy_claimable"), "el trofeo no se reclama dos veces")

	var placer: Node = room.get_node("%DecorPlacer")
	placer.call("_on_place_requested", &"trofeo")
	placer.call("move_ghost_to", Vector2(3.0, 8.0))
	_check(placer.call("confirm_placement"), "el trofeo se vuelve a colocar en el data center")
	_check(game_state.call("count_in_inventory", &"trofeo") == 0 and (game_state.call("get_placed_decor", &"data_center") as Array).size() == 1, "colocarlo lo saca del inventario")

	_check(save_system.call("save_game"), "guardar después de cambiar de etapa")
	_check(save_system.call("load_game"), "cargar después de cambiar de etapa")
	_check(game_state.call("count_in_inventory", &"sillon") == 1 and game_state.call("count_in_inventory", &"cuadro") == 1, "el inventario sobrevive a guardar y cargar")
	_check(game_state.call("count_owned", &"trofeo") == 1, "el trofeo sobrevive a guardar y cargar")
	room.free()
	await process_frame

	# Una partida guardada con objetos atorados en la oficina los recupera al abrir el cuarto.
	game_state.call("place_decor", &"oficina", {"id": "acuario", "ori": "a", "x": 6.5, "y": 2.0})
	_check(save_system.call("save_game") and save_system.call("load_game"), "partida con objetos atorados en la oficina")
	room = (load("res://scenes/rooms/data_center.tscn") as PackedScene).instantiate()
	root.add_child(room)
	await process_frame
	_check(game_state.call("count_in_inventory", &"acuario") == 1, "abrir el cuarto recupera lo atorado de una partida vieja")
	_check(game_state.call("count_owned", &"trofeo") == 1, "el trofeo colocado en este cuarto no se mueve")
	room.free()
	await process_frame


func _test_projection() -> void:
	var room := RoomData.load_room(&"oficina")
	var projection := room.projection
	_check(projection != null and room.has_decor(), "la oficina tiene proyección")
	_check(not RoomData.load_room(&"garage").has_decor(), "el garage no tiene decoración")
	_check(projection.world_to_canvas(0, 0).is_equal_approx(Vector2(36.0, 1105.829)), "origen de la proyección")
	var point := Vector2(3.25, 6.5)
	var canvas := projection.world_to_canvas(point.x, point.y)
	_check(projection.canvas_to_world(canvas).is_equal_approx(point), "canvas_to_world invierte world_to_canvas (z = 0)")
	var on_wall := projection.world_to_canvas(4.0, 9.0, 2.2)
	_check(projection.canvas_to_wall(on_wall, RoomProjection.WALL_RIGHT, 9.0).is_equal_approx(Vector2(4.0, 2.2)), "canvas_to_wall en el muro derecho")
	_check(is_equal_approx(projection.snap(2.74), 2.5) and is_equal_approx(projection.snap(2.76), 3.0), "cuadrícula de 0.5 m")


func _test_layout() -> void:
	var room := RoomData.load_room(&"oficina")
	var sofa := DecorData.find(&"sillon")
	var plant := DecorData.find(&"planta")
	var rug := DecorData.find(&"tapete")
	var picture := DecorData.find(&"cuadro")
	var neon := DecorData.find(&"neon")
	var empty := DecorLayout.new(room)

	# Zonas ocupadas y límites del cuarto
	_check(not empty.can_place(sofa, &"a", Vector2(0.5, 1.5)), "no se coloca sobre el escritorio")
	_check(not empty.can_place(plant, &"a", Vector2(0.5, 4.5)), "no se coloca frente a la puerta")
	_check(not empty.can_place(plant, &"a", Vector2(1.5, 8.5)), "no se coloca sobre los racks")
	_check(empty.can_place(sofa, &"a", Vector2(4.0, 4.0)), "el sillón cabe en el centro")
	_check(not empty.can_place(sofa, &"a", Vector2(8.0, 4.0)), "no se sale del cuarto")
	var snapped := empty.snap_position(sofa, &"a", Vector2(8.9, 0.1))
	_check(empty.get_rect(sofa, &"a", snapped).end.x <= 9.0 and snapped.y >= 0.0, "snap_position deja el objeto dentro del cuarto")

	# Encimar objetos de piso
	var with_sofa := DecorLayout.new(room, [{"id": "sillon", "ori": "a", "x": 4.0, "y": 4.0}])
	_check(not with_sofa.can_place(plant, &"a", Vector2(4.5, 4.5)), "no se enciman objetos de piso")
	_check(with_sofa.can_place(plant, &"a", Vector2(5.5, 4.0)), "objetos que solo se tocan sí caben")
	_check(with_sofa.can_place(sofa, &"a", Vector2(4.0, 4.0), 0), "un objeto no choca consigo mismo al moverlo")

	# Tapete: otros objetos encima, pero no otro tapete
	var with_rug := DecorLayout.new(room, [{"id": "tapete", "ori": "a", "x": 4.0, "y": 4.0}])
	_check(with_rug.can_place(sofa, &"a", Vector2(4.0, 4.0)), "el sillón cabe sobre el tapete")
	_check(not with_rug.can_place(rug, &"a", Vector2(5.0, 4.5)), "un tapete no se encima con otro")
	_check(with_rug.can_place(rug, &"a", Vector2(6.0, 4.0)), "otro tapete al lado sí cabe")

	# Girar intercambia la huella
	_check(sofa.get_rotated(&"a") == &"b" and sofa.get_rotated(&"b") == &"a", "girar alterna a ↔ b")
	_check(empty.get_rect(sofa, &"a", Vector2.ZERO).size == Vector2(1.5, 1.0) and empty.get_rect(sofa, &"b", Vector2.ZERO).size == Vector2(1.0, 1.5), "girar intercambia la huella del sillón")
	_check(picture.get_rotated(&"der") == &"izq", "girar un cuadro cambia de muro")
	_check(empty.get_rect(picture, &"izq", Vector2.ZERO).size == Vector2(0.05, 0.9), "en el muro izquierdo la huella va a lo largo de y")

	# Objetos de pared: pegados al muro y fuera de sus tramos prohibidos
	var on_right := empty.snap_position(picture, &"der", Vector2(3.2, 0.0))
	_check(on_right.is_equal_approx(Vector2(3.0, 8.95)), "el cuadro se pega al muro derecho (%s)" % on_right)
	var on_left := empty.snap_position(picture, &"izq", Vector2(0.5, 0.0))
	_check(on_left.is_equal_approx(Vector2(0.0, 0.0)), "el cuadro se pega al muro izquierdo (%s)" % on_left)
	_check(not empty.can_place(picture, &"der", Vector2(1.0, 8.95)), "muro derecho: no sobre los racks")
	_check(not empty.can_place(picture, &"der", Vector2(4.5, 8.95)), "muro derecho: no sobre la primera ventana")
	_check(not empty.can_place(picture, &"der", Vector2(7.0, 8.95)), "muro derecho: no sobre la segunda ventana")
	_check(empty.can_place(picture, &"der", Vector2(2.5, 8.95)), "muro derecho: entre los racks y la ventana sí")
	_check(not empty.can_place(picture, &"izq", Vector2(0.0, 1.5)), "muro izquierdo: no detrás del monitor")
	_check(not empty.can_place(picture, &"izq", Vector2(0.0, 4.5)), "muro izquierdo: no sobre la puerta")
	_check(not empty.can_place(picture, &"izq", Vector2(0.0, 7.0)), "muro izquierdo: no sobre el pizarrón")
	_check(empty.can_place(picture, &"izq", Vector2(0.0, 0.0)), "muro izquierdo: junto a la esquina sí")
	_check(empty.can_place(neon, &"der", Vector2(2.5, 8.96)), "el neón cabe entre los racks y la ventana")

	# Las zonas prohibidas tienen altura: solo chocan si también se enciman en z.
	_check(is_equal_approx(picture.height_m.x, 1.25) and is_equal_approx(neon.height_m.y, 2.45), "las alturas de los objetos de pared vienen del catálogo")
	_check(empty.can_place(neon, &"izq", Vector2(0.0, 1.5)), "el neón (z 1.95–2.45) cabe sobre el escritorio (monitor z 0.75–1.6)")
	_check(not empty.can_place(picture, &"izq", Vector2(0.0, 1.5)), "el cuadro (z 1.25–1.95) choca con el monitor")
	_check(not empty.can_place(neon, &"izq", Vector2(0.0, 4.0)), "el neón choca con la puerta (z 0–2.15)")
	_check(not empty.can_place(neon, &"izq", Vector2(0.0, 6.5)), "el neón choca con el pizarrón")
	_check(not empty.can_place(neon, &"der", Vector2(1.0, 8.96)), "el neón choca con los racks (z 0–2.05)")
	_check(not empty.can_place(neon, &"der", Vector2(4.5, 8.96)), "el neón choca con la ventana (z 1.0–2.5)")

	# Entre objetos del mismo muro también cuenta la altura.
	var with_picture := DecorLayout.new(room, [{"id": "cuadro", "ori": "der", "x": 2.5, "y": 8.95}])
	_check(not with_picture.can_place(picture, &"der", Vector2(3.0, 8.95)), "dos cuadros no se enciman en el mismo muro")
	_check(with_picture.can_place(neon, &"der", Vector2(2.5, 8.96)), "el neón cabe encima del cuadro (alturas distintas)")
	_check(with_picture.can_place(picture, &"izq", Vector2(0.0, 0.0)), "un cuadro en el otro muro no estorba")
	_check(with_picture.can_place(plant, &"a", Vector2(2.5, 8.5)), "un objeto de pared no estorba en el piso")


func _test_shop_availability(game_state: Node, simulation: Node) -> void:
	game_state.call("start_new_game", "Prueba", "TestCorp")
	_check(not _shop.call("is_open"), "etapa 1: la tienda está cerrada")
	_check(_shop.call("get_closed_reason") == "Disponible en Scale-up", "etapa 1: \"Disponible en Scale-up\"")

	simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 1000})
	_check(simulation.get("phase") == PHASE_READY and _shop.call("is_open"), "etapa 2 entre oleadas: la tienda abre")
	simulation.call("start_wave")
	_check(simulation.get("phase") == PHASE_RUNNING and not _shop.call("is_open"), "durante una oleada la tienda está cerrada")
	_check(_shop.call("get_closed_reason") == "Solo entre oleadas", "durante una oleada: \"Solo entre oleadas\"")
	simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 1000})

	var trophy := DecorData.find(&"trofeo")
	_check(trophy.price == 0, "el trofeo es gratis")
	_check(not _shop.call("can_buy", trophy) and _shop.call("get_buy_block_reason", trophy) == "Completa Scale-up", "el trofeo está bloqueado antes de completar Scale-up")
	(simulation.get("stage_stats") as Dictionary)[&"scale_up"] = {"stars": 3}
	_check(_shop.call("can_buy", trophy), "al completar Scale-up se puede reclamar el trofeo")
	_check(_shop.call("buy", trophy), "reclamar el trofeo")
	_check(not _shop.call("can_buy", trophy) and _shop.call("get_buy_block_reason", trophy) == "Reclamado", "el trofeo solo se reclama una vez")
	game_state.call("take_from_inventory", &"trofeo")


## Comprar descuenta, cancelar devuelve; colocar desde la tienda y desde el inventario con DecorPlacer.
func _test_buy_place_cancel(game_state: Node, simulation: Node) -> void:
	simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 1000})
	game_state.set("decor_inventory", [] as Array[StringName])
	(game_state.get("decor_placed") as Dictionary).clear()
	var office := (load("res://scenes/rooms/oficina.tscn") as PackedScene).instantiate()
	root.add_child(office)
	await process_frame
	var placer: Node = office.get_node("%DecorPlacer")
	var shop_panel: CanvasLayer = office.get_node("%ShopPanel")
	var sofa := DecorData.find(&"sillon")

	shop_panel.emit_signal("buy_requested", &"sillon")
	_check(simulation.get("coins") == 400, "comprar el sillón descuenta 600 monedas (%d)" % simulation.get("coins"))
	_check(int(simulation.call("get_checkpoint")["coins"]) == 400, "la compra también corrige el checkpoint")
	_check(game_state.call("count_in_inventory", &"sillon") == 1, "lo comprado queda en el inventario mientras se coloca")
	_check(placer.call("get_mode") == 1, "comprar entra al modo colocación")
	placer.call("cancel_placement")
	_check(simulation.get("coins") == 1000 and int(simulation.call("get_checkpoint")["coins"]) == 1000, "cancelar devuelve las monedas")
	_check(game_state.call("count_in_inventory", &"sillon") == 0, "cancelar una compra la saca del inventario")
	_check(placer.call("get_mode") == 0, "cancelar sale del modo colocación")

	shop_panel.emit_signal("buy_requested", &"sillon")
	placer.call("move_ghost_to", Vector2(1.0, 2.3))
	_check(not placer.call("is_ghost_valid") and not placer.call("confirm_placement"), "no se confirma sobre el escritorio")
	placer.call("move_ghost_to", Vector2(5.0, 5.0))
	_check(placer.call("confirm_placement"), "confirmar en un lugar libre")
	var placed: Array = game_state.call("get_placed_decor", &"oficina")
	_check(placed.size() == 1 and placed[0]["id"] == "sillon" and game_state.call("count_in_inventory", &"sillon") == 0, "el sillón queda colocado y sale del inventario")
	_check(simulation.get("coins") == 400, "colocar no cobra otra vez")
	var node: Node2D = placer.call("get_item_node", 0)
	var center := DecorLayout.new(RoomData.load_room(&"oficina")).get_center(sofa, &"a", DecorLayout.get_position(placed[0]))
	_check(node != null and node.position.is_equal_approx(RoomData.load_room(&"oficina").projection.world_to_canvas(center.x, center.y)), "el nodo va en el centro de la huella")

	simulation.call("adjust_coins", -int(simulation.get("coins")))
	_check(not _shop.call("can_buy", sofa) and _shop.call("get_buy_block_reason", sofa) == "Faltan monedas", "sin monedas no se puede comprar")

	game_state.call("add_to_inventory", &"planta")
	shop_panel.emit_signal("place_requested", &"planta")
	_check(placer.call("get_mode") == 1 and not shop_panel.visible, "colocar desde el inventario")
	placer.call("cancel_placement")
	_check(shop_panel.visible and game_state.call("count_in_inventory", &"planta") == 1, "cancelar desde el inventario regresa al inventario")
	shop_panel.call("close")
	office.free()
	await process_frame


func _test_save_load(game_state: Node, save_system: Node, simulation: Node) -> void:
	game_state.call("start_new_game", "Prueba", "TestCorp")
	simulation.call("load_checkpoint", {"stage": "scale_up", "wave": 1, "coins": 1000})
	game_state.call("place_decor", &"oficina", {"id": "sillon", "ori": "b", "x": 4.0, "y": 4.0})
	game_state.call("place_decor", &"oficina", {"id": "neon", "ori": "der", "x": 2.5, "y": 8.96})
	game_state.call("add_to_inventory", &"planta")
	game_state.call("add_to_inventory", &"planta")
	game_state.call("set_color", &"piso_oficina", &"alfombra_gris")
	_check(save_system.call("save_game"), "guardar con decoración")
	# Se limpia a mano: start_new_game() autoguarda y sobrescribiría la partida.
	game_state.set("decor_inventory", [] as Array[StringName])
	(game_state.get("decor_placed") as Dictionary).clear()
	game_state.call("set_color", &"piso_oficina", &"laminado_claro")
	_check(save_system.call("load_game"), "cargar con decoración")
	var placed: Array = game_state.call("get_placed_decor", &"oficina")
	_check(placed.size() == 2 and placed[0]["id"] == "sillon" and placed[0]["ori"] == "b" and is_equal_approx(float(placed[1]["y"]), 8.96), "guardar → cargar conserva lo colocado (%s)" % [placed])
	_check(game_state.call("count_in_inventory", &"planta") == 2, "guardar → cargar conserva el inventario")
	_check(game_state.get("colors")[&"piso_oficina"] == &"alfombra_gris", "guardar → cargar conserva el piso de la oficina")

	# Una partida anterior a la tienda (sin sección "decor" y con el piso como "piso") se migra.
	var config := ConfigFile.new()
	config.load(save_system.get("save_path"))
	config.erase_section("decor")
	config.erase_section_key("colors", "piso_garage")
	config.erase_section_key("colors", "piso_oficina")
	config.set_value("colors", "piso", "concreto_oscuro")
	config.save(save_system.get("save_path"))
	_check(save_system.call("load_game"), "cargar una partida vieja")
	_check((game_state.call("get_placed_decor", &"oficina") as Array).is_empty() and (game_state.get("decor_inventory") as Array).is_empty(), "una partida vieja empieza sin decoración")
	_check(game_state.get("colors")[&"piso_garage"] == &"concreto_oscuro" and game_state.get("colors")[&"piso_oficina"] == &"laminado_claro", "una partida vieja migra su piso al garage")


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
