class_name RoomBase
extends Node2D
## Cuarto isométrico base. Las capas son PNG recortados de un lienzo 2x; cada uno se coloca en su
## offset (Customization.apply_layer) dentro de Layers (escala 0.5). Cada cuarto hereda esta escena,
## asigna sus texturas y lee de data/rooms/<room_id>.json (RoomData) su lienzo, los sprites que
## reutiliza del garage con su desplazamiento y, si admite decoración, su proyección.
## Los racks y la mesa con el avatar van en YSort, ordenados con la decoración de piso.
## Clic en la PC → zoom al monitor → dashboard.

## Zoom máximo del cuarto completo; los cuartos grandes se alejan para caber en pantalla.
const CAMERA_MAX_ZOOM_ROOM := 1.5
## Fracción de la pantalla que puede ocupar el cuarto.
const CAMERA_FIT_MARGIN := 0.98
const CAMERA_ZOOM_MONITOR := Vector2(12.0, 12.0)
const CAMERA_ZOOM_SECONDS := 0.8
const CAMERA_PAN_SECONDS := 0.35
const DASHBOARD_FADE_SECONDS := 0.15
## Alto aproximado de la barra de decoración: la cámara sube la mitad para que no tape el piso.
const DECOR_TOOLBAR_HEIGHT := 200.0
## Hueco de cada rack en reutilizados_del_garage / ysort_m; rack i = servidor web i.
const RACK_SLOTS: Array[StringName] = [&"rack_1", &"rack_2"]
## Hueco de la mesa con el avatar en ysort_m.
const DESK_SLOT := &"mesa"

## Carpeta del arte del cuarto: assets/art/rooms/<room_id>/ y data/rooms/<room_id>.json
@export var room_id: StringName = &"garage"
@export var rack_ok_texture: Texture2D
@export var rack_saturated_texture: Texture2D

@onready var _camera: Camera2D = %Camera
@onready var _layers: Node2D = %Layers
@onready var _workstation: Node2D = %Workstation
@onready var _racks: Array[Sprite2D] = [%Rack as Sprite2D, %Rack2 as Sprite2D]
@onready var _boxes: Sprite2D = %Boxes
@onready var _avatar: Avatar = %Avatar
@onready var _pc_area: Area2D = %PcArea
@onready var _monitor_focus: Marker2D = %MonitorFocus
@onready var _decor_placer: DecorPlacer = %DecorPlacer
@onready var _hud: Hud = %Hud
@onready var _customize_panel: CustomizePanel = %CustomizePanel
@onready var _shop_panel: ShopPanel = %ShopPanel
@onready var _settings_button: SettingsButton = %SettingsButton

var room_data: RoomData
## Capa personalizable → sprite que la dibuja.
var _layer_sprites: Dictionary[StringName, Sprite2D] = {}
var _rack_saturated: Array[bool] = [false, false]
var _room_zoom := Vector2.ONE * CAMERA_MAX_ZOOM_ROOM
var _pc_enabled := true
var _camera_tween: Tween


func _ready() -> void:
	# Los Area2D solo reciben clics/toques si el viewport hace picking.
	get_viewport().physics_object_picking = true
	room_data = RoomData.load_room(room_id)
	_room_zoom = _compute_room_zoom()
	_layer_sprites = {
		Customization.get_floor_layer(room_id): %Floor as Sprite2D,
		&"pared_izq": %WallLeft as Sprite2D,
		&"pared_der": %WallRight as Sprite2D,
		&"puerta": %Door as Sprite2D,
		&"mesa": %Desk as Sprite2D,
	}
	_place_ysort_holders()

	for layer: StringName in _layer_sprites:
		_apply_color(layer, GameState.get_color(layer))
	Customization.apply_layer(_boxes, _boxes.texture)
	_avatar.set_avatar(GameState.get_avatar())
	_avatar.position = room_data.get_reuse_offset(GameState.avatar_id) - _workstation.position
	_avatar.set_display_name(GameState.avatar_name)
	_refresh_racks(true)
	_avatar.set_stressed(Simulation.is_saturated)
	_decor_placer.setup(self)

	GameState.color_changed.connect(_apply_color)
	Simulation.saturation_changed.connect(_on_saturation_changed)
	Simulation.tick.connect(_on_simulation_tick)
	Simulation.phase_changed.connect(_on_phase_changed)
	_pc_area.input_event.connect(_on_pc_area_input_event)
	_pc_area.mouse_entered.connect(_on_pc_area_mouse_entered)
	_pc_area.mouse_exited.connect(_on_pc_area_mouse_exited)
	_hud.customize_requested.connect(_on_customize_requested)
	_hud.shop_requested.connect(open_shop)
	_customize_panel.opened.connect(_on_side_panel_opened)
	_customize_panel.closed.connect(_on_side_panel_closed.unbind(1))
	_shop_panel.opened.connect(_on_side_panel_opened)
	_shop_panel.closed.connect(_on_side_panel_closed)
	_decor_placer.busy_changed.connect(_on_decor_busy_changed)

	if SceneRouter.returning_from_dashboard:
		SceneRouter.returning_from_dashboard = false
		_zoom_out_from_monitor()
	else:
		_camera.position = _get_overview_position()
		_camera.zoom = _room_zoom


func _exit_tree() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func get_layers() -> Node2D:
	return _layers


## Abre la tienda de decoración (si la etapa y la fase lo permiten).
func open_shop() -> void:
	if _pc_enabled and DecorShop.is_open():
		_decor_placer.open_shop()


