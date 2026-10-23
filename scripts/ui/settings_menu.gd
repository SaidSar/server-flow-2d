class_name SettingsMenu
extends Control
## Panel modal "Ajustes": volumen de música y efectos, Regresar y Salir (con confirmación).
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
@onready var _return_button: Button = %ReturnButton
@onready var _quit_button: Button = %QuitButton
@onready var _confirm_quit_button: Button = %ConfirmQuitButton
@onready var _cancel_quit_button: Button = %CancelQuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_window.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.ACCENT, 2, 18, 32.0))
	_music_slider.value_changed.connect(_on_music_slider_changed)
	_sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	_music_mute.toggled.connect(_on_music_mute_toggled)
	_sfx_mute.toggled.connect(_on_sfx_mute_toggled)
	_return_button.pressed.connect(close)
	_quit_button.pressed.connect(_show_confirm.bind(true))
	_cancel_quit_button.pressed.connect(_show_confirm.bind(false))
	_confirm_quit_button.pressed.connect(_save_and_quit)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


func open() -> void:
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


func _sync_from_settings() -> void:
	_music_slider.set_value_no_signal(Settings.music_volume * 100.0)
	_sfx_slider.set_value_no_signal(Settings.sfx_volume * 100.0)
	_music_mute.set_pressed_no_signal(Settings.music_muted)
	_sfx_mute.set_pressed_no_signal(Settings.sfx_muted)
	_refresh_labels()


func _refresh_labels() -> void:
	_music_value.text = "%d %%" % roundi(_music_slider.value)
	_sfx_value.text = "%d %%" % roundi(_sfx_slider.value)
	_music_mute.text = UNMUTE_TEXT if _music_mute.button_pressed else MUTE_TEXT
	_sfx_mute.text = UNMUTE_TEXT if _sfx_mute.button_pressed else MUTE_TEXT


func _on_music_slider_changed(value: float) -> void:
	Settings.set_music_volume(value / 100.0)
	_refresh_labels()


func _on_sfx_slider_changed(value: float) -> void:
	Settings.set_sfx_volume(value / 100.0)
	_refresh_labels()


func _on_music_mute_toggled(muted: bool) -> void:
	Settings.set_music_muted(muted)
	_refresh_labels()


func _on_sfx_mute_toggled(muted: bool) -> void:
	Settings.set_sfx_muted(muted)
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
