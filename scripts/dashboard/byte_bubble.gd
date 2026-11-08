class_name ByteBubble
extends PanelContainer
## BYTE, el asistente del tutorial: un globo de texto que se puede cerrar.
## Los mensajes se encolan; al cerrar uno aparece el siguiente.
## Los pasos del tutorial (say_tutorial) pasan por delante de la cola y avisan al cerrarse.

## El jugador cerró un mensaje del tutorial.
signal tutorial_dismissed

@onready var _text_label: Label = %TextLabel
@onready var _close_button: Button = %CloseButton

var _queue: PackedStringArray = []
var _showing_tutorial := false
## Con el tutorial de Briseida tapando la pantalla, los mensajes normales esperan en la cola.
var _held := false


func _ready() -> void:
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)
	_close_button.pressed.connect(_show_next)
	hide()


func say(text: String) -> void:
	if text.is_empty() or _queue.has(text) or (visible and _text_label.text == text):
		return
	if visible or _held:
		_queue.append(text)
	else:
		_display(text)


## Retiene (o libera) los mensajes normales; los del tutorial no se retienen.
func set_held(held: bool) -> void:
	_held = held
	if not held and not visible and not _queue.is_empty():
		_show_next()


## Mensaje del tutorial: aparece de inmediato (el que se estaba mostrando espera su turno).
func say_tutorial(text: String) -> void:
	if visible and not _showing_tutorial and not _text_label.text.is_empty():
		_queue.insert(0, _text_label.text)
	_showing_tutorial = true
	_display(text)


func is_showing_tutorial() -> bool:
	return _showing_tutorial and visible


func clear() -> void:
	_queue.clear()
	hide()


func get_text() -> String:
	return _text_label.text if visible else ""


func _show_next() -> void:
	if _showing_tutorial:
		_showing_tutorial = false
		tutorial_dismissed.emit()
		# El tutorial puede retener la cola al avanzar (su refresco llega un frame después).
		hide()
		_show_queued.call_deferred()
		return
	_show_queued()


func _show_queued() -> void:
	if _showing_tutorial:
		return
	if _queue.is_empty() or _held:
		hide()
		return
	var next := _queue[0]
	_queue.remove_at(0)
	_display(next)


func _display(text: String) -> void:
	_text_label.text = text
	show()


func _apply_theme() -> void:
	add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.CARD, DashboardColors.ACCENT, 2, 16, 14.0))
