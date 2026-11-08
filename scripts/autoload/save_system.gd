extends Node
## Autoload "SaveSystem": guarda y carga la partida en un ConfigFile.
## Guarda la identidad (GameState: personaje, nombres, colores y decoración) y el checkpoint de Simulation: etapa, oleada, monedas,
## niveles de mejoras, disco usado, usuarios atendidos y estadísticas por etapa.
## El checkpoint es el inicio de la oleada en curso, así que "Continuar" vuelve a ese punto.
## Ruta alterna (pruebas, mediciones y partidas de prueba): argumento "--save-path=<ruta>" después
## de "--", variable de entorno SERVERFLOW_SAVE_PATH o, solo en builds debug, el archivo
## user://save_path_override.txt (en Android la app no recibe argumentos: se escribe con adb run-as).
## Así nunca se toca la partida real.

signal saved

## 3: agrega player/avatar_id (las partidas sin él son de Alex).
## 5: decoración inicial entregada por cuarto (decor/initial_granted). Las partidas anteriores no la traen
##    y reciben las ventanas de la oficina al entrar a ella.
## 4: piso por cuarto (colors/piso_<cuarto>) y decoración (sección "decor"). Las partidas
##    anteriores migran su "piso" al garage y empiezan sin decoración.
const SAVE_VERSION := 5
const SECTION_META := "meta"
const SECTION_PLAYER := "player"
const SECTION_COLORS := "colors"
const SECTION_PROGRESS := "progress"
const SECTION_DECOR := "decor"
const SAVE_PATH_ARG := "--save-path="
const SAVE_PATH_ENV := "SERVERFLOW_SAVE_PATH"
const SAVE_PATH_OVERRIDE_FILE := "user://save_path_override.txt"

var save_path := Paths.SAVE_FILE
## true si algo leyó o escribió la partida real (Paths.SAVE_FILE). Las pruebas lo revisan.
var real_save_accessed := false


func _ready() -> void:
	save_path = get_alternate_save_path()
	if save_path.is_empty():
		save_path = Paths.SAVE_FILE
	elif OS.is_debug_build():
		print("[SaveSystem] Ruta alterna de guardado: %s" % save_path)
	# Guardado automático al empezar y al terminar cada oleada (y al pasar de etapa).
	Simulation.checkpoint_created.connect(_on_checkpoint_created)


func _notification(what: int) -> void:
	# Guardado automático al cerrar la ventana (Windows) o al mandar la app a segundo plano (Android).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


## Ruta alterna pedida por argumento, variable de entorno o archivo de override ("" si no hay).
static func get_alternate_save_path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SAVE_PATH_ARG):
			return arg.trim_prefix(SAVE_PATH_ARG)
	var from_env := OS.get_environment(SAVE_PATH_ENV)
	if not from_env.is_empty():
		return from_env
	# Un jugador nunca tiene este archivo; en release se ignora por si acaso.
	if OS.is_debug_build() and FileAccess.file_exists(SAVE_PATH_OVERRIDE_FILE):
		return FileAccess.get_file_as_string(SAVE_PATH_OVERRIDE_FILE).strip_edges()
	return ""


func is_using_real_save() -> bool:
	return ProjectSettings.globalize_path(save_path) == ProjectSettings.globalize_path(Paths.SAVE_FILE)


func has_save() -> bool:
	_note_access()
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	if not GameState.is_active or not Simulation.has_session():
		return false
	_note_access()

	var data := GameState.to_save_data()
	var config := ConfigFile.new()
	config.set_value(SECTION_META, "version", SAVE_VERSION)
	config.set_value(SECTION_PLAYER, "avatar_id", data["avatar_id"])
	config.set_value(SECTION_PLAYER, "avatar_name", data["avatar_name"])
	config.set_value(SECTION_PLAYER, "company_name", data["company_name"])
	var colors: Dictionary = data["colors"]
	for layer: StringName in colors:
		config.set_value(SECTION_COLORS, layer, String(colors[layer]))
	var inventory := PackedStringArray()
	for decor_id: StringName in data["decor_inventory"]:
		inventory.append(String(decor_id))
	config.set_value(SECTION_DECOR, "inventory", inventory)
	var granted := PackedStringArray()
	for room_id: StringName in data["decor_initial_granted"]:
		granted.append(String(room_id))
	config.set_value(SECTION_DECOR, "initial_granted", granted)
	var placed: Dictionary = data["decor_placed"]
	for room_id: StringName in placed:
		config.set_value(SECTION_DECOR, "placed_" + room_id, placed[room_id])
	var progress := Simulation.get_checkpoint()
	for key: String in progress:
		config.set_value(SECTION_PROGRESS, key, progress[key])

	var error := config.save(save_path)
	if error != OK:
		push_error("No se pudo guardar la partida en %s: %s" % [save_path, error_string(error)])
		return false
	saved.emit()
	return true


## Carga la partida guardada. Devuelve false si no hay o está dañada.
func load_game() -> bool:
	_note_access()
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK:
		push_warning("No se pudo cargar la partida de %s: %s" % [save_path, error_string(error)])
		return false

	var colors: Dictionary = {}
	if config.has_section(SECTION_COLORS):
		for key: String in config.get_section_keys(SECTION_COLORS):
			colors[StringName(key)] = StringName(str(config.get_value(SECTION_COLORS, key, "")))
	var decor_placed: Dictionary = {}
	if config.has_section(SECTION_DECOR):
		for key: String in config.get_section_keys(SECTION_DECOR):
			if key.begins_with("placed_"):
				decor_placed[key.trim_prefix("placed_")] = config.get_value(SECTION_DECOR, key, [])
	var progress: Dictionary = {}
	if config.has_section(SECTION_PROGRESS):
		for key: String in config.get_section_keys(SECTION_PROGRESS):
			progress[key] = config.get_value(SECTION_PROGRESS, key)

	GameState.restore({
		"avatar_id": config.get_value(SECTION_PLAYER, "avatar_id", String(AvatarData.DEFAULT_ID)),
		"avatar_name": config.get_value(SECTION_PLAYER, "avatar_name", ""),
		"company_name": config.get_value(SECTION_PLAYER, "company_name", ""),
		"colors": colors,
		"decor_inventory": config.get_value(SECTION_DECOR, "inventory", PackedStringArray()),
		"decor_placed": decor_placed,
		"decor_initial_granted": config.get_value(SECTION_DECOR, "initial_granted", PackedStringArray()),
	})
	Simulation.load_checkpoint(progress)
	return true


func delete_save() -> void:
	_note_access()
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _note_access() -> void:
	if is_using_real_save():
		real_save_accessed = true


func _on_checkpoint_created() -> void:
	save_game()
