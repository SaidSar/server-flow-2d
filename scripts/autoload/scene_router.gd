extends Node
## Autoload "SceneRouter": cambios de escena con fundido a negro.
## También guarda escenas precargadas por la pantalla de carga.

signal scene_changed(scene_path: String)

const FADE_SECONDS := 0.25

## La siguiente entrada al cuarto viene del dashboard (el cuarto hace zoom de regreso).
var returning_from_dashboard := false
## Lo que debe cargar y a dónde ir la pantalla de carga.
var pending_target := ""
var pending_preloads: PackedStringArray = []

var _cache: Dictionary[String, PackedScene] = {}
var _is_changing := false
var _fade_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 100
	add_child(fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_layer.add_child(_fade_rect)


func is_changing() -> bool:
	return _is_changing


## Fundido a negro → cambio de escena → fundido de entrada.
## Todo va encadenado en un Tween (sin await) para que cerrar el juego a media transición no deje nada colgado.
func goto(scene_path: String, fade_seconds: float = FADE_SECONDS) -> void:
	if _is_changing:
		return
	_is_changing = true
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, fade_seconds)
	tween.tween_callback(_change_scene.bind(scene_path))
	tween.tween_property(_fade_rect, "modulate:a", 0.0, fade_seconds)
	tween.tween_callback(_finish_change.bind(scene_path))


## Va a la pantalla de carga, que precarga `preloads` y después abre `target`.
func goto_via_loading(target: String, preloads: PackedStringArray) -> void:
	pending_target = target
	pending_preloads = preloads
	goto(Paths.LOADING_SCREEN)


## Va al cuarto de la etapa actual.
func goto_current_room(fade_seconds: float = FADE_SECONDS) -> void:
	goto(get_current_room_path(), fade_seconds)


## Escena del cuarto de la etapa actual. Las etapas cuyo cuarto aún no existe usan el de la etapa 1.
func get_current_room_path() -> String:
	return _get_room_stage().room_scene_path


## Nombre del cuarto que se está mostrando ("Garage" mientras la oficina no exista).
func get_current_room_name() -> String:
	return _get_room_stage().room_name


func _get_room_stage() -> StageData:
	var stage := Simulation.stage
	if stage == null or stage.room_scene_path.is_empty():
		stage = Simulation.load_stage(Paths.STAGE_ORDER[0])
	return stage


func store_preloaded(path: String, resource: Resource) -> void:
	var packed := resource as PackedScene
	if packed != null:
		_cache[path] = packed


func quit_game() -> void:
	SaveSystem.save_game()
	get_tree().quit()


func _change_scene(scene_path: String) -> void:
	var packed := _get_packed_scene(scene_path)
	if packed == null:
		push_error("No se pudo cargar la escena %s" % scene_path)
		return
	get_tree().change_scene_to_packed(packed)


func _finish_change(scene_path: String) -> void:
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_changing = false
	scene_changed.emit(scene_path)


func _get_packed_scene(scene_path: String) -> PackedScene:
	if _cache.has(scene_path):
		return _cache[scene_path]
	return load(scene_path) as PackedScene
