class_name RoomData
extends RefCounted
## Datos de un cuarto leídos de data/rooms/<id>.json: lienzo 2x, offsets de sus capas propias,
## sprites reutilizados del garage, paleta de piso, sus racks y, si admite decoración, su proyección.

## Racks de un cuarto que no declara los suyos (el garage y la oficina: uno por servidor, hasta 2).
const DEFAULT_RACK_SLOTS: Array[StringName] = [&"rack_1", &"rack_2"]

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
## x (metros) de la partición de vidrio; lo que está en x mayor se dibuja delante de ella. < 0 = no hay.
var partition_x := -1.0
## Racks del cuarto en orden ("rack_1", "rack_2"...), sacados de reutilizados_del_garage.
var rack_slots: Array[StringName] = []
## rack_id → índice del servidor web (0 = el primero) que muestra ese rack. Viene de fijos.racks;
## sin ese dato, rack_k muestra el servidor k.
var rack_servers: Dictionary[StringName, int] = {}

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


func get_rack_slots() -> Array[StringName]:
	return rack_slots if not rack_slots.is_empty() else DEFAULT_RACK_SLOTS


## Índice del servidor web (0 = el primero) cuyo estado muestra el rack.
func get_rack_server(slot: StringName) -> int:
	if rack_servers.has(slot):
		return rack_servers[slot]
	return get_rack_slots().find(slot)


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
			if slot.begins_with("rack_"):
				rack_slots.append(StringName(slot))
	rack_slots.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a).naturalnocasecmp_to(String(b)) < 0)

	var fixed: Dictionary = data.get("fijos", {})
	if fixed.get("vidrio") is Dictionary:
		partition_x = RoomProjection.parse_vector((fixed["vidrio"] as Dictionary).get("pos_m")).x
	var racks: Dictionary = fixed.get("racks", {}) if fixed.get("racks") is Dictionary else {}
	for rack: Variant in racks.get("lista", []):
		if rack is Dictionary and (rack as Dictionary).has("rack_id"):
			rack_servers[StringName(str(rack["rack_id"]))] = int((rack as Dictionary).get("servidor", 1)) - 1

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
