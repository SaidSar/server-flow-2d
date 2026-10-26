class_name DecorPlacer
extends Node
## Decoración de un cuarto: dibuja lo colocado, atiende la tienda, el modo colocación (un fantasma
## con su huella en verde si cabe y en rojo si choca) y la selección de objetos colocados.
## Las reglas viven en DecorLayout (dónde cabe) y DecorShop (monedas e inventario).
## Dibujo: cada objeto es un Node2D en world_to_canvas del centro de su huella; su Sprite2D va en
## proj(esquina mínima) − proj(centro) − ancla, así el y-sort usa el centro y el sprite cae en su
## lugar. Piso → YSort (con la mesa y los racks), tapete → Rugs, pared → WallDecor.
## PC: el fantasma sigue al mouse y un clic coloca. Celular: el toque mueve el fantasma y se confirma
## con "Colocar" (para no colocar por accidente).

signal busy_changed(busy: bool)

enum Mode { IDLE, PLACING, SELECTED }
## De dónde viene lo que se coloca: comprado ahora, del inventario o un objeto que se mueve.
enum Source { SHOP, INVENTORY, MOVE }

const GHOST_ALPHA := 0.75
const VALID_COLOR := Color(0.3, 0.9, 0.45, 0.45)
const INVALID_COLOR := Color(0.95, 0.25, 0.25, 0.5)
const SELECTED_COLOR := Color(0.31, 0.76, 0.97, 0.4)
const SELECTED_MODULATE := Color(1.25, 1.25, 1.25)
## Altura de la franja que marca la huella de un objeto de pared.
const WALL_MARK_HEIGHT_M := 2.6
## Letrero de neón: placa centrada a esta altura del muro; el texto ocupa hasta 1.2 m de ancho.
const NEON_ID := &"neon"
const NEON_TEXT_HEIGHT_M := 2.2
const NEON_TEXT_WIDTH_M := 1.2
const NEON_TEXT_MAX_HEIGHT_PX := 40.0
const NEON_COLOR := Color("#ff6fb5")
const NEON_CORE_COLOR := Color("#ffe3f1")
const NEON_FONT_SIZE := 64

var room_id: StringName
var _room_data: RoomData
var _layers: Node2D
var _wall_layer: Node2D
var _rug_layer: Node2D
var _ysort: Node2D
## Huellas y marca de selección: arriba de los tapetes (piso) y de la decoración de pared.
var _floor_marks: Node2D
var _wall_marks: Node2D
var _shop_panel: ShopPanel
var _toolbar: DecorToolbar
var _mode: Mode = Mode.IDLE
var _selection_enabled := true
## Nodo dibujado de cada objeto colocado, en el mismo orden que GameState.get_placed_decor(room_id).
var _nodes: Array[Node2D] = []

var _decor: DecorData
var _orientation: StringName
var _position := Vector2.ZERO
var _source: Source = Source.SHOP
var _move_index := -1
var _ghost: Node2D
var _footprint: Polygon2D
var _touch := false

var _selected := -1
var _selection_mark: Polygon2D


func setup(room: RoomBase) -> void:
	room_id = room.room_id
	_room_data = room.room_data
	_layers = room.get_layers()
	_wall_layer = room.get_node("%WallDecor")
	_rug_layer = room.get_node("%Rugs")
	_ysort = room.get_node("%YSort")
	_floor_marks = _add_marks_layer("FloorMarks", _rug_layer)
	_wall_marks = _add_marks_layer("WallMarks", _wall_layer)
	_shop_panel = room.get_node("%ShopPanel")
	_toolbar = room.get_node("%DecorToolbar")
	_touch = DisplayServer.is_touchscreen_available()

	_shop_panel.buy_requested.connect(_on_buy_requested)
	_shop_panel.place_requested.connect(_on_place_requested)
	_toolbar.rotate_pressed.connect(rotate)
	_toolbar.confirm_pressed.connect(confirm_placement)
	_toolbar.cancel_pressed.connect(cancel_placement)
	_toolbar.move_pressed.connect(_on_move_pressed)
	_toolbar.store_pressed.connect(_on_store_pressed)
	_toolbar.sell_pressed.connect(_on_sell_pressed)
	_toolbar.done_pressed.connect(deselect)
	GameState.decor_changed.connect(_rebuild)
	GameState.changed.connect(_rebuild)
	_rebuild()


