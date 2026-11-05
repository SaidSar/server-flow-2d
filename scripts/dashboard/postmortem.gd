class_name Postmortem
extends Control
## Post-mortem entre oleadas: qué pasó y por qué. Cubre solo el monitor,
## así que la consola sigue disponible para comprar mejoras antes de seguir.
## Desde Scale-up también lleva a la tienda de decoración del cuarto.

signal next_wave_requested
signal room_requested
signal shop_requested

@onready var _title_label: Label = %TitleLabel
@onready var _summary: ReportSummary = %Summary
@onready var _next_button: Button = %NextButton
@onready var _room_button: Button = %RoomButton
@onready var _shop_button: Button = %ShopButton
@onready var _window: PanelContainer = %Window


func _ready() -> void:
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)
	_next_button.pressed.connect(next_wave_requested.emit)
	_room_button.pressed.connect(room_requested.emit)
	_shop_button.pressed.connect(shop_requested.emit)
	hide()


func show_report(report: WaveReport, next_wave: int, wave_count: int) -> void:
	_title_label.text = "Post-mortem · Oleada %d" % report.wave_number
	_summary.show_report(report)
	_next_button.text = "Siguiente oleada (%d/%d)" % [next_wave, wave_count]
	_shop_button.visible = DecorShop.is_unlocked()
	show()
	_next_button.grab_focus()


func _apply_theme() -> void:
	_window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.ACCENT, 2, 18, 28.0))
