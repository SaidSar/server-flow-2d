class_name NamePrompt
extends PanelContainer
## Ventana reutilizable para pedir un nombre corto (avatar, empresa...).
## Solo acepta letras, números, espacios, punto, guion y guion bajo.

signal confirmed(value: String)
signal back_requested

const MAX_LENGTH := 16
const INVALID_CHARS_PATTERN := "[^A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ ._\\-]"

## Paso del flujo ("Paso 2 de 3"), arriba a la izquierda. Vacío = sin etiqueta.
@export var step_text := ""
@export var title_text := "¿Cómo te llamas?"
@export var placeholder_text := "Alex"
@export var confirm_text := "Siguiente"
## Texto del botón para regresar. Vacío = sin botón.
@export var back_text := ""

@onready var _step_label: Label = %StepLabel
@onready var _title_label: Label = %TitleLabel
@onready var _name_edit: LineEdit = %NameEdit
@onready var _confirm_button: Button = %ConfirmButton
@onready var _back_button: Button = %BackButton

var _invalid_chars := RegEx.new()


func _ready() -> void:
	_invalid_chars.compile(INVALID_CHARS_PATTERN)
	_step_label.text = step_text
	_step_label.visible = not step_text.is_empty()
	_title_label.text = title_text
	_name_edit.placeholder_text = placeholder_text
	_name_edit.max_length = MAX_LENGTH
	_confirm_button.text = confirm_text
	_back_button.text = back_text
	_back_button.visible = not back_text.is_empty()

	_name_edit.text_changed.connect(_on_text_changed)
	_name_edit.text_submitted.connect(_on_text_submitted)
	_confirm_button.pressed.connect(_confirm)
	_back_button.pressed.connect(_on_back_pressed)
	_update_confirm_state()
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


## Texto escrito, sin espacios al inicio ni al final.
func get_value() -> String:
	return _name_edit.text.strip_edges()


## Texto de ejemplo del campo (p. ej. el nombre del personaje elegido).
func set_placeholder(text: String) -> void:
	placeholder_text = text
	if is_node_ready():
		_name_edit.placeholder_text = text


func is_value_valid() -> bool:
	return not get_value().is_empty()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		_name_edit.grab_focus.call_deferred()
		_name_edit.caret_column = _name_edit.text.length()


func _on_text_changed(new_text: String) -> void:
	var filtered := _invalid_chars.sub(new_text, "", true)
	if filtered != new_text:
		var caret := _name_edit.caret_column - (new_text.length() - filtered.length())
		_name_edit.text = filtered
		_name_edit.caret_column = maxi(caret, 0)
	_update_confirm_state()


func _on_text_submitted(_submitted_text: String) -> void:
	_confirm()


func _on_back_pressed() -> void:
	back_requested.emit()


func _confirm() -> void:
	if is_value_valid():
		confirmed.emit(get_value())


func _update_confirm_state() -> void:
	_confirm_button.disabled = not is_value_valid()
