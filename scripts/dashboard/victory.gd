class_name Victory
extends Control
## Victoria de etapa: estadísticas, estrellas (1–4) y mejoras desbloqueadas.

signal continue_requested

const MAX_STARS := 4

@onready var _title_label: Label = %TitleLabel
@onready var _stars_box: HBoxContainer = %StarsBox
@onready var _stats_label: Label = %StatsLabel
@onready var _unlocks_label: Label = %UnlocksLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _window: ReportWindow = %Window


func _ready() -> void:
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)
	_continue_button.pressed.connect(continue_requested.emit)
	hide()


## `unlock_names` vacío = no hay más etapas. `investment` = monedas de la ronda de inversión.
func show_report(report: WaveReport, stage_name: String, unlock_names: PackedStringArray, investment: int) -> void:
	_title_label.text = "¡Etapa %s completada!" % stage_name
	for i in _stars_box.get_child_count():
		var star := _stars_box.get_child(i) as TextureRect
		star.modulate = DashboardColors.WARNING if i < report.stars else Color(DashboardColors.TEXT_MUTED, 0.35)
	_stars_box.tooltip_text = "%d de %d estrellas" % [report.stars, MAX_STARS]
	_stats_label.text = "Usuarios atendidos: %s / %s\nPeticiones atendidas: %s\nSLA promedio: %.1f %%\nLatencia promedio: %d ms" % [
		NumberFormat.thousands(report.stage_users_served), NumberFormat.thousands(report.stage_user_goal),
		NumberFormat.traffic(report.stage_users_served, Simulation.config.display_scale),
		report.stage_avg_sla, roundi(report.stage_avg_latency_ms)]
	if unlock_names.is_empty():
		_unlocks_label.text = "¡Completaste todas las etapas!"
		_continue_button.text = "Volver al cuarto"
	else:
		_unlocks_label.text = "Desbloqueado: %s" % ", ".join(unlock_names)
		if investment > 0:
			_unlocks_label.text += "\nRonda de inversión: +%s monedas" % NumberFormat.thousands(investment)
		_continue_button.text = "Siguiente etapa"
	show()
	_window.refit()
	_continue_button.grab_focus()


func _apply_theme() -> void:
	_window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.OK, 3, 18, 24.0))
