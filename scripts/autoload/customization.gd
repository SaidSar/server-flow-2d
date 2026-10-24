extends Node
## Autoload "Customization": catálogo de colores del cuarto.
## Lee paleta.json, valida ids guardados y resuelve la textura de cada capa.
## Lee layer_offsets.json: los PNG de las capas están recortados a su contenido y cada uno
## se coloca en su offset dentro del lienzo 2x (ver apply_layer).

## Capas personalizables, en el orden en que aparecen en el panel.
const LAYER_ORDER: Array[StringName] = [&"pared_izq", &"pared_der", &"piso", &"puerta", &"mesa"]

## Capa → grupo de paleta.json (las dos paredes comparten "pared").
const LAYER_GROUPS := {
	&"pared_izq": &"pared",
	&"pared_der": &"pared",
	&"piso": &"piso",
	&"puerta": &"puerta",
	&"mesa": &"mesa",
}

const LAYER_TITLES := {
	&"pared_izq": "Pared izquierda",
	&"pared_der": "Pared derecha",
	&"piso": "Piso",
	&"puerta": "Puerta",
	&"mesa": "Mesa",
}

## Colores de una partida nueva. También se usan si un id guardado ya no existe.
const DEFAULT_COLORS := {
	&"pared_izq": &"blanco_hueso",
	&"pared_der": &"blanco_hueso",
	&"piso": &"concreto_calido",
	&"puerta": &"madera_natural",
	&"mesa": &"roble",
}

## Lienzo 2x sobre el que se renderizaron todas las capas del cuarto.
const DEFAULT_CANVAS_SIZE := Vector2(1592, 1318)

var catalog: CustomizationCatalog
## Tamaño del lienzo 2x, leído de layer_offsets.json.
var canvas_size := DEFAULT_CANVAS_SIZE
## "<carpeta>/<archivo>" (p. ej. "piso/concreto_calido") → posición en el lienzo 2x.
var _layer_offsets: Dictionary[String, Vector2] = {}


func _ready() -> void:
	catalog = CustomizationCatalog.from_palette_json(Paths.PALETTE_JSON)
	_load_layer_offsets(Paths.LAYER_OFFSETS_JSON)


func get_options(layer: StringName) -> Array[CustomizationOption]:
	return catalog.get_group(_group_of(layer))


func find_option(layer: StringName, option_id: StringName) -> CustomizationOption:
	return catalog.find_option(_group_of(layer), option_id)


func is_valid_option(layer: StringName, option_id: StringName) -> bool:
	return find_option(layer, option_id) != null


func get_layer_title(layer: StringName) -> String:
	return str(LAYER_TITLES.get(layer, layer))


func get_default_option(layer: StringName) -> StringName:
	return StringName(str(DEFAULT_COLORS.get(layer, "")))


## Devuelve un color válido para cada capa; los ids desconocidos se cambian por el valor por defecto.
func sanitize_colors(raw_colors: Dictionary) -> Dictionary[StringName, StringName]:
	var result: Dictionary[StringName, StringName] = {}
	for layer: StringName in LAYER_ORDER:
		var option_id := StringName(str(raw_colors.get(layer, "")))
		if not is_valid_option(layer, option_id):
			if option_id != &"":
				push_warning("Color guardado desconocido %s/%s; se usa el valor por defecto." % [layer, option_id])
			option_id = get_default_option(layer)
		result[layer] = option_id
	return result


func get_layer_texture_path(room_id: StringName, layer: StringName, option_id: StringName) -> String:
	return Paths.ROOM_LAYER_TEXTURE % [room_id, layer, option_id]


func load_layer_texture(room_id: StringName, layer: StringName, option_id: StringName) -> Texture2D:
	var path := get_layer_texture_path(room_id, layer, option_id)
	if not ResourceLoader.exists(path):
		push_warning("No existe la textura %s; se usa el valor por defecto." % path)
		path = get_layer_texture_path(room_id, layer, get_default_option(layer))
	return load(path) as Texture2D


## Única forma de asignar la textura de una capa: textura y posición cambian juntas,
## porque cada variante (color o pose) puede tener un offset distinto.
func apply_layer(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.centered = false
	sprite.position = get_layer_offset(texture)


## Posición de una textura en el lienzo 2x. Su clave sale de la ruta: .../<carpeta>/<archivo>.png.
func get_layer_offset(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	var key := get_layer_key(texture.resource_path)
	if _layer_offsets.has(key):
		return _layer_offsets[key]
	# Una capa sin recortar ocupa el lienzo completo y va en el origen.
	if texture.get_size() != canvas_size:
		push_warning("La capa %s está recortada pero no tiene offset en layer_offsets.json." % key)
	return Vector2.ZERO


func get_layer_key(texture_path: String) -> String:
	return "%s/%s" % [texture_path.get_base_dir().get_file(), texture_path.get_file().get_basename()]


func _load_layer_offsets(path: String) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("No se pudo leer %s" % path)
		return
	var data: Dictionary = parsed
	var canvas: Array = data.get("canvas", [])
	if canvas.size() == 2:
		canvas_size = Vector2(float(canvas[0]), float(canvas[1]))
	var layers: Dictionary = data.get("capas", {})
	for key: String in layers:
		var entry: Dictionary = layers[key]
		_layer_offsets[key] = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))


func _group_of(layer: StringName) -> StringName:
	return StringName(str(LAYER_GROUPS.get(layer, "")))
