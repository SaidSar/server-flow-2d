class_name TrafficNode
extends PanelContainer
## Tarjeta de un nodo del monitor (Clientes, Firewall, Load Balancer, Servidor, BD)
## con barras de utilización que se interpolan suavemente.

const BAR_LERP_SPEED := 6.0
const BAR_HEIGHT := 18.0

@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _metrics_box: VBoxContainer = %MetricsBox

var _bars: Dictionary[StringName, ProgressBar] = {}
var _value_labels: Dictionary[StringName, Label] = {}
## Utilización objetivo (0..∞) de cada barra.
var _targets: Dictionary[StringName, float] = {}
## Barras "positivas" (como la caché): siempre en azul, más es mejor.
var _positive: Dictionary[StringName, bool] = {}
var _fill_styles: Dictionary[Color, StyleBoxFlat] = {}
var _normal_style := DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.PANEL_BORDER, 2, 12, 12.0)
var _alert_style := DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.DANGER, 3, 12, 12.0)
var _track_style := DashboardColors.bar_style(DashboardColors.BAR_TRACK)
var _name_labels: Array[Label] = []
var _is_alert := false
var _is_compact := false


func _ready() -> void:
	add_theme_stylebox_override(&"panel", _normal_style)
	UiTheme.changed.connect(_apply_theme)


func _process(delta: float) -> void:
	var weight := 1.0 - exp(-BAR_LERP_SPEED * delta)
	for metric_id: StringName in _bars:
		var bar := _bars[metric_id]
		var target := minf(_targets[metric_id], 1.0) * 100.0
		bar.value = lerpf(bar.value, target, weight)
		var color := DashboardColors.ACCENT if _positive[metric_id] else DashboardColors.for_utilization(bar.value / 100.0)
		bar.add_theme_stylebox_override(&"fill", _get_fill_style(color))
	if _is_alert:
		_alert_style.border_color.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)


func setup(title: String, subtitle: String = "") -> void:
	_title_label.text = title
	set_subtitle(subtitle)


func set_subtitle(text: String) -> void:
	_subtitle_label.text = text
	_subtitle_label.visible = not text.is_empty() and not _is_compact


## Compacta: sin subtítulo, para que quepan muchos servidores.
func set_compact(compact: bool) -> void:
	_is_compact = compact
	_subtitle_label.visible = not _subtitle_label.text.is_empty() and not compact


## Agrega una barra. `positive` = más es mejor (se pinta en azul).
func add_metric(metric_id: StringName, label_text: String, positive: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_label := _make_label(label_text, 18, DashboardColors.TEXT_MUTED)
	_name_labels.append(name_label)
	name_label.custom_minimum_size.x = 82.0
	row.add_child(name_label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(110.0, BAR_HEIGHT)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override(&"background", _track_style)
	row.add_child(bar)
	var value_label := _make_label("0 %", 18, DashboardColors.TEXT)
	value_label.custom_minimum_size.x = 62.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_metrics_box.add_child(row)
	_bars[metric_id] = bar
	_value_labels[metric_id] = value_label
	_targets[metric_id] = 0.0
	_positive[metric_id] = positive


func set_metric(metric_id: StringName, utilization: float) -> void:
	if not _bars.has(metric_id):
		return
	_targets[metric_id] = maxf(utilization, 0.0)
	_value_labels[metric_id].text = "%d %%" % roundi(utilization * 100.0)


func set_alert(alert: bool) -> void:
	if alert == _is_alert:
		return
	_is_alert = alert
	add_theme_stylebox_override(&"panel", _alert_style if alert else _normal_style)


## Centro de la tarjeta en coordenadas de su padre (considera la escala).
func get_center() -> Vector2:
	return position + size * scale * 0.5


## Punto del borde de la tarjeta en dirección a `target` (coordenadas del padre).
func get_edge_toward(target: Vector2) -> Vector2:
	var center := get_center()
	var direction := target - center
	var half := size * scale * 0.5
	if direction.is_zero_approx():
		return center
	var t := INF
	if not is_zero_approx(direction.x):
		t = minf(t, half.x / absf(direction.x))
	if not is_zero_approx(direction.y):
		t = minf(t, half.y / absf(direction.y))
	return center + direction * minf(t, 1.0)


func _get_fill_style(color: Color) -> StyleBoxFlat:
	if not _fill_styles.has(color):
		_fill_styles[color] = DashboardColors.bar_style(color)
	return _fill_styles[color]


static func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Los estilos se reutilizan: al cambiar de tema se recolorean en su lugar.
func _apply_theme() -> void:
	for style: StyleBoxFlat in [_normal_style, _alert_style]:
		style.bg_color = DashboardColors.PANEL
	_normal_style.border_color = DashboardColors.PANEL_BORDER
	_alert_style.border_color = DashboardColors.DANGER
	_track_style.bg_color = Color(DashboardColors.BAR_TRACK, 0.9)
	_fill_styles.clear()
	for label: Label in _name_labels:
		label.add_theme_color_override(&"font_color", DashboardColors.TEXT_MUTED)
	for label: Label in _value_labels.values():
		label.add_theme_color_override(&"font_color", DashboardColors.TEXT)
