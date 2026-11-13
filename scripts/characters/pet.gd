class_name Pet
extends Node2D
## Una mascota que camina por el piso del cuarto. Busca rutas con PetGrid (A*) esquivando muebles,
## se queda quieta un rato, a veces se echa a dormir y, con saturación, se asusta y corre a su refugio.
## Vive dentro del YSort del cuarto: su nodo está en los pies, así que se ordena con los muebles.
## `step(delta)` hace todo el trabajo (también lo llaman las pruebas sin dibujar).

enum State { IDLE, WALK, SLEEP }
## Emoción temporal (efecto dibujado sobre el cuadro quieto): corazones al acariciarla o tras una buena oleada,
## gota tras una mala. El miedo (_scared) y el sueño (State.SLEEP) tienen sus propios efectos ("!" y "z").
enum Emotion { NONE, HAPPY, SAD }

const WALK_FPS := 8.0
const SCARED_WALK_FPS := 14.0
const SLEEP_SECONDS := Vector2(6.0, 12.0)
const BUBBLE_RADIUS := 17.0
## Altura de la burbuja "!" sobre los pies, en px del lienzo 2x.
const BUBBLE_HEIGHT := 112.0
const BUBBLE_COLOR := Color("#d9364a")
const HEART_COLOR := Color("#ff5d8f")
const DROP_COLOR := Color("#5bb8ff")
const SLEEP_Z_COLOR := Color("#e6f0ff")
const SLEEP_Z_OUTLINE := Color("#2c3a52")
## Salto de alegría: altura (px del lienzo 2x), rapidez y cuánto dura (segundos) al principio de la emoción.
const HOP_HEIGHT := 9.0
const HOP_SPEED := 14.0
const HOP_SECONDS := 0.7

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
var _shelter_m := Vector2.INF
var _sleep_spot_m := Vector2.INF
## Opcional: PetKeeper la usa para repartir un sitio de siesta distinto a cada mascota. Recibe la mascota y devuelve metros.
var sleep_spot_picker: Callable
var _going_to_sleep := false
var _facing := 1
var _anim_time := 0.0
var _sprite: Sprite2D
var _emotion: Emotion = Emotion.NONE
var _emotion_left := 0.0
var _emotion_time := 0.0
var _pet_cooldown := 0.0


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


func get_emotion() -> Emotion:
	return _emotion


## ¿Cae este punto de la pantalla sobre la mascota? (caja generosa para el dedo; la mascota más pequeña también es fácil de tocar).
func contains_screen_point(screen_point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * screen_point
	return Rect2(-56.0, -104.0, 112.0, 120.0).has_point(local)


## Caricia: se pone contenta (corazones y saltito). Si dormía, se despierta; si caminaba, se detiene un momento.
## false si todavía está en pausa de la caricia anterior (no se amontonan los corazones).
func pet_it() -> bool:
	if _pet_cooldown > 0.0:
		return false
	_pet_cooldown = PetData.get_emotion_value("caricia_espera_s")
	if state == State.SLEEP:
		state = State.IDLE
		_wait = 1.0
	elif state == State.WALK and not _scared:
		_path = PackedVector2Array()
		state = State.IDLE
		_wait = 1.2
	_start_emotion(Emotion.HAPPY)
	_refresh_visuals()
	return true


## Reacción por una oleada (contenta o triste). Las que duermen o están asustadas no se enteran.
func feel(emotion: Emotion) -> void:
	if state == State.SLEEP or _scared:
		return
	_start_emotion(emotion)
	_refresh_visuals()


func _start_emotion(emotion: Emotion) -> void:
	_emotion = emotion
	_emotion_time = 0.0
	match emotion:
		Emotion.HAPPY:
			_emotion_left = PetData.get_emotion_value("contenta_s")
		Emotion.SAD:
			_emotion_left = PetData.get_emotion_value("triste_s")
		_:
			_emotion_left = 0.0


## Destino de la ruta actual en metros (Vector2.INF si no camina).
func get_target_m() -> Vector2:
	if state != State.WALK or _path.is_empty():
		return Vector2.INF
	return _path[_path.size() - 1]


## Punto de refugio de la última vez que se asustó (Vector2.INF si nunca).
func get_shelter_m() -> Vector2:
	return _shelter_m


## Sitio de su siesta (Vector2.INF si no duerme ni va a dormir).
func get_sleep_spot_m() -> Vector2:
	if state == State.SLEEP or _going_to_sleep:
		return _sleep_spot_m
	return Vector2.INF


func get_path_points() -> PackedVector2Array:
	return _path.slice(_path_index) if state == State.WALK else PackedVector2Array()


## Con saturación corre a su refugio y se queda ahí; al terminar, vuelve a pasear.
## `shelter_m` es el punto donde se refugia (si no se da, el refugio del cuarto); PetKeeper reparte uno distinto a cada mascota.
func set_scared(scared: bool, shelter_m: Vector2 = Vector2.INF) -> void:
	if _scared == scared:
		return
	_scared = scared
	_going_to_sleep = false
	if scared:
		_shelter_m = shelter_m if shelter_m != Vector2.INF else _room.pet_shelters.get(data.id, _position_m)
		_walk_to(_shelter_m)
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
	_pet_cooldown = maxf(_pet_cooldown - delta, 0.0)
	if _emotion != Emotion.NONE:
		_emotion_time += delta
		_emotion_left -= delta
		if _emotion_left <= 0.0:
			_emotion = Emotion.NONE
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
	var font := ThemeDB.fallback_font
	if _emotion == Emotion.HAPPY:
		_draw_hearts()
	elif _emotion == Emotion.SAD:
		_draw_drop()
	elif _scared:
		var bob := sin(_anim_time * 12.0) * 3.0
		var center := Vector2(26.0 * _facing, -BUBBLE_HEIGHT + bob)
		draw_circle(center, BUBBLE_RADIUS, BUBBLE_COLOR)
		var size := 26
		var text_size := font.get_string_size("!", HORIZONTAL_ALIGNMENT_CENTER, -1, size)
		draw_string(font, center + Vector2(-text_size.x * 0.5, size * 0.36), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
	elif state == State.SLEEP:
		_draw_sleep_z(font)


## Tres corazones que suben y se desvanecen uno tras otro.
func _draw_hearts() -> void:
	var total := PetData.get_emotion_value("contenta_s")
	for i in 3:
		var progress := clampf((_emotion_time - i * 0.28) / maxf(total - 0.84, 0.5), 0.0, 1.0)
		if progress <= 0.0 or progress >= 1.0:
			continue
		var alpha := 1.0 - maxf(progress - 0.6, 0.0) / 0.4
		var center := Vector2((-26.0 + i * 26.0) * _facing, -BUBBLE_HEIGHT + 30.0 - progress * 40.0)
		_draw_heart(center, 15.0 + (i % 2) * 3.0, Color(HEART_COLOR, alpha))


func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	draw_circle(center + Vector2(-size * 0.5, -size * 0.25), size * 0.56, color)
	draw_circle(center + Vector2(size * 0.5, -size * 0.25), size * 0.56, color)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-size * 1.02, -size * 0.02),
		center + Vector2(size * 1.02, -size * 0.02),
		center + Vector2(0.0, size * 1.1),
	]), color)


