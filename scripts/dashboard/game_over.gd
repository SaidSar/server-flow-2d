class_name GameOver
extends Control
## Game over: la empresa quebró porque el SLA llegó a 0.
## (No llegar a la meta no es quiebra: eso lo muestra GoalMissed.)

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
	_title_label.text = "%s quebró" % company_name
	_reason_label.text = "El SLA llegó a 0 %: los clientes dejaron de confiar en el servicio."
	_summary.show_report(report)
	show()
	_retry_button.grab_focus()
