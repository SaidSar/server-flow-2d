class_name UpgradeButton
extends Button
## Botón de la consola para una UpgradeData: nombre, efecto, nivel y costo.
## Bloqueado muestra candado y "Etapa n"; se resalta en rojo si arregla el cuello de botella.

signal purchase_requested(upgrade_id: StringName)

const HEIGHT := 128.0
const TOOLTIP_WIDTH := 420.0

@onready var _name_label: Label = %NameLabel
@onready var _effect_label: Label = %EffectLabel
@onready var _level_label: Label = %LevelLabel
@onready var _cost_label: Label = %CostLabel
@onready var _lock_box: Control = %LockBox
@onready var _lock_label: Label = %LockLabel
@onready var _info_box: Control = %InfoBox

var upgrade: UpgradeData
var _is_highlighted := false
var _normal_style := DashboardColors.panel_style(Color("#16233a"), DashboardColors.PANEL_BORDER, 2, 12, 10.0)
var _hover_style := DashboardColors.panel_style(Color("#1c2d4a"), DashboardColors.ACCENT, 2, 12, 10.0)
var _pressed_style := DashboardColors.panel_style(Color("#24395c"), DashboardColors.ACCENT, 3, 12, 10.0)
var _disabled_style := DashboardColors.panel_style(Color("#0f1726"), Color("#1a2638"), 2, 12, 10.0)
var _highlight_style := DashboardColors.panel_style(Color("#2a1620"), DashboardColors.DANGER, 4, 12, 10.0)


func _ready() -> void:
	custom_minimum_size.y = HEIGHT
	focus_mode = Control.FOCUS_ALL
	_apply_styles()
	pressed.connect(_on_pressed)


func setup(data: UpgradeData) -> void:
	upgrade = data
	name = "Upgrade_%s" % data.id
	_name_label.text = data.display_name
	_effect_label.text = data.short_effect
	tooltip_text = "%s\n\n%s" % [data.description, data.concept]
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


## Tooltip con el concepto que enseña la mejora, en un panel con ancho fijo para que el texto se ajuste.
func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(Color("#16233a"), DashboardColors.ACCENT, 2, 10, 14.0))
	var label := Label.new()
	label.text = for_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = TOOLTIP_WIDTH
	label.add_theme_font_size_override(&"font_size", 20)
	label.add_theme_color_override(&"font_color", DashboardColors.TEXT)
	panel.add_child(label)
	return panel


func _apply_styles() -> void:
	var base := _highlight_style if _is_highlighted else _normal_style
	add_theme_stylebox_override(&"normal", base)
	add_theme_stylebox_override(&"hover", _highlight_style if _is_highlighted else _hover_style)
	add_theme_stylebox_override(&"pressed", _pressed_style)
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	add_theme_stylebox_override(&"disabled", _highlight_style if _is_highlighted else _disabled_style)


func _on_pressed() -> void:
	purchase_requested.emit(upgrade.id)
