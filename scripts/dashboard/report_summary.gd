class_name ReportSummary
extends BoxContainer
## Estadísticas de una oleada y su causa principal con la explicación educativa.
## Lo usan el post-mortem y el game over. En una ventana ancha (ReportWindow) va lado a lado:
## estadísticas a la izquierda y causa a la derecha; si no, una debajo de la otra.

@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _cause_box: PanelContainer = %CauseBox
@onready var _cause_title: Label = %CauseTitle
@onready var _cause_text: Label = %CauseText

var _value_labels: Dictionary[StringName, Label] = {}
var _name_labels: Array[Label] = []
## Último reporte mostrado: se vuelve a pintar si cambia el tema.
var _last_report: WaveReport


func _ready() -> void:
	UiTheme.changed.connect(_apply_theme)
	for row: Array in [
		[&"served", "Peticiones atendidas"],
		[&"timeouts", "Timeouts"],
		[&"errors_500", "Errores 500"],
		[&"latency", "Latencia media"],
		[&"sla", "SLA final"],
		[&"coins", "Monedas ganadas"],
	]:
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.add_theme_color_override(&"font_color", DashboardColors.TEXT_MUTED)
		name_label.add_theme_font_size_override(&"font_size", 22)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats_grid.add_child(name_label)
		_name_labels.append(name_label)
		var value_label := Label.new()
		value_label.add_theme_color_override(&"font_color", DashboardColors.TEXT)
		value_label.add_theme_font_size_override(&"font_size", 22)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stats_grid.add_child(value_label)
		_value_labels[row[0]] = value_label


func show_report(report: WaveReport) -> void:
	_last_report = report
	var display_scale := Simulation.config.display_scale
	_value_labels[&"served"].text = "%s de %s" % [NumberFormat.traffic(report.green + report.yellow, display_scale), NumberFormat.traffic(report.requests, display_scale)]
	_value_labels[&"timeouts"].text = NumberFormat.traffic(report.timeouts, display_scale)
	_value_labels[&"errors_500"].text = NumberFormat.traffic(report.errors_500, display_scale)
	_value_labels[&"latency"].text = "%d ms" % roundi(report.get_avg_latency_ms())
	_value_labels[&"sla"].text = "%.1f %%" % report.sla_end
	_value_labels[&"coins"].text = "+%d" % roundi(report.coins_earned)
	_value_labels[&"timeouts"].add_theme_color_override(&"font_color", DashboardColors.DANGER if report.timeouts >= 0.5 else DashboardColors.TEXT)
	_value_labels[&"errors_500"].add_theme_color_override(&"font_color", DashboardColors.DANGER if report.errors_500 >= 0.5 else DashboardColors.TEXT)
	var cause := report.get_main_cause()
	_cause_title.text = "Causa principal: %s" % report.get_main_cause_title() if cause != &"" else "Causa principal: ninguna"
	_cause_title.add_theme_color_override(&"font_color", DashboardColors.DANGER if cause != &"" else DashboardColors.OK)
	_cause_text.text = report.get_main_cause_explanation()


## true = estadísticas y causa lado a lado (la causa arriba, del alto de su texto).
func set_wide(wide: bool) -> void:
	vertical = not wide
	_cause_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if wide else Control.SIZE_FILL


func is_wide() -> bool:
	return not vertical


## Las etiquetas se crean con los colores del tema actual; al cambiarlo se repintan.
func _apply_theme() -> void:
	for label: Label in _name_labels:
		label.add_theme_color_override(&"font_color", DashboardColors.TEXT_MUTED)
	for value_label: Label in _value_labels.values():
		value_label.add_theme_color_override(&"font_color", DashboardColors.TEXT)
	if _last_report != null:
		show_report(_last_report)
