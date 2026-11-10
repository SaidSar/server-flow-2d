class_name ShopPanel
extends CanvasLayer
## Panel lateral de la tienda de decoración, con dos pestañas:
## - Tienda: miniatura, nombre, precio, tamaño en celdas, "tienes n" y "Comprar".
## - Inventario: lo guardado, con "Colocar".
## - Mascotas: gato y perro, con precio, "Comprar" y "Vender" (devuelve la mitad; abre una ventana "¿Vender? Sí / No"; tocar fuera de ella la cierra sin vender).
## Solo emite lo que pidió el jugador; DecorPlacer compra, coloca y guarda.

signal opened
signal closed
signal buy_requested(decor_id: StringName)
signal place_requested(decor_id: StringName)
signal pet_buy_requested(pet_id: StringName)
signal pet_sell_requested(pet_id: StringName)

enum Tab { SHOP, INVENTORY, PETS }

const THUMB_SIZE := Vector2(104, 104)
## Tamaño de letra de los botones Comprar/Vender de las mascotas.
const PET_BUTTON_FONT := 24
## Ancho máximo del panel: 560 px o el 30 % del ancho de la pantalla, lo que sea menor.
const MAX_WIDTH_RATIO := 0.3

@onready var _panel: PanelContainer = %Panel
@onready var _coins_label: Label = %CoinsLabel
@onready var _shop_tab: Button = %ShopTab
@onready var _inventory_tab: Button = %InventoryTab
@onready var _pets_tab: Button = %PetsTab
@onready var _rows_box: VBoxContainer = %RowsBox
@onready var _close_button: Button = %CloseButton

var _tab: Tab = Tab.SHOP
## id → botón de la fila visible (Comprar o Colocar), para las pruebas.
var _row_buttons: Dictionary[StringName, Button] = {}
var _refresh_queued := false
## Ventana "¿Vender?" abierta (null si no hay) y sus botones, para las pruebas.
var _sale_dialog: Control
var _sale_yes_button: Button
var _sale_no_button: Button


func _ready() -> void:
	hide()
	_fit_safe_area()
	SceneRouter.safe_area_changed.connect(_fit_safe_area)
	get_viewport().size_changed.connect(_fit_safe_area)
	var tabs := ButtonGroup.new()
	_shop_tab.button_group = tabs
	_inventory_tab.button_group = tabs
	_pets_tab.button_group = tabs
	_shop_tab.pressed.connect(show_tab.bind(Tab.SHOP))
	_inventory_tab.pressed.connect(show_tab.bind(Tab.INVENTORY))
	_pets_tab.pressed.connect(show_tab.bind(Tab.PETS))
	_close_button.pressed.connect(close)
	GameState.decor_changed.connect(_queue_refresh)
	GameState.pets_changed.connect(_queue_refresh)
	Simulation.infrastructure_changed.connect(_queue_refresh)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if _sale_dialog != null:
			_close_sale_dialog()
		else:
			close()
		get_viewport().set_input_as_handled()


func _fit_safe_area() -> void:
	var insets := SafeArea.get_insets(get_viewport())
	_panel.offset_right = -insets.z
	_panel.offset_left = -get_panel_width() - insets.z


## Los textos de las filas se ajustan en varias líneas para no ensanchar el panel.
func get_panel_width() -> float:
	return minf(CustomizePanel.PANEL_WIDTH, get_viewport().get_visible_rect().size.x * MAX_WIDTH_RATIO)


func open(tab: Tab = Tab.SHOP) -> void:
	var was_visible := visible
	show()
	show_tab(tab)
	if not was_visible:
		opened.emit()


func close() -> void:
	if not visible:
		return
	_close_sale_dialog()
	hide()
	closed.emit()


func show_tab(tab: Tab) -> void:
	_close_sale_dialog()
	_tab = tab
	_shop_tab.set_pressed_no_signal(tab == Tab.SHOP)
	_inventory_tab.set_pressed_no_signal(tab == Tab.INVENTORY)
	_pets_tab.set_pressed_no_signal(tab == Tab.PETS)
	_refresh()


func get_row_button(decor_id: StringName) -> Button:
	return _row_buttons.get(decor_id)


## Las filas se reconstruyen al final del cuadro: comprar ocurre dentro de la señal del botón y
## borrarlo ahí mismo lo sacaría del árbol mientras todavía atiende el toque.
func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_node_ready() or not visible:
		return
	_coins_label.text = "%s monedas" % NumberFormat.thousands(Simulation.coins)
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_row_buttons.clear()
	if _tab == Tab.PETS:
		for pet: PetData in PetData.load_catalog():
			_rows_box.add_child(_pet_row(pet))
	elif _tab == Tab.SHOP:
		for decor: DecorData in DecorData.load_catalog():
			if decor.in_shop:
				_rows_box.add_child(_shop_row(decor))
	else:
		var shown: Array[StringName] = []
		for decor_id: StringName in GameState.decor_inventory:
			if decor_id in shown:
				continue
			shown.append(decor_id)
			_rows_box.add_child(_inventory_row(DecorData.find(decor_id)))
		if shown.is_empty():
			_rows_box.add_child(_label("Tu inventario está vacío. Lo que guardes de un cuarto aparece aquí.", 24, DashboardColors.TEXT_SOFT))


func _shop_row(decor: DecorData) -> Control:
	var blocked := DecorShop.get_buy_block_reason(decor)
	var price := "Gratis" if decor.price == 0 else "%s monedas" % NumberFormat.thousands(decor.price)
	var cells := decor.orientations[decor.get_default_orientation()].footprint_cells
	var info := "%s · %d×%d celdas · tienes %d" % [price, cells.x, cells.y, GameState.count_owned(decor.id)]
	var button_text := "Reclamar" if decor.is_trophy() else "Comprar"
	var button := _row_button(button_text, not blocked.is_empty())
	button.pressed.connect(buy_requested.emit.bind(decor.id))
	_row_buttons[decor.id] = button
	return _row(decor, info, blocked, button)


