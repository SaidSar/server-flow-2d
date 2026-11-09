class_name Pet
extends Node2D
## Una mascota que camina por el piso del cuarto. Busca rutas con PetGrid (A*) esquivando muebles,
## se queda quieta un rato, a veces se echa a dormir y, con saturación, se asusta y corre a su refugio.
## Vive dentro del YSort del cuarto: su nodo está en los pies, así que se ordena con los muebles.
## `step(delta)` hace todo el trabajo (también lo llaman las pruebas sin dibujar).

enum State { IDLE, WALK, SLEEP }

const WALK_FPS := 8.0
const SCARED_WALK_FPS := 14.0
const SLEEP_SECONDS := Vector2(6.0, 12.0)
const BUBBLE_RADIUS := 17.0
## Altura de la burbuja "!" sobre los pies, en px del lienzo 2x.
const BUBBLE_HEIGHT := 112.0
const BUBBLE_COLOR := Color("#d9364a")

var data: PetData
var state: State = State.IDLE

var _room: RoomData
var _grid: PetGrid
var _projection: RoomProjection
var _rng := RandomNumberGenerator.new()
var _position_m := Vector2.ZERO
var _path := PackedVector2Array()
var _path_index := 0
var _wait := 1.0
var _scared := false
var _going_to_sleep := false
var _facing := 1
var _anim_time := 0.0
var _sprite: Sprite2D


func setup(pet_data: PetData, room_data: RoomData, grid: PetGrid, start_m: Vector2, seed_value: int = 0) -> void:
	data = pet_data
	_room = room_data
	_grid = grid
	_projection = room_data.surfaces
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	_wait = _random_idle()
	_sprite = Sprite2D.new()
	_sprite.name = "Body"
	_sprite.centered = false
	_sprite.texture = data.load_sheet()
	_sprite.region_enabled = true
	_sprite.offset = -PetData.get_anchor()
	add_child(_sprite)
	_set_position_m(start_m)
	_apply_frame(PetData.FRAME_IDLE)


## Posición en metros del mundo (los pies).
func get_position_m() -> Vector2:
	return _position_m


func is_scared() -> bool:
	return _scared


func is_sleeping() -> bool:
	return state == State.SLEEP


## Destino de la ruta actual en metros (Vector2.INF si no camina).
func get_target_m() -> Vector2:
	if state != State.WALK or _path.is_empty():
		return Vector2.INF
	return _path[_path.size() - 1]


func get_path_points() -> PackedVector2Array:
	return _path.slice(_path_index) if state == State.WALK else PackedVector2Array()


## Con saturación corre a su refugio y se queda ahí; al terminar, vuelve a pasear.
func set_scared(scared: bool) -> void:
	if _scared == scared:
		return
	_scared = scared
	_going_to_sleep = false
	if scared:
		var shelter: Vector2 = _room.pet_shelters.get(data.id, _position_m)
		_walk_to(shelter)
		if state != State.WALK:
			state = State.IDLE
			_wait = INF
	else:
		state = State.IDLE
		_path = PackedVector2Array()
		_wait = _rng.randf_range(0.6, 1.6)
	_refresh_visuals()


## Avisa que cambiaron las casillas ocupadas: si quedó sobre una, se aparta; si camina, recalcula la ruta.
func on_grid_changed() -> void:
	var cell := _grid.cell_of(_position_m)
	if not _grid.is_free(cell):
		var free := _grid.nearest_free_cell(cell)
		if free.x >= 0:
			_set_position_m(_grid.center_of(free))
		_path = PackedVector2Array()
		state = State.IDLE
		_wait = 0.5
		return
	if state == State.WALK and not _path.is_empty():
		var target := _path[_path.size() - 1]
		_walk_to(target)
		if state != State.WALK:
			_wait = 0.5


