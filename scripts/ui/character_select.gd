class_name CharacterSelect
extends PanelContainer
## Paso 1 de la partida nueva: elegir personaje. Hay una tarjeta por cada AvatarData de
## resources/avatars/; la seleccionada lleva borde y brillo de su color y una palomita.

signal confirmed(avatar_id: StringName)
signal back_requested

const CARD_SIZE := Vector2(380, 600)
const CARD_RADIUS := 20
const CARD_BG := Color("#1b2232")
const CARD_BORDER := Color("#3a4458")
const CARD_BORDER_HOVER := Color("#5f6b85")
const SELECTED_BORDER_WIDTH := 5
const GLOW_SIZE := 22
const CHECK_SIZE := 60.0
const CHECK_ICON := preload("res://assets/art/ui/icon_check.svg")

@onready var _cards_box: HBoxContainer = %Cards
@onready var _back_button: Button = %BackButton
@onready var _next_button: Button = %NextButton

var _cards: Dictionary[StringName, Button] = {}
var _checks: Dictionary[StringName, Control] = {}
var _group := ButtonGroup.new()
var _selected_id: StringName = AvatarData.DEFAULT_ID


func _ready() -> void:
	for avatar: AvatarData in AvatarData.load_all():
		_add_card(avatar)
	_back_button.pressed.connect(back_requested.emit)
	_next_button.pressed.connect(_on_next_pressed)
	visibility_changed.connect(_on_visibility_changed)
	select(_selected_id)


func get_selected_id() -> StringName:
	return _selected_id


func get_card(avatar_id: StringName) -> Button:
	return _cards.get(avatar_id)


func select(avatar_id: StringName) -> void:
	if _cards.has(avatar_id):
		_cards[avatar_id].button_pressed = true


func _add_card(avatar: AvatarData) -> void:
	var card := Button.new()
	card.name = "Card_%s" % avatar.id
	card.toggle_mode = true
	card.button_group = _group
	card.custom_minimum_size = CARD_SIZE
	card.tooltip_text = avatar.display_name
	var idle := _card_style(CARD_BORDER, 2, Color.TRANSPARENT)
	var hover := _card_style(CARD_BORDER_HOVER, 2, Color.TRANSPARENT)
	var selected := _card_style(avatar.color, SELECTED_BORDER_WIDTH, Color(avatar.color, 0.55))
	card.add_theme_stylebox_override(&"normal", idle)
	card.add_theme_stylebox_override(&"hover", hover)
	card.add_theme_stylebox_override(&"pressed", selected)
	card.add_theme_stylebox_override(&"hover_pressed", selected)
	card.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	card.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 8)
	margin.add_child(content)

	var portrait := TextureRect.new()
	portrait.texture = load(avatar.select) as Texture2D
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(portrait)
	content.add_child(_card_label(avatar.display_name, 40, Color.WHITE))
	content.add_child(_card_label(avatar.description, 24, Color(0.6, 0.65, 0.72)))

	var check := _check_badge(avatar.color)
	card.add_child(check)
	_checks[avatar.id] = check

	card.toggled.connect(_on_card_toggled.bind(avatar.id))
	_cards_box.add_child(card)
	_cards[avatar.id] = card


func _card_style(border: Color, border_width: int, glow: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(CARD_RADIUS)
	style.shadow_color = glow
	style.shadow_size = GLOW_SIZE if glow.a > 0.0 else 0
	return style


func _card_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Círculo del color del personaje con la palomita, en la esquina superior derecha de la tarjeta.
func _check_badge(color: Color) -> Control:
	var badge := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(CHECK_SIZE))
	badge.add_theme_stylebox_override(&"panel", style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -CHECK_SIZE - 16.0
	badge.offset_top = 16.0
	badge.offset_right = -16.0
	badge.offset_bottom = CHECK_SIZE + 16.0
	var icon := TextureRect.new()
	icon.texture = CHECK_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)
	badge.hide()
	return badge


func _on_card_toggled(pressed: bool, avatar_id: StringName) -> void:
	_checks[avatar_id].visible = pressed
	if pressed:
		_selected_id = avatar_id


func _on_next_pressed() -> void:
	confirmed.emit(_selected_id)


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and _cards.has(_selected_id):
		_cards[_selected_id].grab_focus.call_deferred()
