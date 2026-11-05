class_name SettingsMenu
extends Control
## Panel modal "Ajustes": volumen de música y efectos, Regresar y Salir (con confirmación).
## La fila "Tema" (Oscuro/Claro) solo aparece cuando lo abre el dashboard: ver SettingsButton.show_theme_option.
## Funciona con el árbol en pausa (process_mode = ALWAYS); quien lo abre pausa y reanuda el juego.

signal closed

const MUTE_TEXT := "Silenciar"
const UNMUTE_TEXT := "Activar"

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
	_return_button.pressed.connect(close)
	_quit_button.pressed.connect(_show_confirm.bind(true))
	_cancel_quit_button.pressed.connect(_show_confirm.bind(false))
	_confirm_quit_button.pressed.connect(_save_and_quit)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


## `show_theme` = mostrar la fila "Tema" (solo desde el dashboard).
func open(show_theme: bool = false) -> void:
	_theme_row.visible = show_theme
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


func _save_and_quit() -> void:
	SaveSystem.save_game()
	Settings.save_settings()
	hide()
	get_tree().paused = false
	SceneRouter.goto(Paths.TITLE_MENU)


func _apply_theme() -> void:
	_window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.ACCENT, 2, 18, 32.0))