func step(delta: float) -> void:
	_anim_time += delta
	match state:
		State.IDLE:
			_wait -= delta
			if _wait <= 0.0 and not _scared:
				_choose_next()
		State.SLEEP:
			_wait -= delta
			if _wait <= 0.0:
				state = State.IDLE
				_wait = _random_idle()
		State.WALK:
			_advance(delta)
	_refresh_visuals()


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void:
	if not _scared:
		return
	var bob := sin(_anim_time * 12.0) * 3.0
	var center := Vector2(26.0 * _facing, -BUBBLE_HEIGHT + bob)
	draw_circle(center, BUBBLE_RADIUS, BUBBLE_COLOR)
	var font := ThemeDB.fallback_font
	var size := 26
	var text_size := font.get_string_size("!", HORIZONTAL_ALIGNMENT_CENTER, -1, size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, size * 0.36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)


func _choose_next() -> void:
	_going_to_sleep = false
	if data.sleep_chance > 0.0 and _room.pet_rest_point != Vector2.ZERO and _rng.randf() < data.sleep_chance:
		_going_to_sleep = true
		_walk_to(_room.pet_rest_point)
		if state == State.WALK:
			return
		if _grid.cell_of(_position_m) == _grid.cell_of(_room.pet_rest_point):
			_fall_asleep()
			return
		_going_to_sleep = false
	var target := _grid.pick_random_point(_position_m, _rng)
	if target == Vector2.INF:
		_wait = _random_idle()
		return
	_walk_to(target)
	if state != State.WALK:
		_wait = _random_idle()


func _walk_to(target_m: Vector2) -> void:
	var path := _grid.find_path(_position_m, target_m)
	if path.size() < 2:
		_path = PackedVector2Array()
		state = State.IDLE
		return
	_path = path
	_path_index = 1
	state = State.WALK


func _advance(delta: float) -> void:
	if _path_index >= _path.size():
		_arrive()
		return
	var speed := data.scared_speed_m_s if _scared else data.walk_speed_m_s
	var budget := speed * delta
	while budget > 0.0 and _path_index < _path.size():
		var target := _path[_path_index]
		var to_target := target - _position_m
		var distance := to_target.length()
		if to_target.x + to_target.y != 0.0:
			# En pantalla, avanzar en +x o +y va a la derecha; -x o -y, a la izquierda.
			_facing = 1 if to_target.x + to_target.y > 0.0 else -1
		if distance <= budget:
			_set_position_m(target)
			budget -= distance
			_path_index += 1
		else:
			_set_position_m(_position_m + to_target / distance * budget)
			budget = 0.0
	if _path_index >= _path.size():
		_arrive()


func _arrive() -> void:
	_path = PackedVector2Array()
	if _scared:
		state = State.IDLE
		_wait = INF
	elif _going_to_sleep:
		_fall_asleep()
	else:
		state = State.IDLE
		_wait = _random_idle()


func _fall_asleep() -> void:
	_going_to_sleep = false
	state = State.SLEEP
	_wait = _rng.randf_range(SLEEP_SECONDS.x, SLEEP_SECONDS.y)


func _random_idle() -> float:
	return _rng.randf_range(data.idle_range_s.x, data.idle_range_s.y)


func _set_position_m(point: Vector2) -> void:
	_position_m = point
	position = _projection.world_to_canvas(point.x, point.y)


func _refresh_visuals() -> void:
	var frame := PetData.FRAME_IDLE
	match state:
		State.SLEEP:
			frame = PetData.FRAME_SLEEP
		State.WALK:
			var fps := SCARED_WALK_FPS if _scared else WALK_FPS
			frame = PetData.FRAME_WALK_FIRST + int(_anim_time * fps) % PetData.FRAME_WALK_COUNT
		_:
			frame = PetData.FRAME_SCARED if _scared else PetData.FRAME_IDLE
	_apply_frame(frame)
	_sprite.flip_h = _facing < 0
	# Con flip_h el offset se refleja: se recoloca para que los pies sigan en el mismo punto.
	_sprite.offset.x = -(PetData.get_frame_size().x - PetData.get_anchor().x) if _facing < 0 else -PetData.get_anchor().x
	queue_redraw()


func _apply_frame(frame: int) -> void:
	var size := PetData.get_frame_size()
	_sprite.region_rect = Rect2(frame * size.x, 0, size.x, size.y)
