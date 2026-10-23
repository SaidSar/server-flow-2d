extends Node
## Autoload "SaveSystem": guarda y carga la partida en un ConfigFile.
## Guarda la identidad (GameState) y el checkpoint de Simulation: etapa, oleada, monedas,
## niveles de mejoras, disco usado, usuarios atendidos y estadísticas por etapa.
## El checkpoint es el inicio de la oleada en curso, así que "Continuar" vuelve a ese punto.

signal saved

const SAVE_VERSION := 2
const SECTION_META := "meta"
const SECTION_PLAYER := "player"
const SECTION_COLORS := "colors"
const SECTION_PROGRESS := "progress"

## Se puede cambiar en pruebas para no tocar la partida real.
var save_path := Paths.SAVE_FILE


func _ready() -> void:
	# Guardado automático al empezar y al terminar cada oleada (y al pasar de etapa).
	Simulation.checkpoint_created.connect(_on_checkpoint_created)


func _notification(what: int) -> void:
	# Guardado automático al cerrar la ventana (Windows) o al mandar la app a segundo plano (Android).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func save_game() -> bool:
	if not GameState.is_active or not Simulation.has_session():
		return false

	var data := GameState.to_save_data()
	var config := ConfigFile.new()
	config.set_value(SECTION_META, "version", SAVE_VERSION)
	config.set_value(SECTION_PLAYER, "avatar_name", data["avatar_name"])
	config.set_value(SECTION_PLAYER, "company_name", data["company_name"])
	var colors: Dictionary = data["colors"]
	for layer: StringName in colors:
		config.set_value(SECTION_COLORS, layer, String(colors[layer]))
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
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK:
		push_warning("No se pudo cargar la partida de %s: %s" % [save_path, error_string(error)])
		return false

	var colors: Dictionary = {}
	if config.has_section(SECTION_COLORS):
		for key: String in config.get_section_keys(SECTION_COLORS):
			colors[StringName(key)] = StringName(str(config.get_value(SECTION_COLORS, key, "")))
	var progress: Dictionary = {}
	if config.has_section(SECTION_PROGRESS):
		for key: String in config.get_section_keys(SECTION_PROGRESS):
			progress[key] = config.get_value(SECTION_PROGRESS, key)

	GameState.restore({
		"avatar_name": config.get_value(SECTION_PLAYER, "avatar_name", ""),
		"company_name": config.get_value(SECTION_PLAYER, "company_name", ""),
		"colors": colors,
	})
	Simulation.load_checkpoint(progress)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


func _on_checkpoint_created() -> void:
	save_game()
