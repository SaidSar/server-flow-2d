class_name PetKeeper
extends Node
## Cuida a las mascotas del cuarto: crea y quita sus nodos según GameState.pets, mantiene la cuadrícula
## de rutas al día con la decoración y les avisa de la saturación (se asustan).
## Se crea en RoomBase; las mascotas van dentro del YSort para ordenarse con los muebles.

## Una mascota recibió una caricia (para el sonido).
signal pet_petted(pet_id: StringName)

## Último informe de oleada al que ya reaccionaron las mascotas (para no repetir al volver al cuarto).
static var _last_reacted_report: WaveReport

var room_id: StringName
var _room: RoomData
var _grid: PetGrid
var _holder: Node2D
var _pets: Array[Pet] = []


func setup(room_identifier: StringName, room_data: RoomData, holder: Node2D) -> void:
	room_id = room_identifier
	_room = room_data
	_holder = holder
	if not _room.has_pet_area():
		return
	_grid = PetGrid.new(_room, _get_placed())
	GameState.pets_changed.connect(sync)
	GameState.decor_changed.connect(_on_decor_changed)
	Simulation.saturation_changed.connect(_on_saturation_changed)
	sync()
	_react_to_last_wave()


func get_pets() -> Array[Pet]:
	return _pets


func get_grid() -> PetGrid:
	return _grid


## Deja en el cuarto exactamente las mascotas de la partida: crea las que faltan y quita las que sobran.
func sync() -> void:
	if _grid == null:
		return
	var wanted: Array[StringName] = GameState.pets.duplicate()
	var keep: Array[Pet] = []
	for pet: Pet in _pets:
		var index := wanted.find(pet.data.id)
		if index >= 0:
			wanted.remove_at(index)
			keep.append(pet)
		else:
			pet.queue_free()
	_pets = keep
	for pet_id: StringName in wanted:
		var data := PetData.find(pet_id)
		if data != null:
			_spawn(data)
	if Simulation.is_saturated:
		_apply_saturation(true)


func _spawn(data: PetData) -> void:
	var pet := Pet.new()
	pet.name = "Pet_%s_%d" % [data.id, _pets.size()]
	_holder.add_child(pet)
	pet.sleep_spot_picker = _pick_sleep_spot
	pet.setup(data, _room, _grid, _spawn_point())
	_pets.append(pet)


## Casilla libre junto al punto de descanso del cuarto que no esté ya ocupada por otra mascota.
func _spawn_point() -> Vector2:
	var taken: Array[Vector2i] = []
	for pet: Pet in _pets:
		taken.append(_grid.cell_of(pet.get_position_m()))
	var cell := _grid.nearest_open_cell(_grid.cell_of(_room.pet_rest_point), taken)
	return _grid.center_of(cell) if cell.x >= 0 else _room.pet_bounds.position


## Sitio de siesta junto al punto de descanso que no usen ya otras mascotas (dormidas o en camino a dormir).
func _pick_sleep_spot(sleeper: Pet) -> Vector2:
	var taken: Array[Vector2i] = []
	for pet: Pet in _pets:
		if pet != sleeper and pet.get_sleep_spot_m() != Vector2.INF:
			taken.append(_grid.cell_of(pet.get_sleep_spot_m()))
	var cell := _grid.nearest_open_cell(_grid.cell_of(_room.pet_rest_point), taken)
	return _grid.center_of(cell) if cell.x >= 0 else _room.pet_rest_point


func _get_placed() -> Array:
	return GameState.get_placed_decor(room_id) if _room.has_decor() else []


func _on_decor_changed() -> void:
	_grid.rebuild(_get_placed())
	for pet: Pet in _pets:
		pet.on_grid_changed()


func _on_saturation_changed(saturated: bool) -> void:
	_apply_saturation(saturated)


## Con saturación cada mascota corre a su refugio, pero a una casilla distinta (no se encima con las demás).
func _apply_saturation(saturated: bool) -> void:
	if not saturated:
		for pet: Pet in _pets:
			pet.set_scared(false)
		return
	var taken: Array[Vector2i] = []
	for pet: Pet in _pets:
		if pet.is_scared():
			taken.append(_grid.cell_of(pet.get_shelter_m()))
	for pet: Pet in _pets:
		if pet.is_scared():
			continue
		# Sin refugio en el cuarto (la tortuga): se queda donde está, metida en su caparazón.
		if not _room.pet_shelters.has(pet.data.id):
			pet.set_scared(true, pet.get_position_m())
			continue
		var shelter: Vector2 = _room.pet_shelters[pet.data.id]
		var cell := _grid.nearest_open_cell(_grid.cell_of(shelter), taken)
		taken.append(cell)
		pet.set_scared(true, _grid.center_of(cell) if cell.x >= 0 else Vector2.INF)


## Caricia: toca la mascota que esté bajo ese punto de la pantalla (la más cercana a la cámara si hay varias).
## true si había una mascota ahí (aunque esté en su pausa y no reaccione); el cuarto consume el toque.
func try_pet(screen_point: Vector2) -> bool:
	var best: Pet = null
	for pet: Pet in _pets:
		if pet.contains_screen_point(screen_point) and (best == null or pet.position.y > best.position.y):
			best = pet
	if best == null:
		return false
	if best.pet_it():
		pet_petted.emit(best.data.id)
	return true


## Emoción de las mascotas según cómo terminó una oleada: contentas con SLA alto, tristes con SLA bajo o si falló.
## Entre los dos umbrales (sla_triste <= SLA < sla_contenta) no reaccionan. Función pura (la usan las pruebas).
static func mood_for_report(report: WaveReport) -> Pet.Emotion:
	if report == null or report.outcome == WaveReport.Outcome.IN_PROGRESS:
		return Pet.Emotion.NONE
	if report.outcome == WaveReport.Outcome.SLA_ZERO or report.outcome == WaveReport.Outcome.GOAL_MISSED:
		return Pet.Emotion.SAD
	if report.sla_end >= PetData.get_emotion_value("sla_contenta"):
		return Pet.Emotion.HAPPY
	if report.sla_end < PetData.get_emotion_value("sla_triste"):
		return Pet.Emotion.SAD
	return Pet.Emotion.NONE


## Al entrar al cuarto, reaccionan (una sola vez) al informe de la última oleada.
func _react_to_last_wave() -> void:
	var report: WaveReport = Simulation.pending_stage_report if Simulation.pending_stage_report != null else Simulation.report
	if report == null or report == _last_reacted_report:
		return
	var emotion := mood_for_report(report)
	if emotion == Pet.Emotion.NONE:
		return
	_last_reacted_report = report
	for pet: Pet in _pets:
		pet.feel(emotion)