## Gota de sudor azul que resbala junto a la cabeza.
func _draw_drop() -> void:
	var total := PetData.get_emotion_value("triste_s")
	var progress := clampf(_emotion_time / maxf(total, 0.5), 0.0, 1.0)
	var alpha := 1.0 - maxf(progress - 0.7, 0.0) / 0.3
	var center := Vector2(30.0 * _facing, -BUBBLE_HEIGHT + 24.0 + progress * 24.0)
	var color := Color(DROP_COLOR, alpha)
	draw_circle(center + Vector2(0.0, 7.0), 10.5, color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-9.6, 3.8), center + Vector2(9.6, 3.8), center + Vector2(0.0, -19.0)]), color)


## "z" que suben mientras duerme (tres, desfasadas).
func _draw_sleep_z(font: Font) -> void:
	for i in 3:
		var progress := fmod(_anim_time * 0.45 + i / 3.0, 1.0)
		var size := 28 + int(progress * 16.0)
		var alpha := 1.0 - maxf(progress - 0.65, 0.0) / 0.35
		var origin := Vector2((22.0 + progress * 16.0) * _facing, -62.0 - progress * 42.0)
		draw_string_outline(font, origin, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(SLEEP_Z_OUTLINE, alpha))
		draw_string(font, origin, "z", HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(SLEEP_Z_COLOR, alpha))


func _choose_next() -> void:
	_going_to_sleep = false
	if data.sleep_chance > 0.0 and _room.pet_rest_point != Vector2.ZERO and _rng.randf() < data.sleep_chance:
		_going_to_sleep = true
		_sleep_spot_m = _room.pet_rest_point
		if sleep_spot_picker.is_valid():
			_sleep_spot_m = sleep_spot_picker.call(self)
		_walk_to(_sleep_spot_m)
		if state == State.WALK:
			return
		if _grid.cell_of(_position_m) == _grid.cell_of(_sleep_spot_m):
			_fall_asleep()
			return
		_going_to_sleep = false
		_sleep_spot_m = Vector2.INF
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
	# Saltito de alegría al principio de la emoción contenta.
	var hop := 0.0
	if _emotion == Emotion.HAPPY and _emotion_time < HOP_SECONDS:
		hop = absf(sin(_emotion_time * HOP_SPEED)) * HOP_HEIGHT
	_sprite.position.y = -hop
	# Con flip_h el offset se refleja: se recoloca para que los pies sigan en el mismo punto.
	_sprite.offset.x = -(PetData.get_frame_size().x - PetData.get_anchor().x) if _facing < 0 else -PetData.get_anchor().x
	queue_redraw()


func _apply_frame(frame: int) -> void:
	var size := PetData.get_frame_size()
	_sprite.region_rect = Rect2(frame * size.x, 0, size.x, size.y)
