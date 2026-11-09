class_name PetData
extends Resource
## Una mascota del catálogo (data/pets/mascotas.json): precio, velocidades y hoja de sprites.
## Todo el balance vive en el JSON; aquí solo se lee.

## Cuadros de la hoja de sprites (mismo orden que source_art/mascotas/generar_mascotas.py).
const FRAME_IDLE := 0
const FRAME_WALK_FIRST := 1
const FRAME_WALK_COUNT := 4
const FRAME_SLEEP := 5
const FRAME_SCARED := 6

@export var id: StringName
@export var display_name: String
@export var description: String
@export var price := 0
## Archivo de la hoja en assets/art/mascotas/ (sin .png).
@export var sheet: String = ""
@export var walk_speed_m_s := 1.0
@export var scared_speed_m_s := 2.0
## Cuánto se queda quieta entre un paseo y otro (segundos: mínimo, máximo).
@export var idle_range_s := Vector2(2.0, 4.0)
## Probabilidad de ir a echarse a dormir en el punto de descanso del cuarto cuando elige destino.
@export_range(0.0, 1.0) var sleep_chance := 0.0

static var _catalog: Array[PetData] = []
static var _max_total := 6
static var _frame_size := Vector2i(160, 128)
static var _anchor := Vector2(80, 112)
static var _loaded := false


static func load_catalog() -> Array[PetData]:
	if _loaded:
		return _catalog
	_loaded = true
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(Paths.PETS_JSON))
	if not parsed is Dictionary:
		push_error("No se pudo leer %s" % Paths.PETS_JSON)
		return _catalog
	var root: Dictionary = parsed
	_max_total = maxi(int(root.get("max_total", _max_total)), 1)
	var sheet_info: Dictionary = root.get("hoja", {})
	var frame := RoomProjection.parse_vector(sheet_info.get("cuadro_px"))
	if frame != Vector2.ZERO:
		_frame_size = Vector2i(frame)
	var anchor := RoomProjection.parse_vector(sheet_info.get("ancla_px"))
	if anchor != Vector2.ZERO:
		_anchor = anchor
	for entry: Variant in root.get("mascotas", []):
		if entry is Dictionary:
			var pet := _from_dict(entry)
			if pet != null:
				_catalog.append(pet)
	return _catalog


static func find(pet_id: StringName) -> PetData:
	for pet: PetData in load_catalog():
		if pet.id == pet_id:
			return pet
	return null


## Mascotas que se pueden tener en total.
static func get_max_total() -> int:
	load_catalog()
	return _max_total


static func get_frame_size() -> Vector2i:
	load_catalog()
	return _frame_size


## Posición de los pies dentro de un cuadro, en píxeles.
static func get_anchor() -> Vector2:
	load_catalog()
	return _anchor


func get_sheet_path() -> String:
	return Paths.PET_SHEET % sheet


func load_sheet() -> Texture2D:
	return load(get_sheet_path()) as Texture2D


## Un cuadro de la hoja como textura suelta (miniatura de la tienda).
func get_frame_texture(frame: int) -> Texture2D:
	var texture := load_sheet()
	if texture == null:
		return null
	var size := get_frame_size()
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(frame * size.x, 0, size.x, size.y)
	return atlas


static func _from_dict(data: Dictionary) -> PetData:
	var pet := PetData.new()
	pet.id = StringName(str(data.get("id", "")))
	if pet.id == &"":
		return null
	pet.display_name = str(data.get("nombre", pet.id))
	pet.description = str(data.get("descripcion", ""))
	pet.price = maxi(int(data.get("precio", 0)), 0)
	pet.sheet = str(data.get("hoja", pet.id))
	pet.walk_speed_m_s = maxf(float(data.get("velocidad_m_s", 1.0)), 0.1)
	pet.scared_speed_m_s = maxf(float(data.get("velocidad_susto_m_s", 2.0)), 0.1)
	var idle := RoomProjection.parse_vector(data.get("quieto_s"))
	if idle != Vector2.ZERO:
		pet.idle_range_s = Vector2(minf(idle.x, idle.y), maxf(idle.x, idle.y))
	pet.sleep_chance = clampf(float(data.get("prob_dormir", 0.0)), 0.0, 1.0)
	return pet