func is_busy() -> bool:
	return _mode != Mode.IDLE


func get_mode() -> Mode:
	return _mode


## La selección de objetos colocados solo responde cuando el cuarto no tiene otro panel abierto.
func set_selection_enabled(enabled: bool) -> void:
	_selection_enabled = enabled


func open_shop() -> void:
	if _mode == Mode.IDLE and _room_data.has_decor():
		_shop_panel.open()


func get_item_node(index: int) -> Node2D:
	return _nodes[index] if index >= 0 and index < _nodes.size() else null


func get_ghost() -> Node2D:
	return _ghost


func get_ghost_orientation() -> StringName:
	return _orientation


func get_ghost_position() -> Vector2:
	return _position


func is_ghost_valid() -> bool:
	if _decor == null:
		return false
	return _layout().can_place(_decor, _orientation, _position, _move_index)


#region Colocación

func start_placement(decor: DecorData, source: Source, move_index: int = -1) -> void:
	if _mode == Mode.SELECTED:
		deselect()
	_decor = decor
	_source = source
	_move_index = move_index if source == Source.MOVE else -1
	if source == Source.MOVE:
		var entry: Dictionary = GameState.get_placed_decor(room_id)[move_index]
		_orientation = StringName(str(entry.get("ori", "")))
		_position = DecorLayout.get_position(entry)
	else:
		_orientation = decor.get_default_orientation()
		_position = _find_start_position()
	_footprint = Polygon2D.new()
	(_wall_marks if decor.is_wall() else _floor_marks).add_child(_footprint)
	_ghost = _create_item(decor, _orientation, _position)
	_ghost.modulate.a = GHOST_ALPHA
	_set_mode(Mode.PLACING)
	_rebuild()
	_toolbar.show_placement(decor.display_name, _touch)
	_update_ghost()


## Mueve el fantasma para que el centro de su huella quede cerca de `target` (metros; en pared,
## target.x es la coordenada a lo largo del muro).
func move_ghost_to(target: Vector2) -> void:
	if _mode != Mode.PLACING:
		return
	_position = _layout().snap_position(_decor, _orientation, target)
	_update_ghost()


func rotate() -> void:
	if _mode == Mode.PLACING:
		var target := _rotation_target(_decor, _orientation, _position)
		_orientation = _decor.get_rotated(_orientation)
		_position = _layout().snap_position(_decor, _orientation, target)
		_update_ghost()
	elif _mode == Mode.SELECTED:
		var rotated := _rotated_entry(_selected)
		if not rotated.is_empty():
			var index := _selected
			deselect()
			GameState.update_placed_decor(room_id, index, rotated)
			SaveSystem.save_game()
			select(index)


func confirm_placement() -> bool:
	if _mode != Mode.PLACING or not is_ghost_valid():
		return false
	var entry := {"id": String(_decor.id), "ori": String(_orientation), "x": _position.x, "y": _position.y}
	var source := _source
	var move_index := _move_index
	_end_placement()
	if source == Source.MOVE:
		GameState.update_placed_decor(room_id, move_index, entry)
	else:
		GameState.take_from_inventory(StringName(entry["id"]))
		GameState.place_decor(room_id, entry)
	SaveSystem.save_game()
	return true


## Cancelar: lo recién comprado se devuelve (monedas completas); lo del inventario regresa al
## inventario; lo que se movía vuelve a su lugar.
func cancel_placement() -> void:
	if _mode != Mode.PLACING:
		return
	var decor := _decor
	var source := _source
	_end_placement()
	match source:
		Source.SHOP:
			DecorShop.refund(decor)
			SaveSystem.save_game()
		Source.INVENTORY:
			_shop_panel.open(ShopPanel.Tab.INVENTORY)


func _end_placement() -> void:
	_ghost.queue_free()
	_footprint.queue_free()
	_ghost = null
	_footprint = null
	_decor = null
	_move_index = -1
	_set_mode(Mode.IDLE)
	_toolbar.hide()
	_rebuild()


func _update_ghost() -> void:
	_layout_item(_ghost, _decor, _orientation, _position)
	var valid := is_ghost_valid()
	_footprint.polygon = _footprint_polygon(_decor, _orientation, _position)
	_footprint.color = VALID_COLOR if valid else INVALID_COLOR
	_toolbar.set_valid(valid)


