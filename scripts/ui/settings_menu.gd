class_name SettingsMenu
extends Control
## Panel modal "Ajustes": volumen de música y efectos, Regresar y Salir (con confirmación).
## La fila "Tema" (Oscuro/Claro) solo aparece cuando lo abre el dashboard: ver SettingsButton.show_theme_option.
## El menú de título lo abre fuera de una partida: con Tema, sin "Salir", "Regresar" dice "Cerrar" y en PC
## agrega "Pantalla completa".
## Funciona con el árbol en pausa (process_mode = ALWAYS); quien lo abre pausa y reanuda el juego.

signal closed
## "Ver tutorial otra vez": el tutorial ya se reinició (Tutorial.start); quien abrió el panel lleva al jugador al cuarto.
signal tutorial_replay_requested

const MUTE_TEXT := "Silenciar"
const UNMUTE_TEXT := "Activar"
const RETURN_TEXT := "Regresar"
const CLOSE_TEXT := "Cerrar"

@onready var _window: PanelContainer = %Window
@onready var _main_box: Control = %MainBox
@onready var _confirm_box: Control = %ConfirmBox
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value: Label = %MusicValue
@onready var _music_mute: Button = %MusicMute
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value: Label = %SfxValue
@onready var _sfx_mute: Button = %SfxMute
@onready var _theme_row: Control = %ThemeRow
@onready var _theme_dark_button: Button = %ThemeDarkButton
@onready var _theme_light_button: Button = %ThemeLightButton
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _tutorial_button: Button = %TutorialButton
@onready var _return_button: Button = %ReturnButton
@onready var _quit_button: Button = %QuitButton
@onready var _confirm_quit_button: Button = %ConfirmQuitButton
@onready var _cancel_quit_button: Button = %CancelQuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme()
	UiTheme.changed.connect(_apply_theme)
	_music_slider.value_changed.connect(_on_music_slider_changed)
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	_music_mute.toggled.connect(_on_music_mute_toggled)
	_sfx_mute.toggled.connect(_on_sfx_mute_toggled)
	_theme_dark_button.pressed.connect(Settings.set_ui_theme.bind(UiTheme.DARK))
	_theme_light_button.pressed.connect(Settings.set_ui_theme.bind(UiTheme.LIGHT))
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_tutorial_button.pressed.connect(_on_tutorial_pressed)
	_return_button.pressed.connect(close)
	_quit_button.pressed.connect(_show_confirm.bind(true))
	_cancel_quit_button.pressed.connect(_show_confirm.bind(false))
	_confirm_quit_button.pressed.connect(_save_and_quit)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


## `show_theme` = mostrar la fila "Tema". `in_game` = false desde el menú de título (no hay partida que
## regresar ni de la cual salir).
func open(show_theme: bool = false, in_game: bool = true) -> void:
	_theme_row.visible = show_theme
	_quit_button.visible = in_game
	_tutorial_button.visible = in_game and Tutorial.get_step_count() > 0
	_return_button.text = RETURN_TEXT if in_game else CLOSE_TEXT
	# En Android el juego siempre es pantalla completa.
	_fullscreen_check.visible = not in_game and OS.get_name() != "Android"
	_fullscreen_check.set_pressed_no_signal(_is_fullscreen())
	_sync_from_settings()
	_show_confirm(false)
	show()
	_return_button.grab_focus()


## Esc o "atrás" de Android: primero cancela la confirmación, luego cierra el panel.
func go_back() -> void:
	if _confirm_box.visible:
		_show_confirm(false)
	else:
		close()


func close() -> void:
	if not visible:
		return
	Settings.save_settings()
	hide()
	closed.emit()


func is_confirming_quit() -> bool:
	return _confirm_box.visible


func is_theme_row_visible() -> bool:
	return _theme_row.visible


