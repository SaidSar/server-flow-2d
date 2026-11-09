class_name PetKeeper
extends Node
## Cuida a las mascotas del cuarto: crea y quita sus nodos según GameState.pets, mantiene la cuadrícula
## de rutas al día con la decoración y les avisa de la saturación (se asustan).
## Se crea en RoomBase; las mascotas van dentro del YSort para ordenarse con los muebles.

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
	pet.setup(data, _room, _grid, _spawn_point())
	_pets.append(pet)


## Casilla libre junto al punto de descanso del cuarto que no esté ya ocupada por otra mascota.
func _spawn_point() -> Vector2:
	var taken: Array[Vector2i] = []
	for pet: Pet in _pets:
		taken.append(_grid.cell_of(pet.get_position_m()))
	var cell := _grid.nearest_open_cell(_grid.cell_of(_room.pet_rest_point), taken)
	return _grid.center_of(cell) if cell.x >= 0 else _room.pet_bounds.position


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
		var shelter: Vector2 = _room.pet_shelters.get(pet.data.id, _room.pet_rest_point)
		var cell := _grid.nearest_open_cell(_grid.cell_of(shelter), taken)
		taken.append(cell)
		pet.set_scared(true, _grid.center_of(cell) if cell.x >= 0 else Vector2.INF)