## Primer lugar libre, empezando por el centro del cuarto (o por el muro derecho).
func _find_start_position() -> Vector2:
	var layout := _layout()
	var bounds := _room_data.projection.bounds
	var center := bounds.get_center()
	var first := layout.snap_position(_decor, _orientation, center)
	if layout.can_place(_decor, _orientation, first):
		return first
	var step := _room_data.projection.cell_m
	var candidates: Array[Vector2] = []
	var y := bounds.position.y
	while y < bounds.end.y:
		var x := bounds.position.x
		while x < bounds.end.x:
			candidates.append(Vector2(x, y))
			x += step
		y += step
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(center) < b.distance_squared_to(center))
	for candidate: Vector2 in candidates:
		var position := layout.snap_position(_decor, _orientation, candidate)
		if layout.can_place(_decor, _orientation, position):
			return position
	return first


## Centro de la huella (piso) o centro a lo largo del muro (pared), para conservarlo al girar.
func _rotation_target(decor: DecorData, orientation_id: StringName, position: Vector2) -> Vector2:
	if not decor.is_wall():
		return _layout().get_center(decor, orientation_id, position)
	var span := _layout().get_wall_span(decor, orientation_id, position)
	return Vector2((span.x + span.y) * 0.5, 0.0)


## El objeto colocado girado, si cabe; {} si no.
func _rotated_entry(index: int) -> Dictionary:
	var entry: Dictionary = GameState.get_placed_decor(room_id)[index]
	var decor := DecorData.find(StringName(str(entry.get("id", ""))))
	var orientation := StringName(str(entry.get("ori", "")))
	var layout := _layout()
	var target := _rotation_target(decor, orientation, DecorLayout.get_position(entry))
	var rotated := decor.get_rotated(orientation)
	var position := layout.snap_position(decor, rotated, target)
	if not layout.can_place(decor, rotated, position, index):
		return {}
	return {"id": String(decor.id), "ori": String(rotated), "x": position.x, "y": position.y}

#endregion


#region Selección

func select(index: int) -> void:
	var node := get_item_node(index)
	if node == null:
		return
	if _mode == Mode.SELECTED:
		deselect()
	_selected = index
	var entry: Dictionary = GameState.get_placed_decor(room_id)[index]
	var decor := DecorData.find(StringName(str(entry.get("id", ""))))
	var orientation := StringName(str(entry.get("ori", "")))
	node.modulate = SELECTED_MODULATE
	_selection_mark = Polygon2D.new()
	_selection_mark.color = SELECTED_COLOR
	_selection_mark.polygon = _footprint_polygon(decor, orientation, DecorLayout.get_position(entry))
	(_wall_marks if decor.is_wall() else _floor_marks).add_child(_selection_mark)
	_set_mode(Mode.SELECTED)
	_toolbar.show_selection(decor.display_name, not _rotated_entry(index).is_empty(), -1 if decor.is_trophy() else decor.get_sell_price())


func deselect() -> void:
	if _mode != Mode.SELECTED:
		return
	var node := get_item_node(_selected)
	if node != null:
		node.modulate = Color.WHITE
	_selection_mark.queue_free()
	_selection_mark = null
	_selected = -1
	_set_mode(Mode.IDLE)
	_toolbar.hide()


func get_selected_index() -> int:
	return _selected


func _on_move_pressed() -> void:
	var index := _selected
	var entry: Dictionary = GameState.get_placed_decor(room_id)[index]
	deselect()
	start_placement(DecorData.find(StringName(str(entry.get("id", "")))), Source.MOVE, index)


func _on_store_pressed() -> void:
	var index := _selected
	deselect()
	DecorShop.store_placed(room_id, index)
	SaveSystem.save_game()


func _on_sell_pressed() -> void:
	var index := _selected
	deselect()
	if DecorShop.sell_placed(room_id, index):
		SaveSystem.save_game()

#endregion


#region Tienda

func _on_buy_requested(decor_id: StringName) -> void:
	var decor := DecorData.find(decor_id)
	if decor != null and DecorShop.buy(decor):
		SaveSystem.save_game()
		_shop_panel.close()
		start_placement(decor, Source.SHOP)


func _on_place_requested(decor_id: StringName) -> void:
	var decor := DecorData.find(decor_id)
	if decor != null and GameState.count_in_inventory(decor_id) > 0:
		_shop_panel.close()
		start_placement(decor, Source.INVENTORY)

#endregion


#region Entrada

