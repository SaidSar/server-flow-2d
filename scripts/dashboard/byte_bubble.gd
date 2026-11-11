class_name ByteBubble
extends PanelContainer
## BYTE, el asistente: su busto (igual que el de Briseida, con expresiones) y un globo de texto que se puede cerrar.
## Los mensajes se encolan; al cerrar uno aparece el siguiente.
## Los pasos del tutorial (say_tutorial) pasan por delante de la cola y avisan al cerrarse.
## Cada mensaje trae una expresión: normal (consejos), contenta, preocupada (cuello de botella) o alerta (ataque DDoS).

## El jugador cerró un mensaje del tutorial.
signal tutorial_dismissed

const MOODS: Array[StringName] = [&"normal", &"contenta", &"preocupada", &"alerta"]
const DEFAULT_MOOD := &"normal"

@onready var _text_label: Label = %TextLabel
@onready var _close_button: Button = %CloseButton
@onready var _avatar: TextureRect = %Avatar
@onready var _name_label: Label = $Row/Text/NameLabel

var _queue: PackedStringArray = []
## Expresión de cada mensaje de _queue (mismo orden).
var _queue_moods: Array[StringName] = []
var _mood: StringName = DEFAULT_MOOD
var _textures: Dictionary = {}
var _showing_tutorial := false
## Con el tutorial de Briseida tapando la pantalla, los mensajes normales esperan en la cola.
var _held := false


func _ready() -> void:
	_avatar.texture = _get_texture(_mood)
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)
	_close_button.pressed.connect(_show_next)
	hide()


func say(text: String, mood: StringName = DEFAULT_MOOD) -> void:
	if text.is_empty() or _queue.has(text) or (visible and _text_label.text == text):
		return
	if _held:
		return  # Briseida está hablando: un consejo que llegue ahora estaría desactualizado al terminar.
	if visible:
		_queue.append(text)
		_queue_moods.append(mood)
	else:
		_display(text, mood)


## Mientras se retiene, los mensajes normales se descartan (y los pendientes se borran); los del tutorial no.
func set_held(held: bool) -> void:
	_held = held
	if held:
		_queue.clear()
		_queue_moods.clear()
	if not held and not visible and not _queue.is_empty():
		_show_next()


## Mensaje del tutorial: aparece de inmediato (el que se estaba mostrando espera su turno).
func say_tutorial(text: String, mood: StringName = DEFAULT_MOOD) -> void:
	_showing_tutorial = true
	_display(text, mood)


func is_showing_tutorial() -> bool:
	return _showing_tutorial and visible


func clear() -> void:
	_queue.clear()
	_queue_moods.clear()
	hide()


func get_text() -> String:
	return _text_label.text if visible else ""


## Expresión con la que BYTE está hablando (la última que mostró).
func get_mood() -> StringName:
	return _mood


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
	var next_mood := _queue_moods[0] if not _queue_moods.is_empty() else DEFAULT_MOOD
	_queue.remove_at(0)
	if not _queue_moods.is_empty():
		_queue_moods.remove_at(0)
	_display(next, next_mood)


func _display(text: String, mood: StringName = DEFAULT_MOOD) -> void:
	_text_label.text = text
	_mood = mood if mood in MOODS else DEFAULT_MOOD
	_avatar.texture = _get_texture(_mood)
	_apply_theme()
	show()


func _get_texture(mood: StringName) -> Texture2D:
	if not _textures.has(mood):
		_textures[mood] = load(Paths.BYTE_BUST % mood)
	return _textures[mood]


func _apply_theme() -> void:
	var alert := _mood == &"alerta"
	var accent := DashboardColors.DANGER if alert else DashboardColors.ACCENT
	add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.CARD, accent, 2, 16, 14.0))
	_name_label.add_theme_color_override(&"font_color", accent)
