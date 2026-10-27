class_name RoomData
extends RefCounted
## Datos de un cuarto leídos de data/rooms/<id>.json: lienzo 2x, offsets de sus capas propias,
## sprites reutilizados del garage, paleta de piso y, si admite decoración, su proyección.

var id: StringName
var canvas_size := Vector2.ZERO
## null si el cuarto no admite decoración (el garage).
var projection: RoomProjection
## Opciones de piso propias. Vacío = se usa el grupo "piso" de paleta.json.
var floor_options: Array[CustomizationOption] = []
## "<cuarto>/<capa>/<id>" → posición en el lienzo 2x.
var layer_offsets: Dictionary[String, Vector2] = {}
## Hueco que reutiliza un sprite del garage ("puerta", "mesa", "rack_1", "alex"...) → (dx, dy)
## que se suma a su offset del garage.
var reuse_offsets: Dictionary[StringName, Vector2] = {}
## Centro de la huella (metros) para el y-sort de la mesa y los racks.
var ysort_points: Dictionary[StringName, Vector2] = {}
## Muro ("der"/"izq") → zonas prohibidas en el plano del muro: Rect2 con x = a lo largo del muro
## y y = altura z (metros). Un objeto de pared choca solo si se encima en las dos.
var wall_forbidden: Dictionary[StringName, Array] = {}

static var _cache: Dictionary[StringName, RoomData] = {}


static func load_room(room_id: StringName) -> RoomData:
	if _cache.has(room_id):
		return _cache[room_id]
	var room := RoomData.new()
	room.id = room_id
	var path := Paths.ROOM_DATA % room_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		room._parse(parsed)
	else:
		push_error("No se pudo leer %s" % path)
	_cache[room_id] = room
	return room


func has_decor() -> bool:
	return projection != null


## true si el cuarto usa el sprite del garage en ese hueco.
func reuses(slot: StringName) -> bool:
	return reuse_offsets.has(slot)


func get_reuse_offset(slot: StringName) -> Vector2:
	return reuse_offsets.get(slot, Vector2.ZERO)


## Posición en el lienzo del centro de la huella de la mesa o de un rack (para el y-sort).
func get_ysort_position(slot: StringName) -> Vector2:
	if projection == null or not ysort_points.has(slot):
		return Vector2.ZERO
	var point := ysort_points[slot]
	return projection.world_to_canvas(point.x, point.y)


func _parse(data: Dictionary) -> void:
	canvas_size = RoomProjection.parse_vector(data.get("canvas"))
	if data.get("proyeccion") is Dictionary:
		projection = RoomProjection.from_dict(data["proyeccion"], data.get("cuadricula", {}))
	floor_options = CustomizationCatalog.parse_options(data.get("paleta_piso", []))

	var layers: Dictionary = data.get("capas_offsets", {})
	for key: String in layers:
		var entry: Dictionary = layers[key]
		layer_offsets[key] = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))

	# Claves como "mesa/*", "alexa/*" o "rack_1 (fijos/rack_ok|rack_saturado)".
	var reused: Dictionary = data.get("reutilizados_del_garage", {})
	for key: String in reused:
		if reused[key] is Array:
			var slot := key.get_slice(" ", 0).trim_suffix("/*")
			reuse_offsets[StringName(slot)] = RoomProjection.parse_vector(reused[key])

	var ysort: Dictionary = data.get("ysort_m", {})
	for key: String in ysort:
		if ysort[key] is Array:
			ysort_points[StringName(key)] = RoomProjection.parse_vector(ysort[key])

	var forbidden: Dictionary = data.get("tramos_prohibidos_pared", {})
	for wall: String in forbidden:
		if forbidden[wall] is Array:
			var zones: Array[Rect2] = []
			for zone: Variant in forbidden[wall]:
				if zone is Dictionary:
					var span := RoomProjection.parse_vector((zone as Dictionary).get("tramo"))
					var height := RoomProjection.parse_vector((zone as Dictionary).get("z"))
					zones.append(Rect2(span.x, height.x, span.y - span.x, height.y - height.x))
			wall_forbidden[StringName(wall)] = zones