func _unhandled_input(event: InputEvent) -> void:
	match _mode:
		Mode.PLACING:
			_handle_placing_input(event)
		Mode.SELECTED:
			_handle_selected_input(event)
		Mode.IDLE:
			if _selection_enabled and DecorShop.is_open() and _is_left_press(event):
				var index := _pick((event as InputEventMouseButton).position)
				if index >= 0:
					select(index)
					get_viewport().set_input_as_handled()


func _handle_placing_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_R:
		rotate()
	elif event.is_action_pressed(&"ui_cancel"):
		cancel_placement()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		# En el celular solo se arrastra con el dedo puesto; en PC el fantasma sigue al mouse.
		if not _is_touch(motion) or (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_move_ghost_to_screen(motion.position)
	elif _is_left_press(event):
		var click := event as InputEventMouseButton
		_move_ghost_to_screen(click.position)
		if _is_touch(click):
			_set_touch(true)
		else:
			confirm_placement()
	else:
		return
	get_viewport().set_input_as_handled()


func _handle_selected_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		deselect()
	elif _is_left_press(event):
		var index := _pick((event as InputEventMouseButton).position)
		if index >= 0:
			select(index)
		else:
			deselect()
	else:
		return
	get_viewport().set_input_as_handled()


func _is_left_press(event: InputEvent) -> bool:
	var click := event as InputEventMouseButton
	return click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT


## Los toques llegan como mouse emulado (InputEvent.DEVICE_ID_EMULATION).
func _is_touch(event: InputEvent) -> bool:
	return event.device == InputEvent.DEVICE_ID_EMULATION


func _set_touch(touch: bool) -> void:
	if touch != _touch:
		_touch = touch
		if _mode == Mode.PLACING:
			_toolbar.show_placement(_decor.display_name, _touch)
			_update_ghost()


func _move_ghost_to_screen(screen_position: Vector2) -> void:
	var local := _layers.get_global_transform_with_canvas().affine_inverse() * screen_position
	var projection := _room_data.projection
	if not _decor.is_wall():
		move_ghost_to(projection.canvas_to_world(local))
		return
	var wall_coord := _position.y if _orientation == RoomProjection.WALL_RIGHT else _position.x
	move_ghost_to(Vector2(projection.canvas_to_wall(local, _orientation, wall_coord).x, 0.0))


## Objeto colocado bajo un punto de la pantalla (el de más adelante primero); -1 si no hay.
func _pick(screen_position: Vector2) -> int:
	var order: Array[int] = []
	for i in _nodes.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return _pick_priority(a) > _pick_priority(b))
	for i: int in order:
		var sprite := _nodes[i].get_child(0) as Sprite2D
		var local := sprite.get_global_transform_with_canvas().affine_inverse() * screen_position
		if sprite.is_pixel_opaque(local):
			return i
	return -1


## Se dibujan después (y se tocan primero) los de piso más cercanos a la cámara, luego los de
## pared y al final los tapetes.
func _pick_priority(index: int) -> float:
	var node := _nodes[index]
	if node.get_parent() == _ysort:
		return 100000.0 + node.position.y
	return 50000.0 + node.position.y if node.get_parent() == _wall_layer else node.position.y

#endregion


#region Dibujo

func _rebuild() -> void:
	for node: Node2D in _nodes:
		node.queue_free()
	_nodes.clear()
	if _room_data == null or not _room_data.has_decor():
		return
	for entry: Dictionary in GameState.get_placed_decor(room_id):
		var decor := DecorData.find(StringName(str(entry.get("id", ""))))
		var orientation := StringName(str(entry.get("ori", "")))
		var node := _create_item(decor, orientation, DecorLayout.get_position(entry))
		node.visible = not (_mode == Mode.PLACING and _source == Source.MOVE and _nodes.size() == _move_index)
		_nodes.append(node)
	if _mode == Mode.SELECTED and get_item_node(_selected) != null:
		get_item_node(_selected).modulate = SELECTED_MODULATE


func _create_item(decor: DecorData, orientation_id: StringName, position: Vector2) -> Node2D:
	var item := Node2D.new()
	item.name = "Decor_%s" % decor.id
	var sprite := Sprite2D.new()
	sprite.centered = false
	item.add_child(sprite)
	var container := _ysort
	if decor.is_wall():
		container = _wall_layer
	elif decor.kind == DecorData.KIND_RUG:
		container = _rug_layer
	container.add_child(item)
	_layout_item(item, decor, orientation_id, position)
	return item


