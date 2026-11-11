class_name TutorialOverlay
extends CanvasLayer
## Tutorial de Briseida y BYTE. El cuarto y el dashboard tienen uno cada uno; los dos leen el paso de
## Tutorial (autoload) y muestran solo los pasos de su escena (`scene_id`).
## - Briseida: busto a la izquierda (70 % del alto de la pantalla) y caja de diálogo con su nombre, texto
##   que se escribe solo y puntos de progreso. Tocar completa el texto y luego avanza. En los pasos donde
##   el jugador debe tocar algo la caja se hace pequeña, el busto se esconde y se resalta el objetivo con "TAP".
## - BYTE: no usa esta caja. Pide su globo al dashboard (byte_requested) y su OK avanza el paso.
## - Los pasos de la otra escena se reemplazan por un aviso ("vuelve a la computadora").
## - En el dashboard, mientras un paso solo se lee (no hay nada que tocar) la simulación se pausa.

## BYTE tiene que decir este texto en el dashboard, con esta expresión.
signal byte_requested(text: String, expression: StringName)
## La caja de Briseida apareció o se fue (el cuarto esconde su aviso de la PC mientras está).
signal box_visibility_changed(box_visible: bool)
## La caja tapa la pantalla esperando un toque (el dashboard retiene los mensajes de BYTE mientras tanto).
signal blocking_changed(blocking: bool)

## Altura del busto respecto a la pantalla (aprobada por el equipo).
const BUST_HEIGHT_RATIO := 0.70
## Ancho / alto de briseida_busto_*.png (533×800).
const BUST_ASPECT := 533.0 / 800.0
## La caja empieza donde el busto ya está al 88 % de su ancho: se solapan un poco, como en una novela visual.
const BOX_OVERLAP := 0.88
const BOX_MARGIN := 36.0
## Espacio a la derecha para el engranaje de Ajustes (88 px + su margen).
const BOX_RIGHT_RESERVE := 140.0
const BOX_MIN_HEIGHT := 230.0
const COMPACT_WIDTH := 1000.0
const BOX_PADDING := Vector2(34.0, 22.0)
const TAB_TOP_SPACE := 22.0
const TYPE_CHARS_PER_SECOND := 48.0
const SLIDE_SECONDS := 0.35
const FADE_SECONDS := 0.15
const DOT_SIZE := 12.0
const MORE_BLINK_SPEED := 5.0

## Escena que dibuja este overlay: "room" o "dashboard".
@export var scene_id: StringName = TutorialStep.SCENE_ROOM
## Pausar la simulación mientras el paso solo se lee (dashboard).
@export var pause_simulation := false
## Aviso cuando el paso es de la otra escena.
@export var fallback_text := "Vuelve a la computadora para seguir con el tutorial."
## Si es positivo, la caja pequeña de los pasos de acción va arriba (a esta altura) en lugar de abajo.
## El dashboard la usa para no tapar la consola de mejoras, que está abajo.
@export var compact_top := -1.0

@onready var _root: Control = %Root
@onready var _highlight: TutorialHighlight = %Highlight
@onready var _bust: TextureRect = %Bust
@onready var _box: PanelContainer = %Box
@onready var _tab: PanelContainer = %Tab
@onready var _tab_label: Label = %TabLabel
@onready var _text_label: Label = %TextLabel
@onready var _dots: HBoxContainer = %Dots
@onready var _skip_step_button: Button = %SkipStepButton
@onready var _skip_button: Button = %SkipButton
@onready var _more_label: Label = %MoreLabel

## Clave → función que devuelve el rectángulo (en pantalla) de lo que se resalta.
var _providers: Dictionary[StringName, Callable] = {}
var _textures: Dictionary[StringName, Texture2D] = {}
## Paso y modo que se están mostrando ("" = nada); evita reiniciar el texto en cada refresco.
var _shown_key := ""
var _suspended := false
var _compact := false
var _bust_visible := false
var _typing := false
var _chars := 0.0
var _wants_pause := false
var _paused_by_us := false
var _bust_tween: Tween
var _box_tween: Tween
var _last_box_visible := false
var _last_blocking := false


