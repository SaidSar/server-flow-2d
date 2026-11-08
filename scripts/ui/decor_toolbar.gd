class_name DecorToolbar
extends CanvasLayer
## Barra inferior de la decoración. Dos modos:
## - Colocación: "Girar", "Colocar" (solo en pantallas táctiles; en PC se coloca con clic) y "Cancelar".
## - Objeto seleccionado: "Mover", "Girar", "Guardar en inventario", "Vender (50 %)" y "Listo".

signal rotate_pressed
signal confirm_pressed
signal cancel_pressed
signal move_pressed
signal store_pressed
signal sell_pressed
signal done_pressed

const HINT_TOUCH := "Toca el piso para mover el objeto"
const HINT_TOUCH_WALL := "Toca la pared para mover el objeto"
const HINT_POINTER := "Clic para colocar · R para girar · Esc para cancelar"
const HINT_INVALID := "No cabe ahí"

@onready var _bar: PanelContainer = %Bar
@onready var _title_label: Label = %TitleLabel
@onready var _hint_label: Label = %HintLabel
@onready var _placement_row: HBoxContainer = %PlacementRow
@onready var _selection_row: HBoxContainer = %SelectionRow
@onready var _rotate_button: Button = %RotateButton
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelButton
@onready var _move_button: Button = %MoveButton
@onready var _rotate_placed_button: Button = %RotatePlacedButton
@onready var _store_button: Button = %StoreButton
@onready var _sell_button: Button = %SellButton
@onready var _done_button: Button = %DoneButton

var _touch := false
var _on_wall := false


func _ready() -> void:
	hide()
	_rotate_button.pressed.connect(rotate_pressed.emit)
	_confirm_button.pressed.connect(confirm_pressed.emit)
	_cancel_button.pressed.connect(cancel_pressed.emit)
	_move_button.pressed.connect(move_pressed.emit)
	_rotate_placed_button.pressed.connect(rotate_pressed.emit)
	_store_button.pressed.connect(store_pressed.emit)
	_sell_button.pressed.connect(sell_pressed.emit)
	_done_button.pressed.connect(done_pressed.emit)
	SceneRouter.safe_area_changed.connect(_fit_safe_area)
	_fit_safe_area()
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)


func show_placement(title: String, touch: bool, on_wall: bool = false) -> void:
	_touch = touch
	_on_wall = on_wall
	_title_label.text = title
	_placement_row.show()
	_selection_row.hide()
	_confirm_button.visible = touch
	set_valid(true)
	show()


## Colocar solo se habilita si el objeto cabe donde está.
func set_valid(valid: bool) -> void:
	_confirm_button.disabled = not valid
	var hint := (HINT_TOUCH_WALL if _on_wall else HINT_TOUCH) if _touch else HINT_POINTER
	_hint_label.text = hint if valid else HINT_INVALID


## `sell_price` < 0 = no se puede vender (el trofeo).
func show_selection(title: String, can_rotate: bool, sell_price: int) -> void:
	_title_label.text = title
	_hint_label.text = "Objeto seleccionado"
	_placement_row.hide()
	_selection_row.show()
	_rotate_placed_button.disabled = not can_rotate
	_sell_button.visible = sell_price >= 0
	_sell_button.text = "Vender (50 %%): +%s" % NumberFormat.thousands(maxi(sell_price, 0))
	show()


func _fit_safe_area() -> void:
	var insets := SafeArea.get_insets(get_viewport())
	_bar.offset_bottom = -16.0 - insets.w


## Colores que se pintan por código. En el tema claro los botones (fondo casi igual al de la barra) y
## sus íconos (blancos) apenas se distinguían: se les da borde marcado, y a los íconos el color del texto.
func _apply_theme() -> void:
	var buttons: Array[Button] = [_rotate_button, _confirm_button, _cancel_button, _move_button, _rotate_placed_button, _store_button, _sell_button, _done_button]
	var light := UiTheme.is_light()
	for button: Button in buttons:
		for item: StringName in [&"icon_normal_color", &"icon_hover_color", &"icon_pressed_color", &"icon_hover_pressed_color", &"icon_focus_color"]:
			button.add_theme_color_override(item, DashboardColors.TEXT)
		button.add_theme_color_override(&"icon_disabled_color", Color(DashboardColors.TEXT_MUTED, 0.7))
		if light:
			button.add_theme_stylebox_override(&"normal", _button_style(DashboardColors.CARD, DashboardColors.CARD_BORDER_HOVER))
			button.add_theme_stylebox_override(&"hover", _button_style(DashboardColors.BUTTON_HOVER, DashboardColors.ACCENT))
			button.add_theme_stylebox_override(&"pressed", _button_style(DashboardColors.BUTTON_PRESSED, DashboardColors.ACCENT))
			button.add_theme_stylebox_override(&"hover_pressed", _button_style(DashboardColors.BUTTON_PRESSED, DashboardColors.ACCENT))
			button.add_theme_stylebox_override(&"disabled", _button_style(DashboardColors.BUTTON_DISABLED, DashboardColors.BUTTON_DISABLED_BORDER))
		else:
			for style_name: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
				button.remove_theme_stylebox_override(style_name)
	_hint_label.add_theme_color_override(&"font_color", DashboardColors.TEXT_MUTED)


static func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
