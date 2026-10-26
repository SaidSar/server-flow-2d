class_name DecorLayout
extends RefCounted
## Reglas de colocación de la decoración en un cuarto (en metros, cuadrícula de 0.5 m).
## - Piso: dentro del cuarto, fuera de las zonas ocupadas y sin encimarse con otros objetos de piso.
## - Tapete: capa inferior; otros objetos pueden ir encima, pero no otro tapete.
## - Pared: pegado a un muro ("der": y = fondo − grosor, se mueve en x; "izq": x = 0, se mueve en y),
##   fuera de los tramos prohibidos y sin encimarse con otros objetos del mismo muro.
## Cada objeto colocado es {id, ori, x, y}: (x, y) es la esquina mínima de su huella.

## Margen para que dos huellas que solo se tocan no cuenten como encimadas.
const EPSILON := 0.001

var room: RoomData
var placed: Array[Dictionary] = []


func _init(room_data: RoomData, placed_items: Array = []) -> void:
	room = room_data
	placed.assign(placed_items)


## Huella del objeto en el piso, en metros.
func get_rect(decor: DecorData, orientation_id: StringName, position: Vector2) -> Rect2:
	var size := decor.orientations[orientation_id].footprint_m
	if not decor.is_wall():
		return Rect2(position, size)
	if orientation_id == RoomProjection.WALL_RIGHT:
		return Rect2(position, size)
	return Rect2(position, Vector2(size.y, size.x))


## Centro de la huella (se usa para el y-sort).
func get_center(decor: DecorData, orientation_id: StringName, position: Vector2) -> Vector2:
	return get_rect(decor, orientation_id, position).get_center()


## Lleva una posición a la cuadrícula, dentro del cuarto y, si es de pared, pegada a su muro.
## `target` es el centro deseado de la huella (en el piso o a lo largo del muro).
func snap_position(decor: DecorData, orientation_id: StringName, target: Vector2) -> Vector2:
	var projection := room.projection
	var size := decor.orientations[orientation_id].footprint_m
	var bounds := projection.bounds
	if decor.is_wall():
		var along := projection.snap(target.x - size.x * 0.5)
		if orientation_id == RoomProjection.WALL_RIGHT:
			return Vector2(clampf(along, bounds.position.x, bounds.end.x - size.x), bounds.end.y - size.y)
		return Vector2(bounds.position.x, clampf(along, bounds.position.y, bounds.end.y - size.x))
	var corner := Vector2(projection.snap(target.x - size.x * 0.5), projection.snap(target.y - size.y * 0.5))
	return Vector2(clampf(corner.x, bounds.position.x, bounds.end.x - size.x), clampf(corner.y, bounds.position.y, bounds.end.y - size.y))


## Coordenada a lo largo del muro (x en el derecho, y en el izquierdo).
func get_wall_span(decor: DecorData, orientation_id: StringName, position: Vector2) -> Vector2:
	var length := decor.orientations[orientation_id].footprint_m.x
	var start := position.x if orientation_id == RoomProjection.WALL_RIGHT else position.y
	return Vector2(start, start + length)


## `ignore_index` es el objeto que se está moviendo o girando (no choca consigo mismo).
func can_place(decor: DecorData, orientation_id: StringName, position: Vector2, ignore_index: int = -1) -> bool:
	if decor == null or not decor.orientations.has(orientation_id) or room.projection == null:
		return false
	if decor.is_wall():
		return _can_place_on_wall(decor, orientation_id, position, ignore_index)
	var rect := get_rect(decor, orientation_id, position)
	var bounds := room.projection.bounds.grow(EPSILON)
	if not bounds.encloses(rect):
		return false
	var inner := rect.grow(-EPSILON)
	if decor.kind == DecorData.KIND_FLOOR:
		for zone: Rect2 in room.projection.occupied:
			if inner.intersects(zone):
				return false
	for i in placed.size():
		if i == ignore_index:
			continue
		var other := DecorData.find(StringName(str(placed[i].get("id", ""))))
		# Piso y tapete viven en capas distintas: solo chocan con los de su mismo tipo.
		if other == null or other.kind != decor.kind:
			continue
		var other_ori := StringName(str(placed[i].get("ori", "")))
		if inner.intersects(get_rect(other, other_ori, get_position(placed[i]))):
			return false
	return true


static func get_position(entry: Dictionary) -> Vector2:
	return Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))


func _can_place_on_wall(decor: DecorData, orientation_id: StringName, position: Vector2, ignore_index: int) -> bool:
	var bounds := room.projection.bounds
	var span := get_wall_span(decor, orientation_id, position)
	var wall_start := bounds.position.x if orientation_id == RoomProjection.WALL_RIGHT else bounds.position.y
	var wall_end := bounds.end.x if orientation_id == RoomProjection.WALL_RIGHT else bounds.end.y
	if span.x < wall_start - EPSILON or span.y > wall_end + EPSILON:
		return false
	for forbidden: Vector2 in room.wall_forbidden.get(orientation_id, []):
		if _spans_overlap(span, forbidden):
			return false
	for i in placed.size():
		if i == ignore_index:
			continue
		var other_ori := StringName(str(placed[i].get("ori", "")))
		var other := DecorData.find(StringName(str(placed[i].get("id", ""))))
		if other == null or not other.is_wall() or other_ori != orientation_id:
			continue
		if _spans_overlap(span, get_wall_span(other, other_ori, get_position(placed[i]))):
			return false
	return true


static func _spans_overlap(a: Vector2, b: Vector2) -> bool:
	return a.x < b.y - EPSILON and b.x < a.y - EPSILON
