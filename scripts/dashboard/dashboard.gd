extends Control
## Panel de control (placeholder). Muestra la carga del servidor y regresa al cuarto.

const METRIC_TITLES := {&"cpu": "CPU", &"ram": "RAM", &"network": "Red", &"disk": "Disco"}
const OK_COLOR := Color(0.3, 0.73, 0.43)
const SATURATED_COLOR := Color(0.88, 0.33, 0.29)
const INTRO_SECONDS := 0.3

@onready var _window: Control = %Window
@onready var _metrics_box: VBoxContainer = %MetricsBox
@onready var _back_button: Button = %BackButton

## Recurso → [ProgressBar, Label de valor].
var _metric_rows: Dictionary[StringName, Array] = {}
var _ok_style := _make_fill_style(OK_COLOR)
var _saturated_style := _make_fill_style(SATURATED_COLOR)


func _ready() -> void:
	Simulation.start()
	_build_metrics()
	_back_button.pressed.connect(_on_back_pressed)
	Simulation.tick.connect(_on_simulation_tick)
	_refresh_metrics()
	_back_button.grab_focus()
	_play_intro()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _build_metrics() -> void:
	for resource_id: StringName in ServerState.RESOURCE_IDS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 24)
		var title := Label.new()
		title.text = str(METRIC_TITLES.get(resource_id, resource_id))
		title.custom_minimum_size = Vector2(140, 0)
		row.add_child(title)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 36)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		row.add_child(bar)
		var value_label := Label.new()
		value_label.custom_minimum_size = Vector2(120, 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value_label)
		_metrics_box.add_child(row)
		_metric_rows[resource_id] = [bar, value_label]


func _on_simulation_tick(_tick_index: int) -> void:
	_refresh_metrics()


func _refresh_metrics() -> void:
	if Simulation.servers.is_empty():
		return
	var server := Simulation.servers[0]
	for resource_id: StringName in _metric_rows:
		var value := server.get_load(resource_id)
		var bar: ProgressBar = _metric_rows[resource_id][0]
		var value_label: Label = _metric_rows[resource_id][1]
		bar.value = value
		var saturated := value > Simulation.SATURATION_THRESHOLD
		bar.add_theme_stylebox_override(&"fill", _saturated_style if saturated else _ok_style)
		value_label.text = "%d %%" % roundi(value)


func _on_back_pressed() -> void:
	if SceneRouter.is_changing():
		return
	_back_button.disabled = true
	SceneRouter.returning_from_dashboard = true
	SceneRouter.goto_current_room(RoomBase.DASHBOARD_FADE_SECONDS)


func _play_intro() -> void:
	_window.pivot_offset = _window.size * 0.5
	_window.scale = Vector2(0.9, 0.9)
	_window.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_window, "scale", Vector2.ONE, INTRO_SECONDS)
	tween.tween_property(_window, "modulate:a", 1.0, INTRO_SECONDS)


static func _make_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	return style
