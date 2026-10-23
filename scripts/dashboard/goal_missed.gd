class_name GoalMissed
extends Control
## "Meta no alcanzada": terminaron las oleadas con SLA > 0 pero sin los usuarios de la meta.
## No es quiebra: se puede repetir la etapa desde la oleada 1 con los ahorros con que empezó.

signal repeat_requested
signal room_requested

@onready var _users_label: Label = %UsersLabel
@onready var _users_bar: ProgressBar = %UsersBar
@onready var _sla_label: Label = %SlaLabel
@onready var _advice_label: Label = %AdviceLabel
@onready var _repeat_button: Button = %RepeatButton
@onready var _room_button: Button = %RoomButton
@onready var _window: PanelContainer = %Window


func _ready() -> void:
	_window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.WARNING, 3, 18, 32.0))
	_users_bar.add_theme_stylebox_override(&"fill", DashboardColors.bar_style(DashboardColors.WARNING))
	_users_bar.add_theme_stylebox_override(&"background", DashboardColors.bar_style(DashboardColors.BACKGROUND))
	_repeat_button.pressed.connect(repeat_requested.emit)
	_room_button.pressed.connect(room_requested.emit)
	hide()


func show_report(report: WaveReport) -> void:
	_users_label.text = "Usuarios atendidos: %s / %s" % [NumberFormat.thousands(report.stage_users_served), NumberFormat.thousands(report.stage_user_goal)]
	_users_bar.max_value = maxi(report.stage_user_goal, 1)
	_users_bar.value = report.stage_users_served
	_sla_label.text = "SLA promedio: %.1f %%" % report.stage_avg_sla
	_advice_label.text = report.get_stage_advice()
	show()
	_repeat_button.grab_focus()