func _layout_item(item: Node2D, decor: DecorData, orientation_id: StringName, position: Vector2) -> void:
	var projection := _room_data.projection
	var orientation := decor.orientations[orientation_id]
	var center := _layout().get_center(decor, orientation_id, position)
	item.position = projection.world_to_canvas(center.x, center.y)
	var sprite := item.get_child(0) as Sprite2D
	sprite.texture = orientation.load_texture()
	sprite.position = projection.world_to_canvas(position.x, position.y) - item.position - orientation.anchor
	if decor.id == NEON_ID:
		_layout_neon_text(item, orientation_id, position, orientation.footprint_m.x)


## Nombre de la empresa sobre la placa del neón, en el plano del muro: eje x a lo largo del muro y
## eje y hacia abajo de la pantalla. Se escala para caber en 1.2 m.
func _layout_neon_text(item: Node2D, orientation_id: StringName, position: Vector2, length_m: float) -> void:
	var text_node := item.get_node_or_null("NeonText") as Node2D
	var label: Label
	if text_node == null:
		text_node = Node2D.new()
		text_node.name = "NeonText"
		item.add_child(text_node)
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override(&"font_size", NEON_FONT_SIZE)
		label.add_theme_color_override(&"font_color", NEON_CORE_COLOR)
		label.add_theme_color_override(&"font_outline_color", NEON_COLOR)
		label.add_theme_constant_override(&"outline_size", 10)
		label.add_theme_color_override(&"font_shadow_color", Color(NEON_COLOR, 0.8))
		label.add_theme_constant_override(&"shadow_outline_size", 28)
		label.add_theme_constant_override(&"shadow_offset_x", 0)
		label.add_theme_constant_override(&"shadow_offset_y", 0)
		text_node.add_child(label)
	else:
		label = text_node.get_child(0) as Label
	label.text = GameState.company_name if not GameState.company_name.is_empty() else Hud.DEFAULT_COMPANY_NAME
	var size := label.get_minimum_size()
	label.size = size
	label.position = -size * 0.5

	var projection := _room_data.projection
	var axis := projection.ex if orientation_id == RoomProjection.WALL_RIGHT else projection.ey
	var plate_center := projection.world_to_canvas(position.x, position.y, NEON_TEXT_HEIGHT_M) + axis * length_m * 0.5
	var scale := minf(NEON_TEXT_WIDTH_M * axis.length() / maxf(size.x, 1.0), NEON_TEXT_MAX_HEIGHT_PX / maxf(size.y, 1.0))
	text_node.transform = Transform2D(axis.normalized() * scale, Vector2(0.0, scale), plate_center - item.position)


func _footprint_polygon(decor: DecorData, orientation_id: StringName, position: Vector2) -> PackedVector2Array:
	var projection := _room_data.projection
	if not decor.is_wall():
		var rect := _layout().get_rect(decor, orientation_id, position)
		return PackedVector2Array([
			projection.world_to_canvas(rect.position.x, rect.position.y),
			projection.world_to_canvas(rect.end.x, rect.position.y),
			projection.world_to_canvas(rect.end.x, rect.end.y),
			projection.world_to_canvas(rect.position.x, rect.end.y),
		])
	var span := _layout().get_wall_span(decor, orientation_id, position)
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2(span.x, 0.0), Vector2(span.y, 0.0), Vector2(span.y, WALL_MARK_HEIGHT_M), Vector2(span.x, WALL_MARK_HEIGHT_M)]:
		if orientation_id == RoomProjection.WALL_RIGHT:
			points.append(projection.world_to_canvas(corner.x, position.y, corner.y))
		else:
			points.append(projection.world_to_canvas(position.x, corner.x, corner.y))
	return points

#endregion


## Capa vacía justo encima de `below` en Layers.
func _add_marks_layer(layer_name: String, below: Node2D) -> Node2D:
	var marks := Node2D.new()
	marks.name = layer_name
	_layers.add_child(marks)
	_layers.move_child(marks, below.get_index() + 1)
	return marks


func _layout() -> DecorLayout:
	return DecorLayout.new(_room_data, GameState.get_placed_decor(room_id))


func _set_mode(mode: Mode) -> void:
	var was_busy := is_busy()
	_mode = mode
	if is_busy() != was_busy:
		busy_changed.emit(is_busy())
