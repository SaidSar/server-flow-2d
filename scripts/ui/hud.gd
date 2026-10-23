class_name Hud
extends CanvasLayer
## HUD: "{empresa} · {cuarto}", monedas, usuarios, barra de SLA y botón de personalizar.

signal customize_requested

const DEFAULT_COMPANY_NAME := "Mi empresa"

@export var show_customize_button := true

@onready var _title_label: Label = %TitleLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _users_label: Label = %UsersLabel
@onready var _sla_label: Label = %SlaLabel
@onready var _sla_bar: ProgressBar = %SlaBar
@onready var _brush_button: Button = %BrushButton


func _ready() -> void:
	_brush_button.visible = show_customize_button
	_brush_button.pressed.connect(_on_brush_pressed)
	GameState.changed.connect(_refresh)
	Simulation.tick.connect(_on_simulation_tick)
	_refresh()


func set_customize_enabled(enabled: bool) -> void:
	_brush_button.disabled = not enabled


func _on_brush_pressed() -> void:
	customize_requested.emit()


func _on_simulation_tick(_tick_index: int) -> void:
	_refresh()


func _refresh() -> void:
	var company := GameState.company_name if not GameState.company_name.is_empty() else DEFAULT_COMPANY_NAME
	_title_label.text = "%s · %s" % [company, GameState.get_stage_data().room_name]
	_coins_label.text = "Monedas: %d" % GameState.coins
	_users_label.text = "Usuarios: %d" % GameState.users
	_sla_label.text = "SLA %.1f %%" % Simulation.sla
	_sla_bar.value = Simulation.sla
