class_name DialogBox
extends Control
## Diálogo reutilizable: retrato, hablante, texto y un botón.
## Sin arte, el retrato es un círculo de color con las iniciales del hablante.
## Uso: dialog.show_dialog("Briseida", "CEO", texto, "¡Vamos!", color); await dialog.closed

signal closed

const MAX_INITIALS := 2

@onready var _window: PanelContainer = %Window
@onready var _portrait_circle: Panel = %PortraitCircle
@onready var _initials_label: Label = %InitialsLabel
@onready var _portrait_texture: TextureRect = %PortraitTexture
@onready var _speaker_label: Label = %SpeakerLabel
@onready var _role_label: Label = %RoleLabel
@onready var _text_label: Label = %TextLabel
@onready var _continue_button: Button = %ContinueButton

var _circle_style := StyleBoxFlat.new()


func _ready() -> void:
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)
	_circle_style.set_corner_radius_all(999)
	_portrait_circle.add_theme_stylebox_override(&"panel", _circle_style)
	_continue_button.pressed.connect(_on_continue_pressed)
	hide()


## `portrait` vacío = círculo de color con las iniciales.
## `color` transparente = el acento del tema.
func show_dialog(speaker: String, role: String, text: String, button_text: String, color: Color = Color.TRANSPARENT, portrait: Texture2D = null) -> void:
	if color.a == 0.0:
		color = DashboardColors.ACCENT
	_speaker_label.text = speaker
	_role_label.text = role
	_role_label.visible = not role.is_empty()
	_text_label.text = text
	_continue_button.text = button_text
	_circle_style.bg_color = color
	_initials_label.text = get_initials(speaker)
	_portrait_texture.texture = portrait
	_portrait_texture.visible = portrait != null
	_initials_label.visible = portrait == null
	show()
	_continue_button.grab_focus()


func get_text() -> String:
	return _text_label.text


static func get_initials(speaker: String) -> String:
	var initials := ""
	for word: String in speaker.split(" ", false):
		initials += word.left(1).to_upper()
		if initials.length() >= MAX_INITIALS:
			break
	return initials


func _on_continue_pressed() -> void:
	hide()
	closed.emit()


func _apply_theme() -> void:
	_window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.CARD, DashboardColors.ACCENT, 2, 18, 24.0))
