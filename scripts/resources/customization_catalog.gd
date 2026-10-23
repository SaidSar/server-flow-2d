class_name CustomizationCatalog
extends Resource
## Catálogo de colores del cuarto, agrupado como en paleta.json
## ("pared", "piso", "puerta", "mesa").

@export var walls: Array[CustomizationOption] = []
@export var floors: Array[CustomizationOption] = []
@export var doors: Array[CustomizationOption] = []
@export var desks: Array[CustomizationOption] = []


## Construye el catálogo a partir de paleta.json.
static func from_palette_json(json_path: String) -> CustomizationCatalog:
	var catalog := CustomizationCatalog.new()
	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir la paleta: %s (%s)" % [json_path, error_string(FileAccess.get_open_error())])
		return catalog

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("La paleta no es un objeto JSON válido: %s" % json_path)
		return catalog

	var palette: Dictionary = (parsed as Dictionary).get("paleta", {})
	catalog.walls = _parse_options(palette.get("pared", []))
	catalog.floors = _parse_options(palette.get("piso", []))
	catalog.doors = _parse_options(palette.get("puerta", []))
	catalog.desks = _parse_options(palette.get("mesa", []))
	return catalog


## Opciones de un grupo de la paleta ("pared", "piso", "puerta" o "mesa").
func get_group(group: StringName) -> Array[CustomizationOption]:
	match group:
		&"pared":
			return walls
		&"piso":
			return floors
		&"puerta":
			return doors
		&"mesa":
			return desks
	var empty: Array[CustomizationOption] = []
	return empty


func find_option(group: StringName, option_id: StringName) -> CustomizationOption:
	for option: CustomizationOption in get_group(group):
		if option.id == option_id:
			return option
	return null


static func _parse_options(raw: Variant) -> Array[CustomizationOption]:
	var options: Array[CustomizationOption] = []
	if not raw is Array:
		return options
	for entry: Variant in raw:
		if not entry is Dictionary:
			continue
		var data: Dictionary = entry
		var option := CustomizationOption.new()
		option.id = StringName(str(data.get("id", "")))
		if option.id == &"":
			continue
		option.display_name = str(data.get("nombre", option.id))
		option.color = Color.from_string(str(data.get("color", "")), Color.MAGENTA)
		options.append(option)
	return options
