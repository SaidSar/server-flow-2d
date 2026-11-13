class_name SavesPanel
extends Control
## Pantalla "Partidas" del menú de título: hasta SaveSystem.MAX_SLOTS partidas con empresa, etapa, oleada
## y monedas. Cada una se carga o se borra (el borrado siempre pregunta, con "No" como botón por defecto).
## No cambia de escena: avisa con `load_requested` y el menú de título hace el resto.

signal closed
signal load_requested(slot: int)
## Cambió el número de partidas (se borró una): el menú actualiza Continuar y el contador.
signal saves_changed

const WIDTH := 1120.0

var _list: VBoxContainer
var _count_label: Label
var _hint_label: Label
var _close_button: Button
var _dialog: ConfirmDialog
var _load_buttons: Dictionary[int, Button] = {}
var _delete_buttons: Dictionary[int, Button] = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 10
	_build()
	hide()


func open() -> void:
	_refresh()
	show()
	_close_button.grab_focus()


func close() -> void:
	_close_dialog()
	hide()
	closed.emit()


func is_confirming_delete() -> bool:
	return _dialog != null


func get_load_button(slot: int) -> Button:
	return _load_buttons.get(slot)


func get_delete_button(slot: int) -> Button:
	return _delete_buttons.get(slot)


func get_dialog() -> ConfirmDialog:
	return _dialog


## Esc o "atrás" de Android: cierra la pregunta de borrar o, si no hay, la pantalla.
func go_back() -> void:
	if _dialog != null:
		_close_dialog()
	elif visible:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _dialog == null and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var window := PanelContainer.new()
	window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.CARD_ALT, DashboardColors.ACCENT, 2, 18, 28.0))
	window.custom_minimum_size.x = WIDTH
	center.add_child(window)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	window.add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "Partidas"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override(&"font_size", 44)
	title.add_theme_color_override(&"font_color", DashboardColors.TEXT_TITLE)
	header.add_child(title)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override(&"font_size", 28)
	_count_label.add_theme_color_override(&"font_color", DashboardColors.TEXT_SOFT)
	header.add_child(_count_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 10)
	box.add_child(_list)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override(&"separation", 20)
	box.add_child(footer)
	_hint_label = Label.new()
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override(&"font_size", 24)
	_hint_label.add_theme_color_override(&"font_color", DashboardColors.TEXT_MUTED)
	footer.add_child(_hint_label)
	_close_button = Button.new()
	_close_button.text = "Cerrar"
	_close_button.custom_minimum_size = Vector2(240.0, 68.0)
	_close_button.add_theme_font_size_override(&"font_size", 28)
	_close_button.pressed.connect(close)
	footer.add_child(_close_button)


func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
		_list.remove_child(child)
	_load_buttons.clear()
	_delete_buttons.clear()
	var slots := SaveSystem.get_slots()
	_count_label.text = "%d de %d" % [slots.size(), SaveSystem.MAX_SLOTS]
	for info: Dictionary in slots:
		_list.add_child(_make_row(info))
	for i in range(slots.size(), SaveSystem.MAX_SLOTS):
		_list.add_child(_make_empty_row())
	if slots.is_empty():
		_hint_label.text = "Todavía no tienes partidas: crea una con Nueva partida."
	elif slots.size() >= SaveSystem.MAX_SLOTS:
		_hint_label.text = "Llegaste al límite: borra una para crear otra."
	else:
		_hint_label.text = "Toca Cargar para continuar esa partida."


func _make_row(info: Dictionary) -> Control:
	var slot: int = info["slot"]
	var panel := PanelContainer.new()
	panel.name = "Slot%d" % slot
	var border := DashboardColors.ACCENT if info["is_last"] else DashboardColors.CARD_BORDER
	panel.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.CARD, border, 2 if info["is_last"] else 1, 12, 14.0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	panel.add_child(row)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 2)
	row.add_child(texts)
	var name_text := String(info["company"])
	if name_text.is_empty():
		name_text = "Partida %d" % slot
	if info["is_last"]:
		name_text += "   ·  Última"
	texts.add_child(_label(name_text, 32, DashboardColors.TEXT_TITLE))
	texts.add_child(_label(_describe(info), 22, DashboardColors.TEXT_MUTED))
	var load_button := _row_button("Cargar")
	load_button.pressed.connect(_on_load_pressed.bind(slot))
	row.add_child(load_button)
	_load_buttons[slot] = load_button
	var delete_button := _row_button("Borrar")
	delete_button.add_theme_color_override(&"font_color", DashboardColors.DANGER)
	delete_button.pressed.connect(_on_delete_pressed.bind(slot, name_text.split("   ·")[0]))
	row.add_child(delete_button)
	_delete_buttons[slot] = delete_button
	return panel


func _make_empty_row() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(Color(0, 0, 0, 0), DashboardColors.CARD_BORDER, 1, 12, 14.0))
	panel.custom_minimum_size.y = 74.0
	var label := _label("Espacio libre", 24, DashboardColors.TEXT_HINT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel


## "Etapa 2 · Scale-up · Oleada 4/5 · 8,410 monedas"
func _describe(info: Dictionary) -> String:
	var stage := Simulation.load_stage(StringName(info["stage"]))
	return "Etapa %d · %s · Oleada %d/%d · %s monedas" % [stage.number, stage.display_name, mini(info["wave"], stage.get_wave_count()), stage.get_wave_count(), NumberFormat.thousands(info["coins"])]


func _row_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180.0, 64.0)
	button.add_theme_font_size_override(&"font_size", 26)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.clip_text = true
	return label


func _on_load_pressed(slot: int) -> void:
	if _dialog == null:
		load_requested.emit(slot)


func _on_delete_pressed(slot: int, company: String) -> void:
	if _dialog != null:
		return
	var options: Array[Dictionary] = [{"id": &"no", "text": "No"}, {"id": &"si", "text": "Sí, borrar", "danger": true}]
	_dialog = ConfirmDialog.create("¿Borrar «%s»?" % company, "Se perderá su progreso y no se puede deshacer.", options, 0)
	_dialog.chosen.connect(_on_delete_chosen.bind(slot))
	add_child(_dialog)


func _on_delete_chosen(id: StringName, slot: int) -> void:
	_close_dialog()
	if id == &"si":
		SaveSystem.delete_slot(slot)
		_refresh()
		saves_changed.emit()
	if _close_button != null:
		_close_button.grab_focus()


func _close_dialog() -> void:
	if _dialog != null:
		_dialog.queue_free()
		remove_child(_dialog)
		_dialog = null
