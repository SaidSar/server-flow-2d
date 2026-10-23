extends Node
## Autoload "Customization": catálogo de colores del cuarto.
## Lee paleta.json, valida ids guardados y resuelve la textura de cada capa.

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

var catalog: CustomizationCatalog


func _ready() -> void:
	catalog = CustomizationCatalog.from_palette_json(Paths.PALETTE_JSON)


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


func _group_of(layer: StringName) -> StringName:
	return StringName(str(LAYER_GROUPS.get(layer, "")))