## Silenciado, el slider se ve en 0 %; el volumen anterior se guarda en Settings y vuelve al reactivar.
func _sync_from_settings() -> void:
	_music_mute.set_pressed_no_signal(Settings.music_muted)
	_sfx_mute.set_pressed_no_signal(Settings.sfx_muted)
	_show_volume(_music_slider, Settings.music_volume, Settings.music_muted)
	_show_volume(_sfx_slider, Settings.sfx_volume, Settings.sfx_muted)
	_theme_dark_button.set_pressed_no_signal(Settings.ui_theme == UiTheme.DARK)
	_theme_light_button.set_pressed_no_signal(Settings.ui_theme == UiTheme.LIGHT)
	_refresh_labels()


func _refresh_labels() -> void:
	_music_value.text = "%d %%" % roundi(_music_slider.value)
	_sfx_value.text = "%d %%" % roundi(_sfx_slider.value)
	_music_mute.text = UNMUTE_TEXT if _music_mute.button_pressed else MUTE_TEXT
	_sfx_mute.text = UNMUTE_TEXT if _sfx_mute.button_pressed else MUTE_TEXT


static func _show_volume(slider: HSlider, volume: float, muted: bool) -> void:
	slider.set_value_no_signal(0.0 if muted else volume * 100.0)


## Mover el slider a 0 silencia (sin olvidar el volumen anterior); moverlo arriba de 0 quita el silencio.
func _on_music_slider_changed(value: float) -> void:
	if is_zero_approx(value):
		Settings.set_music_muted(true)
	else:
		Settings.set_music_volume(value / 100.0)
		Settings.set_music_muted(false)
	_music_mute.set_pressed_no_signal(Settings.music_muted)
	_refresh_labels()


func _on_sfx_slider_changed(value: float) -> void:
	if is_zero_approx(value):
		Settings.set_sfx_muted(true)
	else:
		Settings.set_sfx_volume(value / 100.0)
		Settings.set_sfx_muted(false)
	_sfx_mute.set_pressed_no_signal(Settings.sfx_muted)
	_refresh_labels()


func _on_music_mute_toggled(muted: bool) -> void:
	if not muted and is_zero_approx(Settings.music_volume):
		Settings.set_music_volume(Settings.DEFAULT_VOLUME)
	Settings.set_music_muted(muted)
	_show_volume(_music_slider, Settings.music_volume, muted)
	_refresh_labels()


func _on_sfx_mute_toggled(muted: bool) -> void:
	if not muted and is_zero_approx(Settings.sfx_volume):
		Settings.set_sfx_volume(Settings.DEFAULT_VOLUME)
	Settings.set_sfx_muted(muted)
	_show_volume(_sfx_slider, Settings.sfx_volume, muted)
	_refresh_labels()


func _show_confirm(confirm: bool) -> void:
	_main_box.visible = not confirm
	_confirm_box.visible = confirm
	if confirm:
		_cancel_quit_button.grab_focus()
	elif visible:
		_return_button.grab_focus()


func _on_tutorial_pressed() -> void:
	Tutorial.start()
	close()
	tutorial_replay_requested.emit()


func _save_and_quit() -> void:
	SaveSystem.save_game()
	Settings.save_settings()
	hide()
	get_tree().paused = false
	SceneRouter.goto(Paths.TITLE_MENU)


func _apply_theme() -> void:
	_window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.ACCENT, 2, 18, 32.0))
	_style_switch(_fullscreen_check)


## El interruptor usa íconos con los colores del tema (el de Godot casi no se ve en oscuro) y sin
## caja de botón, igual en los dos temas.
static func _style_switch(check: CheckButton) -> void:
	var on := UiTheme.switch_icon(true)
	var off := UiTheme.switch_icon(false)
	for icon_name: StringName in [&"checked", &"checked_mirrored"]:
		check.add_theme_icon_override(icon_name, on)
	for icon_name: StringName in [&"unchecked", &"unchecked_mirrored"]:
		check.add_theme_icon_override(icon_name, off)
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
		check.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	for color_name: StringName in [&"font_color", &"font_pressed_color", &"font_focus_color"]:
		check.add_theme_color_override(color_name, DashboardColors.TEXT)
	for color_name: StringName in [&"font_hover_color", &"font_hover_pressed_color"]:
		check.add_theme_color_override(color_name, DashboardColors.ACCENT)


func _on_fullscreen_toggled(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


static func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