func _ready() -> void:
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)
	_skip_button.pressed.connect(Tutorial.skip)
	_skip_step_button.pressed.connect(Tutorial.advance)
	_root.gui_input.connect(_on_gui_input)
	_box.gui_input.connect(_on_gui_input)
	Tutorial.step_changed.connect(_refresh_deferred)
	Simulation.phase_changed.connect(_on_simulation_changed.unbind(1))
	Simulation.wave_started.connect(_on_simulation_changed.unbind(1))
	Simulation.wave_finished.connect(_on_simulation_changed.unbind(1))
	Simulation.stage_failed.connect(_on_simulation_changed.unbind(1))
	Simulation.stage_completed.connect(_on_simulation_changed.unbind(1))
	Simulation.game_over.connect(_on_simulation_changed.unbind(1))
	get_viewport().size_changed.connect(_on_viewport_resized)
	SceneRouter.safe_area_changed.connect(_on_viewport_resized)
	_hide_all()
	# Diferido: el dashboard arranca la oleada en su _ready, después que sus hijos; hay que pausar después de eso.
	_refresh_deferred()


func _exit_tree() -> void:
	_release_pause()


func _process(delta: float) -> void:
	if _typing:
		_chars += delta * TYPE_CHARS_PER_SECOND
		var total := _text_label.get_total_character_count()
		if int(_chars) >= total:
			_finish_typing()
		else:
			_text_label.visible_characters = int(_chars)
	elif _more_label.visible:
		_more_label.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.001 * MORE_BLINK_SPEED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept") and _box.visible and not _suspended:
		_on_tap()
		get_viewport().set_input_as_handled()


#region API

## Dónde está lo que se resalta (`key` = el `highlight` del paso: pc, health, console).
func register_highlight(key: StringName, provider: Callable) -> void:
	_providers[key] = provider
	_shown_key = ""
	_refresh_deferred()


## Oculta todo (p. ej. mientras el cuarto hace zoom hacia la PC) hasta que cambie la escena.
func set_suspended(suspended: bool) -> void:
	_suspended = suspended
	_shown_key = ""
	_refresh()


## BYTE cerró su globo del tutorial.
func on_byte_dismissed() -> void:
	var step := Tutorial.current()
	if step != null and step.is_byte() and step.scene == scene_id:
		Tutorial.advance()


## true mientras la caja de Briseida tapa la pantalla pidiendo un toque para continuar.
func is_blocking() -> bool:
	return _root.mouse_filter == Control.MOUSE_FILTER_STOP and _box.visible


func is_box_visible() -> bool:
	return _box.visible


func is_bust_visible() -> bool:
	return _bust_visible


func is_compact() -> bool:
	return _compact


func is_highlighting() -> bool:
	return _highlight.visible


func get_text() -> String:
	return _text_label.text if _box.visible else ""


func get_expression() -> StringName:
	for expression: StringName in _textures:
		if _textures[expression] == _bust.texture:
			return expression
	return &""


func is_typing() -> bool:
	return _typing


func is_pausing_simulation() -> bool:
	return _paused_by_us


## Equivale a tocar la caja: completa el texto y, si el paso solo se lee, avanza.
func tap() -> void:
	_on_tap()

#endregion


#region Refresco

func _on_simulation_changed() -> void:
	_refresh_deferred()
	# start_wave() quita la pausa: si el paso sigue siendo de lectura, se vuelve a pausar.
	_apply_pause.call_deferred()


func _on_viewport_resized() -> void:
	if _box.visible:
		_layout_box.call_deferred()
		_place_bust(_bust_visible, false)


func _refresh_deferred() -> void:
	_refresh.call_deferred()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var step := Tutorial.current()
	if _suspended or step == null:
		_shown_key = ""
		_hide_all()
		return
	var in_scene := step.scene == scene_id
	if in_scene and not Tutorial.is_ready(step):
		_shown_key = ""
		_hide_all()
		return
	var key := "%d|%s" % [Tutorial.get_step_index(), in_scene]
	if key == _shown_key:
		return
	_shown_key = key
	if in_scene and step.is_byte():
		_show_byte(step)
	else:
		_show_briseida(step, in_scene)


