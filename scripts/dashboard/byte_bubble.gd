class_name ByteBubble
extends PanelContainer
## BYTE, el asistente del tutorial: un globo de texto que se puede cerrar.
## Los mensajes se encolan; al cerrar uno aparece el siguiente.

@onready var _text_label: Label = %TextLabel
@onready var _close_button: Button = %CloseButton

var _queue: PackedStringArray = []


func _ready() -> void:
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)
	_close_button.pressed.connect(_show_next)
	hide()


func say(text: String) -> void:
	if text.is_empty() or _queue.has(text) or (visible and _text_label.text == text):
		return
	if visible:
		_queue.append(text)
	else:
		_display(text)


func clear() -> void:
	_queue.clear()
	hide()


func get_text() -> String:
	return _text_label.text if visible else ""


func _show_next() -> void:
	if _queue.is_empty():
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
