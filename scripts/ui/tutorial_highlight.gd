class_name TutorialHighlight
extends Control
## Recuadro que pulsa alrededor de lo que el jugador debe tocar (la PC, la consola de mejoras...),
## con una etiqueta "TAP" cuando hay que tocarlo. No recibe clics: lo de abajo sigue funcionando.
## `rect_provider` devuelve el rectángulo en coordenadas de pantalla y se lee cada cuadro, así sigue
## al objetivo si la cámara o la ventana cambian.

const PULSE_SPEED := 4.5
const GROW_MIN := 6.0
const GROW_MAX := 16.0
const BORDER_WIDTH := 5
const CHIP_TEXT := "TAP"
const CHIP_FONT_SIZE := 28
const CHIP_PADDING := Vector2(18.0, 8.0)
const CHIP_GAP := 14.0

var rect_provider: Callable
var show_chip := true

var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	hide()


## `provider` vacío o `null` = sin recuadro.
func point_at(provider: Callable, with_chip: bool) -> void:
	rect_provider = provider
	show_chip = with_chip
	visible = provider.is_valid()
	set_process(visible)
	queue_redraw()


func clear() -> void:
	point_at(Callable(), false)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if not rect_provider.is_valid():
		return
	var rect: Rect2 = rect_provider.call()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var pulse := 0.5 + 0.5 * sin(_time * PULSE_SPEED)
	var accent := DashboardColors.ACCENT
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(accent, 0.10 + 0.12 * pulse)
	frame.border_color = Color(accent, 0.55 + 0.45 * pulse)
	frame.set_border_width_all(BORDER_WIDTH)
	frame.set_corner_radius_all(18)
	draw_style_box(frame, rect.grow(lerpf(GROW_MIN, GROW_MAX, pulse)))
	if show_chip:
		_draw_chip(rect, pulse)


func _draw_chip(rect: Rect2, pulse: float) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(CHIP_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_FONT_SIZE)
	var chip_size := text_size + CHIP_PADDING * 2.0
	var top := rect.position.y - lerpf(GROW_MIN, GROW_MAX, pulse) - CHIP_GAP - chip_size.y
	# Si el objetivo está pegado al borde de arriba, la etiqueta va debajo.
	if top < 4.0:
		top = rect.end.y + lerpf(GROW_MIN, GROW_MAX, pulse) + CHIP_GAP
	var chip_rect := Rect2(Vector2(rect.get_center().x - chip_size.x * 0.5, top), chip_size)
	var chip_style := DashboardColors.panel_style(DashboardColors.ACCENT, DashboardColors.ACCENT, 0, 10, 0.0)
	draw_style_box(chip_style, chip_rect)
	draw_string(font, chip_rect.position + Vector2(CHIP_PADDING.x, CHIP_PADDING.y + font.get_ascent(CHIP_FONT_SIZE)),
		CHIP_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, CHIP_FONT_SIZE, DashboardColors.TEXT_ON_ACCENT)
