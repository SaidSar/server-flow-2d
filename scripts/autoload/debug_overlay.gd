extends CanvasLayer
## Autoload "DebugOverlay": FPS, tiempo de proceso y memoria, solo en builds de depuración.
## Se muestra/oculta con F3 (PC) o con un toque de tres dedos (celular).

const REFRESH_SECONDS := 0.5
const TOGGLE_TOUCHES := 3
const MARGIN := 8.0
const BYTES_PER_MB := 1024.0 * 1024.0

var _label: Label
var _elapsed := 0.0
## Dedos tocando la pantalla ahora mismo.
var _touches: Dictionary[int, bool] = {}


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 99
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override(&"font_size", 16)
	_label.add_theme_color_override(&"font_color", Color(0.75, 1.0, 0.8))
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_label.visible = false
	add_child(_label)
	# SceneRouter es otro autoload que todavía no existe en este _ready.
	(func() -> void: SceneRouter.safe_area_changed.connect(_place_label)).call_deferred()
	_place_label()
	if OS.has_feature("mobile"):
		_log_display_info()


func _process(delta: float) -> void:
	if not _label.visible:
		return
	_elapsed += delta
	if _elapsed < REFRESH_SECONDS:
		return
	_elapsed = 0.0
	_label.text = "%d FPS · proceso %.1f ms · texturas %.0f MB · memoria %.0f MB" % [
		Performance.get_monitor(Performance.TIME_FPS),
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / BYTES_PER_MB,
		Performance.get_monitor(Performance.MEMORY_STATIC) / BYTES_PER_MB,
	]


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_F3:
		toggle()
		return
	var touch := event as InputEventScreenTouch
	if touch == null:
		return
	if touch.pressed:
		_touches[touch.index] = true
		if _touches.size() == TOGGLE_TOUCHES:
			toggle()
	else:
		_touches.erase(touch.index)


func toggle() -> void:
	_label.visible = not _label.visible
	_elapsed = REFRESH_SECONDS


func is_shown() -> bool:
	return _label != null and _label.visible


func _place_label() -> void:
	var insets := SafeArea.get_insets(get_viewport())
	_label.offset_right = -(MARGIN + insets.z)
	_label.offset_top = MARGIN * 0.25 + insets.y


## Deja en el log la pantalla y su zona segura (útil para revisar el logcat del celular).
func _log_display_info() -> void:
	print("[DebugOverlay] ventana %s en %s, zona segura %s, viewport %s, márgenes seguros %s" % [
		DisplayServer.window_get_size(), DisplayServer.window_get_position(), DisplayServer.get_display_safe_area(),
		get_viewport().get_visible_rect().size, SafeArea.get_insets(get_viewport())])