func _hide_all() -> void:
	_typing = false
	_wants_pause = false
	_release_pause()
	_highlight.clear()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_box()
	_place_bust(false, false)
	_emit_state()


func _hide_box() -> void:
	_box.hide()
	_tab.hide()


## BYTE: la caja y el busto se van; su globo está en el dashboard y se cierra con su OK.
func _show_byte(step: TutorialStep) -> void:
	_typing = false
	_hide_box()
	_place_bust(false, true)
	_highlight.clear()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_wants_pause(pause_simulation)
	_emit_state()
	byte_requested.emit(Tutorial.format(step.text), step.expression)


func _show_briseida(step: TutorialStep, in_scene: bool) -> void:
	_compact = not in_scene or step.needs_action()
	var text := Tutorial.format(step.text) if in_scene else fallback_text
	var expression := step.expression if in_scene else &"normal"
	_bust.texture = _get_texture(expression)
	_text_label.text = text
	_skip_step_button.visible = in_scene and step.needs_action()
	_rebuild_dots()
	# Solo los pasos de lectura bloquean la pantalla (el toque avanza); los de acción dejan pasar los toques.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE if _compact else Control.MOUSE_FILTER_STOP
	_set_wants_pause(pause_simulation and not _compact)
	_point_highlight(step if in_scene else null)
	_box.show()
	_tab.show()
	_start_typing()
	_layout_box()
	_layout_box.call_deferred()
	_place_bust(not _compact, true)
	_emit_state()


func _emit_state() -> void:
	if _last_box_visible != _box.visible:
		_last_box_visible = _box.visible
		box_visibility_changed.emit(_last_box_visible)
	var blocking := is_blocking()
	if _last_blocking != blocking:
		_last_blocking = blocking
		blocking_changed.emit(blocking)


func _point_highlight(step: TutorialStep) -> void:
	var key: StringName = &"pc" if step == null and scene_id == TutorialStep.SCENE_ROOM else (step.highlight if step != null else &"")
	var provider: Callable = _providers.get(key, Callable())
	var needs_tap := step == null or step.needs_action()
	_highlight.point_at(provider, needs_tap)

#endregion


#region Texto

func _start_typing() -> void:
	_chars = 0.0
	_typing = true
	_text_label.visible_characters = 0
	_more_label.hide()


func _finish_typing() -> void:
	_typing = false
	_text_label.visible_characters = -1
	_more_label.visible = not _compact
	_more_label.modulate.a = 1.0


func _on_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_on_tap()
		get_viewport().set_input_as_handled()


func _on_tap() -> void:
	if _typing:
		_finish_typing()
		return
	if not _compact and _box.visible:
		Tutorial.advance()

#endregion


#region Diseño

## Caja de texto y etiqueta con el nombre. En los pasos de lectura va a la derecha del busto; en los de
## acción (compactos) va pegada a la izquierda.
func _layout_box() -> void:
	if not _box.visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var insets := SafeArea.get_insets(get_viewport())
	var left := insets.x + BOX_MARGIN
	var width := minf(COMPACT_WIDTH, viewport_size.x - left - insets.z - BOX_RIGHT_RESERVE)
	if not _compact:
		left = insets.x + _get_bust_size().x * BOX_OVERLAP
		width = viewport_size.x - insets.z - BOX_RIGHT_RESERVE - left
	width = maxf(width, 320.0)
	_text_label.custom_minimum_size.x = width - BOX_PADDING.x * 2.0
	_box.custom_minimum_size = Vector2(width, 0.0 if _compact else BOX_MIN_HEIGHT)
	_box.reset_size()
	var bottom := viewport_size.y - insets.w - BOX_MARGIN
	_box.position = Vector2(left, bottom - _box.size.y)
	if _compact and compact_top >= 0.0:
		_box.position = Vector2(maxf((viewport_size.x - width) * 0.5, left), compact_top)
	_tab.reset_size()
	_tab.position = _box.position + Vector2(BOX_PADDING.x - 6.0, -_tab.size.y * 0.62)
	if _box_tween != null:
		_box_tween.kill()
	_box.modulate.a = 0.0
	_tab.modulate.a = 0.0
	_box_tween = create_tween().set_parallel()
	_box_tween.tween_property(_box, "modulate:a", 1.0, FADE_SECONDS)
	_box_tween.tween_property(_tab, "modulate:a", 1.0, FADE_SECONDS)


