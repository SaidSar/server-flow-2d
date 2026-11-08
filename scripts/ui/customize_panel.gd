class_name CustomizePanel
extends CanvasLayer
## Panel lateral para cambiar los colores del cuarto.
## Cada muestra cambia la capa en vivo (vía GameState); "Guardar" guarda y "Cancelar" revierte.
## Las filas son las capas del cuarto abierto: paredes, puerta y mesa son comunes y el piso es propio.

signal opened
signal closed(saved: bool)

const PANEL_WIDTH := 560.0
const SWATCH_SIZE := Vector2(72, 72)
const SWATCH_RADIUS := 10

@onready var _panel: PanelContainer = %Panel
@onready var _groups_box: VBoxContainer = %GroupsBox
@onready var _save_button: Button = %SaveButton
@onready var _cancel_button: Button = %CancelButton

## Colores al abrir el panel, para poder cancelar.
var _snapshot: Dictionary[StringName, StringName] = {}
## Capa → { id de opción → Button }.
var _swatches: Dictionary[StringName, Dictionary] = {}
## Capa → Label con el nombre del color elegido.
var _selection_labels: Dictionary[StringName, Label] = {}
## Cuarto cuyas capas muestra el panel.
var _room_id: StringName = &""


func _ready() -> void:
	hide()
	_fit_safe_area()
	SceneRouter.safe_area_changed.connect(_fit_safe_area)
	_save_button.pressed.connect(_on_save_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	GameState.color_changed.connect(_on_color_changed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


## El panel va pegado al borde derecho: se recorre si ahí está la cámara del celular.
func _fit_safe_area() -> void:
	var insets := SafeArea.get_insets(get_viewport())
	_panel.offset_right = -insets.z
	_panel.offset_left = -PANEL_WIDTH - insets.z


func open(room_id: StringName) -> void:
	if visible:
		return
	if room_id != _room_id:
		_build_groups(room_id)
	_snapshot.assign(GameState.colors)
	for layer_id: StringName in Customization.get_room_layers(_room_id):
		_show_selection(layer_id, GameState.get_color(layer_id))
	show()
	opened.emit()


func _build_groups(room_id: StringName) -> void:
	_room_id = room_id
	for child: Node in _groups_box.get_children():
		child.queue_free()
	_swatches.clear()
	_selection_labels.clear()
	for layer_id: StringName in Customization.get_room_layers(room_id):
		var header := HBoxContainer.new()
		var title := Label.new()
		title.text = Customization.get_layer_title(layer_id)
		title.add_theme_font_size_override(&"font_size", 30)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var selection_label := Label.new()
		selection_label.add_theme_color_override(&"font_color", DashboardColors.TEXT_SOFT)
		selection_label.add_theme_font_size_override(&"font_size", 24)
		header.add_child(selection_label)
		_selection_labels[layer_id] = selection_label
		_groups_box.add_child(header)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override(&"h_separation", 8)
		flow.add_theme_constant_override(&"v_separation", 8)
		var button_group := ButtonGroup.new()
		var buttons: Dictionary = {}
		for option: CustomizationOption in Customization.get_options(layer_id):
			var swatch := _create_swatch(option, button_group)
			swatch.pressed.connect(_on_swatch_pressed.bind(layer_id, option.id))
			flow.add_child(swatch)
			buttons[option.id] = swatch
		_swatches[layer_id] = buttons
		_groups_box.add_child(flow)


func _create_swatch(option: CustomizationOption, button_group: ButtonGroup) -> Button:
	var swatch := Button.new()
	swatch.toggle_mode = true
	swatch.button_group = button_group
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.tooltip_text = option.display_name
	swatch.add_theme_stylebox_override(&"normal", _make_swatch_style(option.color, Color(DashboardColors.SWATCH_BORDER, 0.9), 3))
	swatch.add_theme_stylebox_override(&"hover", _make_swatch_style(option.color, DashboardColors.SWATCH_BORDER_HOVER, 3))
	swatch.add_theme_stylebox_override(&"pressed", _make_swatch_style(option.color, DashboardColors.HIGHLIGHT, 6))
	swatch.add_theme_stylebox_override(&"hover_pressed", _make_swatch_style(option.color, DashboardColors.HIGHLIGHT, 6))
	return swatch


func _make_swatch_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(SWATCH_RADIUS)
	return style


func _on_swatch_pressed(layer_id: StringName, option_id: StringName) -> void:
	GameState.set_color(layer_id, option_id)


func _on_color_changed(layer_id: StringName, option_id: StringName) -> void:
	_show_selection(layer_id, option_id)


func _show_selection(layer_id: StringName, option_id: StringName) -> void:
	# set_pressed_no_signal() no desmarca al resto del ButtonGroup, así que se marca cada muestra.
	var buttons: Dictionary = _swatches.get(layer_id, {})
	for swatch_id: StringName in buttons:
		(buttons[swatch_id] as Button).set_pressed_no_signal(swatch_id == option_id)
	var option := Customization.find_option(layer_id, option_id)
	if _selection_labels.has(layer_id) and option != null:
		_selection_labels[layer_id].text = option.display_name


func _on_save_pressed() -> void:
	SaveSystem.save_game()
	_close(true)


func _on_cancel_pressed() -> void:
	GameState.apply_colors(_snapshot)
	_close(false)


func _close(saved: bool) -> void:
	hide()
	closed.emit(saved)
