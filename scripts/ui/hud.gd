class_name Hud
extends CanvasLayer
## HUD del cuarto: "{empresa} · {cuarto}", monedas, usuarios, oleada, barra de SLA,
## aviso cuando la PC necesita atención y botón de personalizar.

signal customize_requested

const DEFAULT_COMPANY_NAME := "Mi empresa"

@export var show_customize_button := true

@onready var _title_label: Label = %TitleLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _users_label: Label = %UsersLabel
@onready var _users_bar: ProgressBar = %UsersBar
@onready var _wave_label: Label = %WaveLabel
@onready var _sla_label: Label = %SlaLabel
@onready var _sla_bar: ProgressBar = %SlaBar
@onready var _alert_label: Label = %AlertLabel
@onready var _brush_button: Button = %BrushButton
@onready var _root: Control = $Root

var _users_fill := DashboardColors.bar_style(DashboardColors.ACCENT)


func _ready() -> void:
	_fit_safe_area()
	SceneRouter.safe_area_changed.connect(_fit_safe_area)
	_brush_button.visible = show_customize_button
	_users_bar.add_theme_stylebox_override(&"fill", _users_fill)
	_users_bar.add_theme_stylebox_override(&"background", DashboardColors.bar_style(Color(0.2, 0.22, 0.28)))
	_brush_button.pressed.connect(_on_brush_pressed)
	GameState.changed.connect(_refresh)
	Simulation.tick.connect(_on_simulation_tick)
	Simulation.infrastructure_changed.connect(_refresh)
	Simulation.phase_changed.connect(_on_phase_changed)
	_refresh()


func _process(_delta: float) -> void:
	if _alert_label.visible:
		_alert_label.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.005)


func _fit_safe_area() -> void:
	SafeArea.fit_full_rect(_root)


func set_customize_enabled(enabled: bool) -> void:
	_brush_button.disabled = not enabled


func _on_brush_pressed() -> void:
	customize_requested.emit()


func _on_simulation_tick(_snapshot: SimSnapshot) -> void:
	_refresh()


func _on_phase_changed(_phase: Simulation.Phase) -> void:
	_refresh()


func _refresh() -> void:
	var company := GameState.company_name if not GameState.company_name.is_empty() else DEFAULT_COMPANY_NAME
	_title_label.text = "%s · %s" % [company, SceneRouter.get_current_room_name()]
	_coins_label.text = NumberFormat.thousands(Simulation.coins)
	var goal := Simulation.stage.user_goal if Simulation.stage != null else 0
	_users_label.text = "%s / %s" % [NumberFormat.thousands(Simulation.users_served), NumberFormat.thousands(goal)]
	_users_bar.max_value = maxi(goal, 1)
	_users_bar.value = mini(Simulation.users_served, goal)
	_users_fill.bg_color = DashboardColors.OK if goal > 0 and Simulation.users_served >= goal else DashboardColors.ACCENT
	_wave_label.text = "Oleada %d/%d" % [Simulation.wave_number, Simulation.get_wave_count()]
	_sla_label.text = "SLA %.1f %%" % Simulation.sla
	_sla_bar.value = Simulation.sla
	var alert := _get_alert_text()
	_alert_label.visible = not alert.is_empty()
	_alert_label.text = alert


## Aviso para que el jugador vuelva a la PC; vacío mientras la oleada corre.
func _get_alert_text() -> String:
	match Simulation.phase:
		Simulation.Phase.READY:
			return "La oleada %d te espera en la PC" % Simulation.wave_number
		Simulation.Phase.BETWEEN_WAVES:
			return "Oleada terminada: revisa el post-mortem en la PC"
		Simulation.Phase.GAME_OVER:
			return "¡Los servidores cayeron! Revisa la PC"
		Simulation.Phase.STAGE_FAILED:
			return "No alcanzaste la meta: revisa la PC"
	return ""
