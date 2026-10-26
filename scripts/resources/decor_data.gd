class_name DecorData
extends Resource
## Objeto de decoración de la tienda (solo estético). Se genera desde data/decor/catalogo.json.

## Tipos: "piso" (no se enciman), "tapete" (capa inferior, otros objetos van encima) y "pared".
const KIND_FLOOR := &"piso"
const KIND_RUG := &"tapete"
const KIND_WALL := &"pared"
## El trofeo es gratis, se reclama una vez al completar Scale-up y no se vende.
const TROPHY_ID := &"trofeo"

@export var id: StringName
@export var display_name: String
@export var price := 0
@export var kind: StringName = KIND_FLOOR
## Orientación → datos. Piso y tapete: "a" y "b"; pared: "der" e "izq".
@export var orientations: Dictionary[StringName, DecorOrientation] = {}

static var _catalog: Array[DecorData] = []
static var _unlock_stage := 2


static func load_catalog() -> Array[DecorData]:
	if _catalog.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Paths.DECOR_CATALOG_JSON))
		if not parsed is Dictionary:
			push_error("No se pudo leer %s" % Paths.DECOR_CATALOG_JSON)
			return _catalog
		_unlock_stage = int((parsed as Dictionary).get("etapa_desbloqueo", _unlock_stage))
		for entry: Variant in (parsed as Dictionary).get("objetos", []):
			if entry is Dictionary:
				_catalog.append(_from_dict(entry))
	return _catalog


## Número de etapa desde la que abre la tienda.
static func get_unlock_stage() -> int:
	load_catalog()
	return _unlock_stage


static func find(decor_id: StringName) -> DecorData:
	for decor: DecorData in load_catalog():
		if decor.id == decor_id:
			return decor
	return null


func get_orientation_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(orientations.keys())
	return ids


func get_default_orientation() -> StringName:
	return get_orientation_ids()[0]


## La otra orientación (girar).
func get_rotated(orientation_id: StringName) -> StringName:
	var ids := get_orientation_ids()
	return ids[(ids.find(orientation_id) + 1) % ids.size()]


func is_wall() -> bool:
	return kind == KIND_WALL


func is_trophy() -> bool:
	return id == TROPHY_ID


## Precio al vender (50 %).
func get_sell_price() -> int:
	return price / 2


static func _from_dict(data: Dictionary) -> DecorData:
	var decor := DecorData.new()
	decor.id = StringName(str(data.get("id", "")))
	decor.display_name = str(data.get("nombre", decor.id))
	decor.price = int(data.get("precio", 0))
	decor.kind = StringName(str(data.get("tipo", KIND_FLOOR)))
	var raw: Dictionary = data.get("orientaciones", {})
	for key: String in raw:
		var entry: Dictionary = raw[key]
		var orientation := DecorOrientation.new()
		orientation.sprite_path = str(entry.get("sprite", ""))
		orientation.anchor = RoomProjection.parse_vector(entry.get("ancla"))
		orientation.footprint_m = RoomProjection.parse_vector(entry.get("huella_m"))
		var cells := RoomProjection.parse_vector(entry.get("huella_celdas"))
		orientation.footprint_cells = Vector2i(int(cells.x), int(cells.y))
		decor.orientations[StringName(key)] = orientation
	return decor
