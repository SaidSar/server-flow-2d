class_name CustomizePanel
extends CanvasLayer
## Panel lateral para cambiar los colores del cuarto.
## Cada muestra cambia la capa en vivo (vía GameState); "Guardar" guarda y "Cancelar" revierte.

signal opened
signal closed(saved: bool)

const PANEL_WIDTH := 560.0
const SWATCH_SIZE := Vector2(72, 72)
const SWATCH_RADIUS := 10
const SELECTED_BORDER_COLOR := Color(0.31, 0.76, 0.97)
const IDLE_BORDER_COLOR := Color(0.05, 0.06, 0.09, 0.9)

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


func _ready() -> void:
	hide()
	_panel.offset_left = -PANEL_WIDTH
	_build_groups()
	_save_button.pressed.connect(_on_save_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	GameState.color_changed.connect(_on_color_changed)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()


func open() -> void:
	if visible:
		return
	_snapshot.assign(GameState.colors)
	for layer: StringName in Customization.LAYER_ORDER:
		_show_selection(layer, GameState.get_color(layer))
	show()
	opened.emit()


func _build_groups() -> void:
	for layer: StringName in Customization.LAYER_ORDER:
		var header := HBoxContainer.new()
		var title := Label.new()
		title.text = Customization.get_layer_title(layer)
		title.add_theme_font_size_override(&"font_size", 30)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var selection_label := Label.new()
		selection_label.add_theme_color_override(&"font_color", Color(0.7, 0.75, 0.82))
		selection_label.add_theme_font_size_override(&"font_size", 24)
		header.add_child(selection_label)
		_selection_labels[layer] = selection_label
		_groups_box.add_child(header)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override(&"h_separation", 8)
		flow.add_theme_constant_override(&"v_separation", 8)
		var button_group := ButtonGroup.new()
		var buttons: Dictionary = {}
		for option: CustomizationOption in Customization.get_options(layer):
			var swatch := _create_swatch(option, button_group)
			swatch.pressed.connect(_on_swatch_pressed.bind(layer, option.id))
			flow.add_child(swatch)
			buttons[option.id] = swatch
		_swatches[layer] = buttons
		_groups_box.add_child(flow)


func _create_swatch(option: CustomizationOption, button_group: ButtonGroup) -> Button:
	var swatch := Button.new()
	swatch.toggle_mode = true
	swatch.button_group = button_group
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.tooltip_text = option.display_name
	swatch.add_theme_stylebox_override(&"normal", _make_swatch_style(option.color, IDLE_BORDER_COLOR, 3))
	swatch.add_theme_stylebox_override(&"hover", _make_swatch_style(option.color, Color(0.8, 0.85, 0.9), 3))
	swatch.add_theme_stylebox_override(&"pressed", _make_swatch_style(option.color, SELECTED_BORDER_COLOR, 6))
	swatch.add_theme_stylebox_override(&"hover_pressed", _make_swatch_style(option.color, SELECTED_BORDER_COLOR, 6))
	return swatch


func _make_swatch_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(SWATCH_RADIUS)
	return style


func _on_swatch_pressed(layer: StringName, option_id: StringName) -> void:
	GameState.set_color(layer, option_id)


func _on_color_changed(layer: StringName, option_id: StringName) -> void:
	_show_selection(layer, option_id)


func _show_selection(layer: StringName, option_id: StringName) -> void:
	# set_pressed_no_signal() no desmarca al resto del ButtonGroup, así que se marca cada muestra.
	var buttons: Dictionary = _swatches.get(layer, {})
	for swatch_id: StringName in buttons:
		(buttons[swatch_id] as Button).set_pressed_no_signal(swatch_id == option_id)
	var option := Customization.find_option(layer, option_id)
	if _selection_labels.has(layer) and option != null:
		_selection_labels[layer].text = option.display_name


func _on_save_pressed() -> void:
	SaveSystem.save_game()
	_close(true)


func _on_cancel_pressed() -> void:
	GameState.apply_colors(_snapshot)
	_close(false)


func _close(saved: bool) -> void:
	hide()
	closed.emit(saved)