## La mesa con el avatar y los racks se ordenan con la decoración por el centro de su huella.
## Sus sprites siguen en su offset del lienzo: se compensa la posición del nodo que los contiene.
func _place_ysort_holders() -> void:
	_workstation.position = room_data.get_ysort_position(DESK_SLOT)
	for i in _racks.size():
		var holder := _racks[i].get_parent() as Node2D
		holder.position = room_data.get_ysort_position(RACK_SLOTS[i])
		holder.visible = i == 0 or room_data.reuses(RACK_SLOTS[i])


func _apply_color(layer: StringName, option_id: StringName) -> void:
	var sprite: Sprite2D = _layer_sprites.get(layer)
	if sprite == null:
		return
	# La puerta y la mesa de la oficina son los sprites del garage, desplazados.
	var texture_room := &"garage" if room_data.reuses(layer) else room_id
	var texture := Customization.load_layer_texture(texture_room, layer, option_id)
	Customization.apply_layer(sprite, texture, room_data.get_reuse_offset(layer) - _holder_position(sprite))


func _holder_position(sprite: Sprite2D) -> Vector2:
	var parent := sprite.get_parent() as Node2D
	return Vector2.ZERO if parent == _layers else parent.position


## Cada rack muestra si su servidor web está saturado.
func _refresh_racks(force: bool = false) -> void:
	for i in _racks.size():
		var saturated := Simulation.is_server_saturated(i)
		if not force and saturated == _rack_saturated[i]:
			continue
		_rack_saturated[i] = saturated
		var texture := rack_saturated_texture if saturated else rack_ok_texture
		Customization.apply_layer(_racks[i], texture, room_data.get_reuse_offset(RACK_SLOTS[i]) - _holder_position(_racks[i]))


func _on_simulation_tick(_snapshot: SimSnapshot) -> void:
	_refresh_racks()


func _on_saturation_changed(saturated: bool) -> void:
	_refresh_racks()
	_avatar.set_stressed(saturated)


func _on_phase_changed(_phase: Simulation.Phase) -> void:
	_refresh_racks()


## Zoom con el que el lienzo completo del cuarto cabe en la pantalla (sin pasar del máximo).
func _compute_room_zoom() -> Vector2:
	var room_size := room_data.canvas_size * _layers.scale
	var screen := get_viewport_rect().size
	if room_size.x <= 0.0 or room_size.y <= 0.0:
		return Vector2.ONE * CAMERA_MAX_ZOOM_ROOM
	var fit := minf(screen.x / room_size.x, screen.y / room_size.y) * CAMERA_FIT_MARGIN
	return Vector2.ONE * minf(CAMERA_MAX_ZOOM_ROOM, fit)


## Centro del cuarto en coordenadas del mundo: el centro de su lienzo 2x, que empieza en el origen
## de Layers. No usa el tamaño de las texturas porque están recortadas.
func _get_overview_position() -> Vector2:
	return _layers.to_global(room_data.canvas_size * 0.5)


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
	var tween := _tween_camera(_get_overview_position(), _room_zoom, CAMERA_ZOOM_SECONDS, Tween.EASE_OUT)
	tween.finished.connect(_on_zoom_out_finished)


func _on_zoom_out_finished() -> void:
	_hud.show()
	_set_pc_enabled(true)
	# Botón "Tienda" del post-mortem.
	if SceneRouter.open_shop_on_return:
		SceneRouter.open_shop_on_return = false
		open_shop()


func _on_customize_requested() -> void:
	_customize_panel.open(room_id)


## El pincel y la tienda ocupan el lado derecho: bloquean la PC, ocultan el engranaje y recorren
## la cámara para que el cuarto no quede detrás del panel.
func _on_side_panel_opened() -> void:
	_set_pc_enabled(false)
	_settings_button.set_gear_visible(false)
	var offset := Vector2(CustomizePanel.PANEL_WIDTH * 0.5 / _room_zoom.x, 0.0)
	_tween_camera(_get_overview_position() + offset, _room_zoom, CAMERA_PAN_SECONDS, Tween.EASE_IN_OUT)


func _on_side_panel_closed() -> void:
	_tween_camera(_get_overview_position(), _room_zoom, CAMERA_PAN_SECONDS, Tween.EASE_IN_OUT)
	_settings_button.set_gear_visible(true)
	if not _decor_placer.is_busy():
		_set_pc_enabled(true)


## Mientras se coloca o se selecciona decoración, la PC y los botones del HUD no responden y la
## cámara sube para que la barra de abajo no tape el piso.
func _on_decor_busy_changed(busy: bool) -> void:
	_hud.set_alert_suppressed(busy)
	var offset := Vector2(0.0, DECOR_TOOLBAR_HEIGHT * 0.5 / _room_zoom.y) if busy else Vector2.ZERO
	_tween_camera(_get_overview_position() + offset, _room_zoom, CAMERA_PAN_SECONDS, Tween.EASE_IN_OUT)
	if not _shop_panel.visible:
		_set_pc_enabled(not busy)


func _set_pc_enabled(enabled: bool) -> void:
	_pc_enabled = enabled
	_hud.set_buttons_enabled(enabled)
	_decor_placer.set_selection_enabled(enabled)
	if not enabled:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _tween_camera(target_position: Vector2, target_zoom: Vector2, seconds: float, ease_type: Tween.EaseType) -> Tween:
	if _camera_tween != null:
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(ease_type)
	_camera_tween.tween_property(_camera, "position", target_position, seconds)
	_camera_tween.tween_property(_camera, "zoom", target_zoom, seconds)
	return _camera_tween
