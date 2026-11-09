class_name AvatarData
extends Resource
## Personaje que el jugador puede elegir (Alex, Alexa...).
## Para agregar otro basta con crear un .tres en resources/avatars/ y su arte.

const DEFAULT_ID := &"alex"

@export var id: StringName
@export var display_name: String
## Descripción corta para la tarjeta de selección ("Sudadera azul").
@export var description: String
## Borde y brillo de la tarjeta cuando está seleccionada.
@export var color := Color.WHITE
## "m" o "f": elige la forma de los textos con género (ver TextUtil).
@export_enum("m", "f") var gender: String = "m"

@export_group("Camiseta")
## Tono (0–1), saturación y valor de la sudadera original en el render. El shader de la camiseta
## recolorea solo los píxeles cercanos a este tono.
@export_range(0.0, 1.0) var shirt_hue := 0.61
@export_range(0.0, 1.0) var shirt_saturation := 0.71
@export_range(0.0, 1.0) var shirt_value := 0.97

@export_group("Sprites")
## Poses sentado, recortadas del lienzo 2x del cuarto (offsets en layer_offsets.json).
@export_file("*.png") var teclea_a: String
@export_file("*.png") var teclea_b: String
@export_file("*.png") var estres: String
## Pose de pie, completa.
@export_file("*.png") var de_pie: String
## Render grande para la pantalla de selección.
@export_file("*.png") var select: String


func load_typing_textures() -> Array[Texture2D]:
	return [load(teclea_a) as Texture2D, load(teclea_b) as Texture2D]


func load_stressed_texture() -> Texture2D:
	return load(estres) as Texture2D


## Todos los personajes de resources/avatars/, con el personaje por defecto primero.
static func load_all() -> Array[AvatarData]:
	var result: Array[AvatarData] = []
	for file: String in ResourceLoader.list_directory(Paths.AVATARS_DIR):
		if file.get_extension() != "tres":
			continue
		var avatar := load(Paths.AVATARS_DIR.path_join(file)) as AvatarData
		if avatar != null:
			result.append(avatar)
	result.sort_custom(func(a: AvatarData, b: AvatarData) -> bool:
		return a.id == DEFAULT_ID or (b.id != DEFAULT_ID and String(a.id) < String(b.id)))
	return result


## Personaje por id; si no existe, el personaje por defecto.
static func find(avatar_id: StringName) -> AvatarData:
	var path := Paths.AVATAR % avatar_id
	if avatar_id.is_empty() or not ResourceLoader.exists(path):
		path = Paths.AVATAR % DEFAULT_ID
	return load(path) as AvatarData
