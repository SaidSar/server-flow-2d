class_name GameOver
extends Control
## Game over: la empresa quebró (SLA en 0) o no llegó a la meta de la etapa.

signal retry_requested
signal menu_requested

@onready var _title_label: Label = %TitleLabel
@onready var _reason_label: Label = %ReasonLabel
@onready var _summary: ReportSummary = %Summary
@onready var _retry_button: Button = %RetryButton
@onready var _menu_button: Button = %MenuButton
@onready var _window: PanelContainer = %Window


func _ready() -> void:
	_window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.DANGER, 3, 18, 32.0))
	_retry_button.pressed.connect(retry_requested.emit)
	_menu_button.pressed.connect(menu_requested.emit)
	hide()


func show_report(report: WaveReport, company_name: String) -> void:
	if report.outcome == WaveReport.Outcome.GOAL_MISSED:
		_title_label.text = "%s no alcanzó la meta" % company_name
		_reason_label.text = "Terminaron las oleadas con %d de %d usuarios atendidos." % [report.stage_users_served, report.stage_user_goal]
	else:
		_title_label.text = "%s quebró" % company_name
		_reason_label.text = "El SLA llegó a 0 %: los clientes dejaron de confiar en el servicio."
	_summary.show_report(report)
	show()
	_retry_button.grab_focus()
