class_name PetGrid
extends RefCounted
## Cuadrícula por donde caminan las mascotas de un cuarto (casillas de 0.5 m) y búsqueda de rutas A*.
## Las casillas ocupadas son las zonas fijas del cuarto (escritorio, puerta, racks, vidrio, cajas) y la
## decoración de piso colocada; los tapetes y los objetos de pared no estorban.
## Todo en metros del mundo; los puntos devueltos son centros de casilla.

const CELL_M := 0.5

var room: RoomData
var _astar := AStarGrid2D.new()
var _size := Vector2i.ZERO


func _init(room_data: RoomData, placed_decor: Array = []) -> void:
	room = room_data
	rebuild(placed_decor)


## Vuelve a marcar las casillas ocupadas (al colocar, mover o guardar decoración).
func rebuild(placed_decor: Array = []) -> void:
	_size = Vector2i(ceili(room.pet_bounds.size.x / CELL_M - 0.001), ceili(room.pet_bounds.size.y / CELL_M - 0.001))
	_astar.region = Rect2i(Vector2i.ZERO, _size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	var blocked: Array[Rect2] = room.pet_blocked.duplicate()
	blocked.append_array(_decor_footprints(placed_decor))
	for rect: Rect2 in blocked:
		_block_rect(rect)


func get_size() -> Vector2i:
	return _size


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


func is_free(cell: Vector2i) -> bool:
	return is_inside(cell) and not _astar.is_point_solid(cell)


func cell_of(point_m: Vector2) -> Vector2i:
	var local := (point_m - room.pet_bounds.position) / CELL_M
	return Vector2i(clampi(floori(local.x), 0, _size.x - 1), clampi(floori(local.y), 0, _size.y - 1))


func center_of(cell: Vector2i) -> Vector2:
	return room.pet_bounds.position + (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_M


## Ruta de `from_m` a `to_m`: centros de casilla desde la casilla de origen hasta la de destino.
## Vacía si no hay camino.
func find_path(from_m: Vector2, to_m: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var start := cell_of(from_m)
	var goal := cell_of(to_m)
	if not is_free(start) or not is_free(goal):
		return result
	for cell: Vector2i in _astar.get_id_path(start, goal):
		result.append(center_of(cell))
	return result


## La casilla libre más cercana a `cell` (ella misma si está libre); (-1, -1) si no queda ninguna.
func nearest_free_cell(cell: Vector2i) -> Vector2i:
	if is_free(cell):
		return cell
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for x in _size.x:
		for y in _size.y:
			var candidate := Vector2i(x, y)
			if is_free(candidate):
				var distance := Vector2(candidate - cell).length_squared()
				if distance < best_distance:
					best_distance = distance
					best = candidate
	return best


## Casilla libre más cercana a `origin` (a la que se llega caminando) que no esté en `taken`.
## Sirve para que las mascotas no se encimen al aparecer ni en el refugio. Si todas están tomadas, devuelve la más cercana.
func nearest_open_cell(origin: Vector2i, taken: Array[Vector2i]) -> Vector2i:
	var start := nearest_free_cell(origin)
	if start.x < 0:
		return start
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		if not taken.has(cell):
			return cell
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + step
			if not seen.has(next) and is_free(next):
				seen[next] = true
				queue.append(next)
	return start


## Casillas libres a las que se llega caminando desde `cell` (sin contar la de origen).
func get_reachable_cells(cell: Vector2i) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	if not is_free(cell):
		return found
	var seen := {cell: true}
	var queue: Array[Vector2i] = [cell]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next := current + step
			if is_free(next) and not seen.has(next):
				seen[next] = true
				found.append(next)
				queue.append(next)
	return found


## Un punto libre cualquiera al que se llega desde `from_m` (distinto de su casilla). Vector2.INF si no hay.
func pick_random_point(from_m: Vector2, rng: RandomNumberGenerator) -> Vector2:
	var cells := get_reachable_cells(cell_of(from_m))
	if cells.is_empty():
		return Vector2.INF
	return center_of(cells[rng.randi_range(0, cells.size() - 1)])


func _block_rect(rect: Rect2) -> void:
	var local := Rect2(rect.position - room.pet_bounds.position, rect.size)
	var x0 := maxi(floori(local.position.x / CELL_M + 0.001), 0)
	var y0 := maxi(floori(local.position.y / CELL_M + 0.001), 0)
	var x1 := mini(ceili(local.end.x / CELL_M - 0.001), _size.x)
	var y1 := mini(ceili(local.end.y / CELL_M - 0.001), _size.y)
	for x in range(x0, x1):
		for y in range(y0, y1):
			_astar.set_point_solid(Vector2i(x, y), true)


## Huellas en el piso de la decoración de piso colocada (los tapetes y la decoración de pared no bloquean).
func _decor_footprints(placed_decor: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if placed_decor.is_empty() or not room.has_decor():
		return rects
	var layout := DecorLayout.new(room, placed_decor)
	for entry: Variant in placed_decor:
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry
		var decor := DecorData.find(StringName(str(item.get("id", ""))))
		if decor == null or decor.kind != DecorData.KIND_FLOOR:
			continue
		var orientation := StringName(str(item.get("ori", decor.get_default_orientation())))
		if not decor.orientations.has(orientation):
			continue
		rects.append(layout.get_rect(decor, orientation, Vector2(float(item.get("x", 0.0)), float(item.get("y", 0.0)))))
	return rects