func _pet_row(pet: PetData) -> Control:
	var blocked := PetShop.get_buy_block_reason(pet)
	var owned := GameState.count_pets(pet.id)
	var info := "%s monedas · tienes %d" % [NumberFormat.thousands(pet.price), owned]
	var buy_button := _row_button("Comprar", not blocked.is_empty())
	buy_button.pressed.connect(_on_pet_buy_pressed.bind(pet.id))
	_row_buttons[pet.id] = buy_button
	var sell_button := _row_button("Vender +%s" % NumberFormat.thousands(pet.get_sell_price()), owned <= 0)
	sell_button.pressed.connect(_on_pet_sell_pressed.bind(pet.id))
	_row_buttons[StringName("vender_%s" % pet.id)] = sell_button
	# Los dos botones van abajo, a todo lo ancho y del mismo tamaño.
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	for button: Button in [buy_button, sell_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 0.0
		button.clip_text = true
		button.add_theme_font_size_override(&"font_size", PET_BUTTON_FONT)
		buttons.add_child(button)
	return _row_with(pet.display_name, pet.get_frame_texture(PetData.FRAME_IDLE), info, blocked, null, pet.description, buttons)


func _on_pet_buy_pressed(pet_id: StringName) -> void:
	pet_buy_requested.emit(pet_id)


## Vender abre una ventana "¿Vender? Sí / No": la mascota se va para siempre y se devuelve solo una parte del precio.
func _on_pet_sell_pressed(pet_id: StringName) -> void:
	var pet := PetData.find(pet_id)
	if pet == null:
		return
	_close_sale_dialog()
	var overlay := Control.new()
	overlay.name = "SaleDialog"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.name = "Dim"
	# Tocar fuera de la ventana (en lo oscuro) la cierra sin vender.
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_sale_dim_input)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DashboardColors.CARD_ALT
	style.set_corner_radius_all(16)
	style.set_content_margin_all(28)
	style.set_border_width_all(2)
	style.border_color = DashboardColors.TEXT_SOFT
	card.add_theme_stylebox_override(&"panel", style)
	card.custom_minimum_size.x = minf(get_panel_width(), 520.0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 16)
	card.add_child(box)
	var title := _label("¿Vender %s?" % pet.display_name.to_lower(), 32, DashboardColors.TEXT_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var detail := _label("Se va de la empresa y recibes %s monedas." % NumberFormat.thousands(pet.get_sell_price()), 24, DashboardColors.TEXT_SOFT)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(detail)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 12)
	box.add_child(buttons)
	_sale_no_button = _row_button("No", false)
	_sale_yes_button = _row_button("Sí, vender", false)
	for button: Button in [_sale_no_button, _sale_yes_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 0.0
		buttons.add_child(button)
	_sale_no_button.pressed.connect(_close_sale_dialog)
	_sale_yes_button.pressed.connect(_confirm_sale.bind(pet_id))
	add_child(overlay)
	_sale_dialog = overlay


func _on_sale_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_sale_dialog()


func _confirm_sale(pet_id: StringName) -> void:
	_close_sale_dialog()
	pet_sell_requested.emit(pet_id)
	_queue_refresh()


func _close_sale_dialog() -> void:
	if _sale_dialog != null:
		_sale_dialog.queue_free()
		_sale_dialog.hide()
		_sale_dialog = null
		_sale_yes_button = null
		_sale_no_button = null


## Botones de la ventana "¿Vender?" (&"si" o &"no"); null si no hay ventana abierta. Para las pruebas.
func get_sale_dialog_button(which: StringName) -> Button:
	return _sale_yes_button if which == &"si" else _sale_no_button


func _inventory_row(decor: DecorData) -> Control:
	var info := "En inventario: %d" % GameState.count_in_inventory(decor.id)
	var button := _row_button("Colocar", false)
	button.pressed.connect(place_requested.emit.bind(decor.id))
	_row_buttons[decor.id] = button
	return _row(decor, info, "", button)


func _row(decor: DecorData, info: String, blocked: String, button: Button) -> Control:
	return _row_with(decor.display_name, decor.orientations[decor.get_default_orientation()].load_texture(), info, blocked, button)


## `button` va a la derecha de la fila; `footer` (opcional) va debajo, a todo lo ancho.
func _row_with(title: String, picture: Texture2D, info: String, blocked: String, button: Control, extra: String = "", footer: Control = null) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = DashboardColors.CARD_ALT
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	row.add_theme_stylebox_override(&"panel", style)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override(&"separation", 10)
	row.add_child(rows)
	var box := HBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	rows.add_child(box)

	var thumb := TextureRect.new()
	thumb.texture = picture
	thumb.custom_minimum_size = THUMB_SIZE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(thumb)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_child(_label(title, 28, DashboardColors.TEXT_TITLE))
	texts.add_child(_label(info, 22, DashboardColors.TEXT_SOFT))
	if not extra.is_empty():
		texts.add_child(_label(extra, 20, DashboardColors.TEXT_MUTED))
	if not blocked.is_empty():
		texts.add_child(_label(blocked, 22, DashboardColors.BLOCKED))
	box.add_child(texts)
	if button != null:
		box.add_child(button)
	if footer != null:
		rows.add_child(footer)
	return row


func _row_button(text: String, disabled: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.disabled = disabled
	button.custom_minimum_size = Vector2(150, 72)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
