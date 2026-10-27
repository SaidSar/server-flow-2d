extends Node
## Autoload "Customization": catálogo de colores del cuarto.
## Lee paleta.json, valida ids guardados y resuelve la textura de cada capa.
## Paredes, puerta y mesa comparten ids en todos los cuartos; el piso es propio de cada cuarto
## (capa "piso_<cuarto>", con la paleta_piso de data/rooms/<cuarto>.json).
## Los PNG de las capas están recortados a su contenido y cada uno se coloca en su offset dentro
## del lienzo 2x (ver apply_layer): layer_offsets.json para el garage y los personajes, y
## capas_offsets de cada cuarto para sus capas propias.

## Prefijo de la capa de piso de cada cuarto: "piso_garage", "piso_oficina".
const FLOOR_LAYER_PREFIX := "piso_"
## Carpeta de los PNG del piso dentro de assets/art/rooms/<cuarto>/.
const FLOOR_FOLDER := &"piso"
## Antes de tener un piso por cuarto, el piso del garage se guardaba como "piso".
const LEGACY_FLOOR_LAYER := &"piso"

## Capa → grupo de paleta.json (las dos paredes comparten "pared").
const LAYER_GROUPS := {
	&"pared_izq": &"pared",
	&"pared_der": &"pared",
	&"puerta": &"puerta",
	&"mesa": &"mesa",
}

const LAYER_TITLES := {
	&"pared_izq": "Pared izquierda",
	&"pared_der": "Pared derecha",
	&"puerta": "Puerta",
	&"mesa": "Mesa",
}
const FLOOR_TITLE := "Piso"

## Colores de una partida nueva. También se usan si un id guardado ya no existe.
## El piso de cada cuarto usa la primera opción de su paleta (en el garage, concreto cálido).
const DEFAULT_COLORS := {
	&"pared_izq": &"blanco_hueso",
	&"pared_der": &"blanco_hueso",
	&"piso_garage": &"concreto_calido",
	&"puerta": &"madera_natural",
	&"mesa": &"roble",
}

var catalog: CustomizationCatalog
## "<carpeta>/<archivo>" (p. ej. "piso/concreto_calido") → posición en el lienzo 2x.
var _layer_offsets: Dictionary[String, Vector2] = {}
## "<cuarto>/<carpeta>/<archivo>" (p. ej. "oficina/piso/laminado_claro") → posición en el lienzo 2x.
var _room_layer_offsets: Dictionary[String, Vector2] = {}


func _ready() -> void:
	catalog = CustomizationCatalog.from_palette_json(Paths.PALETTE_JSON)
	_load_layer_offsets(Paths.LAYER_OFFSETS_JSON)
	for room_id: StringName in Paths.ROOM_IDS:
		_room_layer_offsets.merge(RoomData.load_room(room_id).layer_offsets)


## Todas las capas que se guardan: las compartidas y el piso de cada cuarto.
func get_all_layers() -> Array[StringName]:
	var layers: Array[StringName] = [&"pared_izq", &"pared_der"]
	for room_id: StringName in Paths.ROOM_IDS:
		layers.append(get_floor_layer(room_id))
	layers.append_array([&"puerta", &"mesa"])
	return layers


## Capas de un cuarto, en el orden en que aparecen en el panel del pincel.
func get_room_layers(room_id: StringName) -> Array[StringName]:
	return [&"pared_izq", &"pared_der", get_floor_layer(room_id), &"puerta", &"mesa"]


func get_floor_layer(room_id: StringName) -> StringName:
	return StringName(FLOOR_LAYER_PREFIX + room_id)


func is_floor_layer(layer: StringName) -> bool:
	return String(layer).begins_with(FLOOR_LAYER_PREFIX)


func get_options(layer: StringName) -> Array[CustomizationOption]:
	if is_floor_layer(layer):
		var room_options := RoomData.load_room(_floor_room(layer)).floor_options
		return room_options if not room_options.is_empty() else catalog.floors
	return catalog.get_group(_group_of(layer))


func find_option(layer: StringName, option_id: StringName) -> CustomizationOption:
	for option: CustomizationOption in get_options(layer):
		if option.id == option_id:
			return option
	return null


func is_valid_option(layer: StringName, option_id: StringName) -> bool:
	return find_option(layer, option_id) != null


