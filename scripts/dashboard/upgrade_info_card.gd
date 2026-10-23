class_name UpgradeInfoCard
extends PanelContainer
## Ficha de una mejora: nombre, efecto por nivel, nivel actual, costo y qué concepto enseña.
## Se usa como tooltip (PC) y dentro de UpgradeInfoPanel (táctil: mantener presionado o botón "i").

const WIDTH := 520.0

@onready var _name_label: Label = %NameLabel
@onready var _effect_label: Label = %EffectLabel
@onready var _level_label: Label = %LevelLabel
@onready var _cost_label: Label = %CostLabel
@onready var _concept_label: Label = %ConceptLabel
@onready var _description_label: Label = %DescriptionLabel

var _upgrade: UpgradeData


func _ready() -> void:
	add_theme_stylebox_override(&"panel", DashboardColors.panel_style(Color("#16233a"), DashboardColors.ACCENT, 2, 14, 20.0))
	custom_minimum_size.x = WIDTH
	if _upgrade != null:
		_apply(_upgrade)


## Se puede llamar antes de que la ficha entre al árbol (el tooltip la crea así).
func setup(upgrade: UpgradeData) -> void:
	_upgrade = upgrade
	if is_node_ready():
		_apply(upgrade)


func _apply(upgrade: UpgradeData) -> void:
	_name_label.text = upgrade.display_name
	_effect_label.text = "Efecto: %s" % describe_effect(upgrade)
	var level := Simulation.get_level(upgrade.id)
	if not Simulation.is_unlocked(upgrade):
		_level_label.text = "Bloqueada: se desbloquea en la etapa %d" % upgrade.unlock_stage
	elif upgrade.is_action():
		_level_label.text = "Acción: se puede usar las veces que quieras"
	else:
		_level_label.text = "Nivel actual: %d de %d" % [level, upgrade.max_level]
	if upgrade.is_maxed(level):
		_cost_label.text = "Costo: nivel máximo"
	else:
		_cost_label.text = "Costo: %s monedas" % NumberFormat.thousands(Simulation.get_cost(upgrade))
	_concept_label.text = upgrade.concept
	_description_label.text = upgrade.description


## "+50 % concurrencia por nivel", "Libera 40 % del disco"...
static func describe_effect(upgrade: UpgradeData) -> String:
	if upgrade.is_action() or upgrade.max_level <= 1:
		return upgrade.short_effect
	return "%s por nivel" % upgrade.short_effect
