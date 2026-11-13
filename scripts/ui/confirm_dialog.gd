class_name ConfirmDialog
extends Control
## Ventana de aviso o confirmación sobre un fondo oscuro: título, detalle y 1 o 2 botones.
## `chosen` emite el id del botón tocado; tocar fuera de la ventana o Esc emite &"cancel".
## El botón con `default_index` toma el foco (en las confirmaciones destructivas, el que NO destruye).

signal chosen(id: StringName)

var _buttons: Dictionary[StringName, Button] = {}


## `options`: Array de {id: StringName, text: String, danger: bool (opcional)}. Devuelve la ventana ya armada
## (el que la llama la agrega a su escena).
static func create(title_text: String, detail_text: String, options: Array[Dictionary], default_index: int = 0) -> ConfirmDialog:
	var dialog := ConfirmDialog.new()
	dialog.name = "ConfirmDialog"
	dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	dialog.z_index = 20
	dialog._build(title_text, detail_text, options, default_index)
	return dialog


func get_button(id: StringName) -> Button:
	return _buttons.get(id)


func _build(title_text: String, detail_text: String, options: Array[Dictionary], default_index: int) -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.CARD_ALT, DashboardColors.TEXT_SOFT, 2, 16, 28.0))
	card.custom_minimum_size.x = 620.0
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	card.add_child(box)
	box.add_child(_label(title_text, 34, DashboardColors.TEXT_TITLE))
	box.add_child(_label(detail_text, 26, DashboardColors.TEXT_SOFT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	box.add_child(row)
	var index := 0
	for option: Dictionary in options:
		var button := Button.new()
		button.text = str(option.get("text", ""))
		button.custom_minimum_size = Vector2(0.0, 72.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override(&"font_size", 28)
		if option.get("danger", false):
			button.add_theme_color_override(&"font_color", DashboardColors.DANGER)
		var id := StringName(str(option.get("id", "")))
		button.pressed.connect(_choose.bind(id))
		row.add_child(button)
		_buttons[id] = button
		if index == default_index:
			button.call_deferred(&"grab_focus")
		index += 1


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	return label


func _choose(id: StringName) -> void:
	chosen.emit(id)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chosen.emit(&"cancel")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		chosen.emit(&"cancel")