func _get_bust_size() -> Vector2:
	var height := get_viewport().get_visible_rect().size.y * BUST_HEIGHT_RATIO
	return Vector2(height * BUST_ASPECT, height)


func _bust_home_position() -> Vector2:
	var viewport_size := get_viewport().get_visible_rect().size
	var insets := SafeArea.get_insets(get_viewport())
	return Vector2(insets.x + 8.0, viewport_size.y - insets.w - _get_bust_size().y)


## Entra o sale deslizándose por la izquierda.
func _place_bust(show_bust: bool, animate: bool) -> void:
	_bust_visible = show_bust
	_bust.size = _get_bust_size()
	var home := _bust_home_position()
	var away := Vector2(-_bust.size.x - 40.0, home.y)
	var target := home if show_bust else away
	if _bust_tween != null:
		_bust_tween.kill()
	if not animate:
		_bust.position = target
		_bust.visible = show_bust
		return
	if show_bust and not _bust.visible:
		_bust.position = away
	_bust.visible = true
	_bust_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_bust_tween.tween_property(_bust, "position", target, SLIDE_SECONDS)
	if not show_bust:
		_bust_tween.tween_callback(_bust.hide)


func _get_texture(expression: StringName) -> Texture2D:
	if not _textures.has(expression):
		_textures[expression] = load(Paths.CEO_BUST % expression) as Texture2D
	return _textures[expression]


func _rebuild_dots() -> void:
	for child: Node in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	var current := Tutorial.get_step_index()
	for i in Tutorial.get_step_count():
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(DOT_SIZE))
		style.bg_color = DashboardColors.CEO if i == current else (DashboardColors.TEXT_MUTED if i < current else DashboardColors.CARD_BORDER)
		dot.add_theme_stylebox_override(&"panel", style)
		_dots.add_child(dot)


func _apply_theme() -> void:
	var box_style := DashboardColors.panel_style(DashboardColors.CARD, DashboardColors.CEO, 3, 20, 0.0)
	box_style.content_margin_left = BOX_PADDING.x
	box_style.content_margin_right = BOX_PADDING.x
	box_style.content_margin_top = BOX_PADDING.y + TAB_TOP_SPACE
	box_style.content_margin_bottom = BOX_PADDING.y
	_box.add_theme_stylebox_override(&"panel", box_style)
	var tab_style := DashboardColors.panel_style(DashboardColors.CEO, DashboardColors.CEO, 0, 12, 0.0)
	tab_style.content_margin_left = 20.0
	tab_style.content_margin_right = 20.0
	tab_style.content_margin_top = 6.0
	tab_style.content_margin_bottom = 6.0
	_tab.add_theme_stylebox_override(&"panel", tab_style)
	_tab_label.add_theme_color_override(&"font_color", DashboardColors.TEXT_ON_ACCENT)
	_text_label.add_theme_color_override(&"font_color", DashboardColors.TEXT)
	_more_label.add_theme_color_override(&"font_color", DashboardColors.CEO)
	for button: Button in [_skip_step_button, _skip_button]:
		button.add_theme_color_override(&"font_color", DashboardColors.TEXT_MUTED)
		button.add_theme_color_override(&"font_hover_color", DashboardColors.ACCENT)
		button.add_theme_color_override(&"font_pressed_color", DashboardColors.ACCENT)
	if _box.visible:
		_rebuild_dots()

#endregion


#region Pausa

func _set_wants_pause(value: bool) -> void:
	_wants_pause = value
	_apply_pause()


func _apply_pause() -> void:
	if not is_inside_tree():
		return
	if _wants_pause and Simulation.phase == Simulation.Phase.RUNNING and not Simulation.paused:
		Simulation.set_paused(true)
		_paused_by_us = true
	elif not _wants_pause:
		_release_pause()


func _release_pause() -> void:
	if _paused_by_us:
		_paused_by_us = false
		Simulation.set_paused(false)

#endregion
