extends Node
## Autoload "Settings": volumen de música y efectos, y tema de la interfaz (Oscuro/Claro).
## Se guarda en user://settings.cfg, aparte de la partida, y se aplica al iniciar el juego.

signal changed

const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const SECTION_AUDIO := "audio"
const SECTION_UI := "ui"
## Tema de la interfaz: "dark" o "light" (ver UiTheme).
const DEFAULT_UI_THEME: StringName = &"dark"
const UI_THEMES: Array[StringName] = [&"dark", &"light"]
const DEFAULT_VOLUME := 0.8

## Se puede cambiar en pruebas para no tocar los ajustes reales.
var settings_path := Paths.SETTINGS_FILE
## Volumen lineal 0..1.
var music_volume := DEFAULT_VOLUME
var sfx_volume := DEFAULT_VOLUME
var music_muted := false
var sfx_muted := false
var ui_theme: StringName = DEFAULT_UI_THEME


func _ready() -> void:
	load_settings()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_settings()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_on_changed()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_on_changed()


func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_on_changed()


func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_on_changed()


func set_ui_theme(value: StringName) -> void:
	ui_theme = value if value in UI_THEMES else DEFAULT_UI_THEME
	_on_changed()


## Aplica los volúmenes a los buses de audio.
func apply() -> void:
	_apply_bus(BUS_MUSIC, music_volume, music_muted)
	_apply_bus(BUS_SFX, sfx_volume, sfx_muted)


func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, "music_volume", music_volume)
	config.set_value(SECTION_AUDIO, "sfx_volume", sfx_volume)
	config.set_value(SECTION_AUDIO, "music_muted", music_muted)
	config.set_value(SECTION_AUDIO, "sfx_muted", sfx_muted)
	config.set_value(SECTION_UI, "theme", String(ui_theme))
	var error := config.save(settings_path)
	if error != OK:
		push_error("No se pudieron guardar los ajustes en %s: %s" % [settings_path, error_string(error)])
		return false
	return true


## Lee los ajustes guardados (o deja los valores por defecto) y los aplica.
func load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(settings_path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("No se pudieron leer los ajustes de %s: %s" % [settings_path, error_string(error)])
	music_volume = clampf(float(config.get_value(SECTION_AUDIO, "music_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	sfx_volume = clampf(float(config.get_value(SECTION_AUDIO, "sfx_volume", DEFAULT_VOLUME)), 0.0, 1.0)
	music_muted = bool(config.get_value(SECTION_AUDIO, "music_muted", false))
	sfx_muted = bool(config.get_value(SECTION_AUDIO, "sfx_muted", false))
	var saved_theme := StringName(str(config.get_value(SECTION_UI, "theme", DEFAULT_UI_THEME)))
	ui_theme = saved_theme if saved_theme in UI_THEMES else DEFAULT_UI_THEME
	apply()
	changed.emit()


func _on_changed() -> void:
	apply()
	changed.emit()


func _apply_bus(bus_name: StringName, volume: float, muted: bool) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("No existe el bus de audio %s (revisa default_bus_layout.tres)." % bus_name)
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, muted or is_zero_approx(volume))