func get_layer_title(layer: StringName) -> String:
	return FLOOR_TITLE if is_floor_layer(layer) else str(LAYER_TITLES.get(layer, layer))


func get_default_option(layer: StringName) -> StringName:
	if DEFAULT_COLORS.has(layer):
		return DEFAULT_COLORS[layer]
	var options := get_options(layer)
	return options[0].id if not options.is_empty() else &""


## Devuelve un color válido para cada capa; los ids desconocidos se cambian por el valor por defecto.
## Las partidas viejas guardaban el piso del garage como "piso".
func sanitize_colors(raw_colors: Dictionary) -> Dictionary[StringName, StringName]:
	var colors := raw_colors.duplicate()
	var garage_floor := get_floor_layer(&"garage")
	if colors.has(LEGACY_FLOOR_LAYER) and not colors.has(garage_floor):
		colors[garage_floor] = colors[LEGACY_FLOOR_LAYER]
	var result: Dictionary[StringName, StringName] = {}
	for layer: StringName in get_all_layers():
		var option_id := StringName(str(colors.get(layer, "")))
		if not is_valid_option(layer, option_id):
			if option_id != &"":
				push_warning("Color guardado desconocido %s/%s; se usa el valor por defecto." % [layer, option_id])
			option_id = get_default_option(layer)
		result[layer] = option_id
	return result


## Ruta del PNG de una capa. El piso siempre es del cuarto al que pertenece.
func get_layer_texture_path(room_id: StringName, layer: StringName, option_id: StringName) -> String:
	if is_floor_layer(layer):
		return Paths.ROOM_LAYER_TEXTURE % [_floor_room(layer), FLOOR_FOLDER, option_id]
	return Paths.ROOM_LAYER_TEXTURE % [room_id, layer, option_id]


func load_layer_texture(room_id: StringName, layer: StringName, option_id: StringName) -> Texture2D:
	var path := get_layer_texture_path(room_id, layer, option_id)
	if not ResourceLoader.exists(path):
		push_warning("No existe la textura %s; se usa el valor por defecto." % path)
		path = get_layer_texture_path(room_id, layer, get_default_option(layer))
	return load(path) as Texture2D


## Única forma de asignar la textura de una capa: textura y posición cambian juntas,
## porque cada variante (color o pose) puede tener un offset distinto.
## `extra_offset` mueve un sprite reutilizado de otro cuarto (p. ej. la mesa del garage en la oficina)
## o lo compensa cuando su nodo padre no está en el origen del lienzo (y-sort).
func apply_layer(sprite: Sprite2D, texture: Texture2D, extra_offset: Vector2 = Vector2.ZERO) -> void:
	sprite.texture = texture
	sprite.centered = false
	sprite.position = get_layer_offset(texture) + extra_offset


## Posición de una textura en el lienzo 2x de su cuarto. La clave sale de la ruta:
## primero .../<cuarto>/<carpeta>/<archivo>.png (capas propias de un cuarto) y si no
## .../<carpeta>/<archivo>.png (garage y personajes).
func get_layer_offset(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var room_key := get_room_layer_key(texture.resource_path)
	if _room_layer_offsets.has(room_key):
		return _room_layer_offsets[room_key]
	var key := get_layer_key(texture.resource_path)
	if _layer_offsets.has(key):
		return _layer_offsets[key]
	push_warning("La capa %s no tiene offset en layer_offsets.json ni en su cuarto." % key)
	return Vector2.ZERO


func get_layer_key(texture_path: String) -> String:
	return "%s/%s" % [texture_path.get_base_dir().get_file(), texture_path.get_file().get_basename()]


func get_room_layer_key(texture_path: String) -> String:
	return "%s/%s" % [texture_path.get_base_dir().get_base_dir().get_file(), get_layer_key(texture_path)]


func _load_layer_offsets(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("No se pudo leer %s" % path)
		return
	var data: Dictionary = parsed
	var layers: Dictionary = data.get("capas", {})
	for key: String in layers:
		var entry: Dictionary = layers[key]
		_layer_offsets[key] = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))


func _floor_room(layer: StringName) -> StringName:
	return StringName(String(layer).trim_prefix(FLOOR_LAYER_PREFIX))


func _group_of(layer: StringName) -> StringName:
	return StringName(str(LAYER_GROUPS.get(layer, "")))
