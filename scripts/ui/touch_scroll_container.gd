class_name TouchScrollContainer
extends ScrollContainer
## Lista desplazable para táctil y PC (Tienda, Inventario, pincel...).
## - Celular: se arrastra con el dedo en cualquier parte, también encima de tarjetas y botones.
##   Un arrastre mayor que scroll_deadzone cancela el toque del botón (NOTIFICATION_SCROLL_BEGIN),
##   así que arrastrar nunca compra ni coloca; un toque corto sí activa el botón.
## - PC: rueda del mouse y una barra delgada siempre visible.
## Los hijos (también los que se agregan después) pasan de mouse_filter STOP a PASS para que la
## rueda y los toques lleguen a la lista.

const DEADZONE_PX := 14
const SCROLLBAR_WIDTH := 10
const SCROLLBAR_RADIUS := 5
## Transparencia de la pista y de la barra (los colores vienen del tema).
const SCROLLBAR_TRACK_ALPHA := 0.06
const SCROLLBAR_GRABBER_ALPHA := 0.55
const SCROLLBAR_GRABBER_ACTIVE_ALPHA := 0.9

## Dedo que está arrastrando la lista (-1 = ninguno).
var _touch_index := -1
var _touch_start := Vector2.ZERO
var _scroll_start := 0
var _dragging := false


func _ready() -> void:
	scroll_deadzone = DEADZONE_PX
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_style_scrollbar(get_v_scroll_bar())
	_let_input_through(self)
	get_tree().node_added.connect(_on_node_added)


func is_dragging() -> bool:
	return _dragging


## El arrastre se maneja aquí (antes que la interfaz) para que funcione aunque el toque empiece
## encima de un botón.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var touch := event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and _touch_index < 0 and get_global_rect().has_point(touch.position):
			_touch_index = touch.index
			_touch_start = touch.position
			_scroll_start = scroll_vertical
			_dragging = false
		elif not touch.pressed and touch.index == _touch_index:
			if _dragging:
				propagate_notification(NOTIFICATION_SCROLL_END)
				scroll_ended.emit()
			_touch_index = -1
			_dragging = false
		return
	var drag := event as InputEventScreenDrag
	if drag == null or drag.index != _touch_index:
		return
	var offset := drag.position.y - _touch_start.y
	if not _dragging and absf(offset) > scroll_deadzone:
		_dragging = true
		# Los botones bajo el dedo cancelan su toque: soltar ya no los activa.
		propagate_notification(NOTIFICATION_SCROLL_BEGIN)
		scroll_started.emit()
	if _dragging:
		scroll_vertical = roundi(_scroll_start - offset)
		get_viewport().set_input_as_handled()


## Los eventos de mouse que el celular genera a partir del toque ya se usaron en _input: el arrastre
## nativo del ScrollContainer no los recibe (si no, la lista se movería el doble).
func _gui_input(event: InputEvent) -> void:
	var emulated := event.device == InputEvent.DEVICE_ID_EMULATION
	if emulated and (event is InputEventMouseMotion or (event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)):
		accept_event()


func _on_node_added(node: Node) -> void:
	if is_ancestor_of(node):
		_pass_input(node)


func _let_input_through(node: Node) -> void:
	for child: Node in node.get_children():
		_pass_input(child)
		_let_input_through(child)


func _pass_input(node: Node) -> void:
	var control := node as Control
	if control != null and not control is ScrollBar and control.mouse_filter == Control.MOUSE_FILTER_STOP:
		control.mouse_filter = Control.MOUSE_FILTER_PASS


func _style_scrollbar(bar: ScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(DashboardColors.SCROLL_TRACK, SCROLLBAR_TRACK_ALPHA)
	track.set_corner_radius_all(SCROLLBAR_RADIUS)
	track.content_margin_left = SCROLLBAR_RADIUS
	track.content_margin_right = SCROLLBAR_RADIUS
	bar.add_theme_stylebox_override(&"scroll", track)
	bar.add_theme_stylebox_override(&"scroll_focus", track)
	for state: StringName in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = Color(DashboardColors.HIGHLIGHT, SCROLLBAR_GRABBER_ALPHA if state == &"grabber" else SCROLLBAR_GRABBER_ACTIVE_ALPHA)
		grabber.set_corner_radius_all(SCROLLBAR_RADIUS)
		grabber.content_margin_left = SCROLLBAR_RADIUS
		grabber.content_margin_right = SCROLLBAR_RADIUS
		bar.add_theme_stylebox_override(state, grabber)
	bar.custom_minimum_size.x = SCROLLBAR_WIDTH
