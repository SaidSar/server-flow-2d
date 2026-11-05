class_name UpgradeButton
extends Button
## Botón de la consola para una UpgradeData: nombre, efecto, nivel y costo.
## Bloqueado muestra candado y "Etapa n"; se resalta en rojo si arregla el cuello de botella.
## La ficha de la mejora se abre al mantenerlo presionado, con el botón "i" o como tooltip en PC.

signal purchase_requested(upgrade_id: StringName)
## Mantener presionado o tocar la "i": mostrar la ficha de la mejora.
signal info_requested(upgrade_id: StringName)

const INFO_CARD_SCENE := preload("res://scenes/dashboard/upgrade_info_card.tscn")
const HEIGHT := 128.0
const LONG_PRESS_SECONDS := 0.4

@onready var _name_label: Label = %NameLabel
@onready var _effect_label: Label = %EffectLabel
@onready var _level_label: Label = %LevelLabel
@onready var _cost_label: Label = %CostLabel
@onready var _lock_box: Control = %LockBox
@onready var _lock_label: Label = %LockLabel
@onready var _info_box: Control = %InfoBox
@onready var _info_button: Button = %InfoButton

var upgrade: UpgradeData
var _is_highlighted := false
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _pressed_style: StyleBoxFlat
var _disabled_style: StyleBoxFlat
var _highlight_style: StyleBoxFlat
var _long_press_timer := Timer.new()
## La pulsación actual ya abrió la ficha: al soltar no se compra.
var _long_pressed := false


func _ready() -> void:
	custom_minimum_size.y = HEIGHT
	focus_mode = Control.FOCUS_ALL
	_build_styles()
	_apply_styles()
	UiTheme.changed.connect(_apply_theme)
	_long_press_timer.one_shot = true
	_long_press_timer.wait_time = LONG_PRESS_SECONDS
	_long_press_timer.timeout.connect(_on_long_press)
	add_child(_long_press_timer)
	_style_info_button()
	pressed.connect(_on_pressed)
	# gui_input llega aunque el botón esté deshabilitado: así también se ve la ficha de una mejora bloqueada.
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(_long_press_timer.stop)
	_info_button.pressed.connect(_request_info)


func setup(data: UpgradeData) -> void:
	upgrade = data
	name = "Upgrade_%s" % data.id
	_name_label.text = data.display_name
	_effect_label.text = data.short_effect
	# El contenido real del tooltip lo arma _make_custom_tooltip; el texto solo lo activa.
	tooltip_text = data.display_name
	refresh()


## Lee el estado de la simulación (nivel, monedas, desbloqueo, recarga).
func refresh() -> void:
	if upgrade == null:
		return
	var unlocked := Simulation.is_unlocked(upgrade)
	var level := Simulation.get_level(upgrade.id)
	_lock_box.visible = not unlocked
	_info_box.visible = unlocked
	_lock_label.text = "Etapa %d" % upgrade.unlock_stage
	if upgrade.target == &"backup":
		_level_label.text = "Recarga %d s" % ceili(Simulation.backup_cooldown) if Simulation.backup_cooldown > 0.0 else "Listo"
	elif upgrade.target == &"firewall":
		_level_label.text = "Instalado" if level > 0 else "No instalado"
	else:
		_level_label.text = "Nv %d/%d" % [level, upgrade.max_level]
	if upgrade.is_maxed(level):
		_cost_label.text = "MÁX"
	else:
		_cost_label.text = "%d monedas" % Simulation.get_cost(upgrade)
	var affordable := Simulation.coins >= Simulation.get_cost(upgrade)
	_cost_label.add_theme_color_override(&"font_color", DashboardColors.WARNING if affordable or upgrade.is_maxed(level) else DashboardColors.TEXT_MUTED)
	disabled = not Simulation.can_purchase(upgrade)


func set_highlighted(value: bool) -> void:
	if value == _is_highlighted:
		return
	_is_highlighted = value
	_apply_styles()


func is_highlighted() -> bool:
	return _is_highlighted


## Tooltip (PC): la misma ficha que se abre en táctil.
func _make_custom_tooltip(_for_text: String) -> Object:
	var card := INFO_CARD_SCENE.instantiate() as UpgradeInfoCard
	card.setup(upgrade)
	return card


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if click.pressed:
		_long_pressed = false
		_long_press_timer.start()
	else:
		_long_press_timer.stop()


func _on_long_press() -> void:
	_long_pressed = true
	_request_info()


func _request_info() -> void:
	info_requested.emit(upgrade.id)


## La "i": un círculo pequeño dentro de un área táctil de 64 × 64.
func _style_info_button() -> void:
	var circle := StyleBoxFlat.new()
	circle.bg_color = Color(DashboardColors.ACCENT, 0.18)
	circle.border_color = DashboardColors.ACCENT
	circle.set_border_width_all(2)
	circle.set_corner_radius_all(999)
	circle.set_expand_margin_all(-14.0)
	var hover := circle.duplicate() as StyleBoxFlat
	hover.bg_color = Color(DashboardColors.ACCENT, 0.4)
	_info_button.add_theme_stylebox_override(&"normal", circle)
	_info_button.add_theme_stylebox_override(&"hover", hover)
	_info_button.add_theme_stylebox_override(&"pressed", hover)
	_info_button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())


func _build_styles() -> void:
	_normal_style = DashboardColors.panel_style(DashboardColors.CARD, DashboardColors.PANEL_BORDER, 2, 12, 10.0)
	_hover_style = DashboardColors.panel_style(DashboardColors.BUTTON_HOVER, DashboardColors.ACCENT, 2, 12, 10.0)
	_pressed_style = DashboardColors.panel_style(DashboardColors.BUTTON_PRESSED, DashboardColors.ACCENT, 3, 12, 10.0)
	_disabled_style = DashboardColors.panel_style(DashboardColors.BUTTON_DISABLED, DashboardColors.BUTTON_DISABLED_BORDER, 2, 12, 10.0)
	_highlight_style = DashboardColors.panel_style(DashboardColors.BUTTON_ALERT, DashboardColors.DANGER, 4, 12, 10.0)


func _apply_theme() -> void:
	_build_styles()
	_apply_styles()
	_style_info_button()
	refresh()


func _apply_styles() -> void:
	var base := _highlight_style if _is_highlighted else _normal_style
	add_theme_stylebox_override(&"normal", base)
	add_theme_stylebox_override(&"hover", _highlight_style if _is_highlighted else _hover_style)
	add_theme_stylebox_override(&"pressed", _pressed_style)
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	add_theme_stylebox_override(&"disabled", _highlight_style if _is_highlighted else _disabled_style)


func _on_pressed() -> void:
	if _long_pressed:
		_long_pressed = false
		return
	purchase_requested.emit(upgrade.id)
