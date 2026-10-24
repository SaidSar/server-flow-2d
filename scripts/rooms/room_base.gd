class_name RoomBase
extends Node2D
## Cuarto isométrico base. Las capas son PNG recortados de un mismo lienzo 2x; cada uno se
## coloca en su offset (Customization.apply_layer) dentro de Layers (escala 0.5).
## Cada cuarto hereda esta escena y asigna sus texturas.
## Clic en la PC → zoom al monitor → dashboard.

const CAMERA_ZOOM_ROOM := Vector2(1.5, 1.5)
const CAMERA_ZOOM_MONITOR := Vector2(12.0, 12.0)
const CAMERA_ZOOM_SECONDS := 0.8
const CAMERA_PAN_SECONDS := 0.35
const DASHBOARD_FADE_SECONDS := 0.15

## Carpeta del arte del cuarto: assets/art/rooms/<room_id>/
@export var room_id: StringName = &"garage"
@export var rack_ok_texture: Texture2D
@export var rack_saturated_texture: Texture2D

@onready var _camera: Camera2D = %Camera
@onready var _layers: Node2D = %Layers
@onready var _rack: Sprite2D = %Rack
@onready var _boxes: Sprite2D = %Boxes
@onready var _avatar: Avatar = %Avatar
@onready var _pc_area: Area2D = %PcArea
@onready var _monitor_focus: Marker2D = %MonitorFocus
@onready var _hud: Hud = %Hud
@onready var _customize_panel: CustomizePanel = %CustomizePanel
@onready var _settings_button: SettingsButton = %SettingsButton
## Capa personalizable → sprite que la dibuja.
@onready var _layer_sprites: Dictionary[StringName, Sprite2D] = {
	&"piso": %Floor as Sprite2D,
	&"pared_izq": %WallLeft as Sprite2D,
	&"pared_der": %WallRight as Sprite2D,
	&"puerta": %Door as Sprite2D,
	&"mesa": %Desk as Sprite2D,
}

var _pc_enabled := true
var _camera_tween: Tween


func _ready() -> void:
	# Los Area2D solo reciben clics/toques si el viewport hace picking.
	get_viewport().physics_object_picking = true

	for layer: StringName in _layer_sprites:
		_apply_color(layer, GameState.get_color(layer))
	Customization.apply_layer(_boxes, _boxes.texture)
	_avatar.set_display_name(GameState.avatar_name)
	_set_saturated(Simulation.is_saturated)

	GameState.color_changed.connect(_apply_color)
	Simulation.saturation_changed.connect(_set_saturated)
	_pc_area.input_event.connect(_on_pc_area_input_event)
	_pc_area.mouse_entered.connect(_on_pc_area_mouse_entered)
	_pc_area.mouse_exited.connect(_on_pc_area_mouse_exited)
	_hud.customize_requested.connect(_customize_panel.open)
	_customize_panel.opened.connect(_on_customize_opened)
	_customize_panel.closed.connect(_on_customize_closed)

	if SceneRouter.returning_from_dashboard:
		SceneRouter.returning_from_dashboard = false
		_zoom_out_from_monitor()
	else:
		_camera.position = _get_overview_position()
		_camera.zoom = CAMERA_ZOOM_ROOM


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _apply_color(layer: StringName, option_id: StringName) -> void:
	var sprite: Sprite2D = _layer_sprites.get(layer)
	if sprite != null:
		Customization.apply_layer(sprite, Customization.load_layer_texture(room_id, layer, option_id))


func _set_saturated(saturated: bool) -> void:
	Customization.apply_layer(_rack, rack_saturated_texture if saturated else rack_ok_texture)
	_avatar.set_stressed(saturated)


## Centro del cuarto en coordenadas del mundo: el centro del lienzo 2x, que empieza en el origen
## de Layers. No usa el tamaño de las texturas porque están recortadas.
func _get_overview_position() -> Vector2:
	return _layers.to_global(Customization.canvas_size * 0.5)


func _on_pc_area_input_event(_viewport: Node, event: InputEvent, _shape_index: int) -> void:
	var click := event as InputEventMouseButton
	if _pc_enabled and click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_enter_monitor()


func _on_pc_area_mouse_entered() -> void:
	if _pc_enabled:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


func _on_pc_area_mouse_exited() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _enter_monitor() -> void:
	_set_pc_enabled(false)
	_hud.hide()
	var tween := _tween_camera(_monitor_focus.global_position, CAMERA_ZOOM_MONITOR, CAMERA_ZOOM_SECONDS, Tween.EASE_IN)
	tween.finished.connect(SceneRouter.goto.bind(Paths.DASHBOARD, DASHBOARD_FADE_SECONDS))


func _zoom_out_from_monitor() -> void:
	_set_pc_enabled(false)
	_hud.hide()
	_camera.position = _monitor_focus.global_position
	_camera.zoom = CAMERA_ZOOM_MONITOR
	var tween := _tween_camera(_get_overview_position(), CAMERA_ZOOM_ROOM, CAMERA_ZOOM_SECONDS, Tween.EASE_OUT)
	tween.finished.connect(_on_zoom_out_finished)


func _on_zoom_out_finished() -> void:
	_hud.show()
	_set_pc_enabled(true)


func _on_customize_opened() -> void:
	_set_pc_enabled(false)
	# El panel del pincel ocupa la esquina del engranaje.
	_settings_button.set_gear_visible(false)
	# Recorre la cámara para que el cuarto no quede detrás del panel lateral.
	var offset := Vector2(CustomizePanel.PANEL_WIDTH * 0.5 / CAMERA_ZOOM_ROOM.x, 0.0)
	_tween_camera(_get_overview_position() + offset, CAMERA_ZOOM_ROOM, CAMERA_PAN_SECONDS, Tween.EASE_IN_OUT)


func _on_customize_closed(_saved: bool) -> void:
	_tween_camera(_get_overview_position(), CAMERA_ZOOM_ROOM, CAMERA_PAN_SECONDS, Tween.EASE_IN_OUT)
	_set_pc_enabled(true)
	_settings_button.set_gear_visible(true)


func _set_pc_enabled(enabled: bool) -> void:
	_pc_enabled = enabled
	_hud.set_customize_enabled(enabled)
	if not enabled:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _tween_camera(target_position: Vector2, target_zoom: Vector2, seconds: float, ease_type: Tween.EaseType) -> Tween:
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	_camera_tween.tween_property(_camera, "position", target_position, seconds)
	_camera_tween.tween_property(_camera, "zoom", target_zoom, seconds)
	return _camera_tween
