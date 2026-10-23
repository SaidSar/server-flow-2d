extends Control
## Menú de título: Nueva partida, Continuar, Opciones y Salir.

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _options_panel: Control = %OptionsPanel
@onready var _fullscreen_check: CheckButton = %FullscreenCheck
@onready var _close_options_button: Button = %CloseOptionsButton


func _ready() -> void:
	Simulation.stop()
	_continue_button.disabled = not SaveSystem.has_save()
	_options_panel.hide()
	# En Android el juego siempre es pantalla completa.
	_fullscreen_check.visible = OS.get_name() != "Android"
	_fullscreen_check.button_pressed = _is_fullscreen()

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_options_button.pressed.connect(_options_panel.show)
	_quit_button.pressed.connect(SceneRouter.quit_game)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_close_options_button.pressed.connect(_options_panel.hide)
	_new_game_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _options_panel.visible and event.is_action_pressed(&"ui_cancel"):
		_options_panel.hide()
		get_viewport().set_input_as_handled()


func _on_new_game_pressed() -> void:
	var first_room := GameState.get_stage_data(GameState.DEFAULT_STAGE).room_scene_path
	SceneRouter.goto_via_loading(Paths.NEW_GAME_SETUP, PackedStringArray([first_room, Paths.NEW_GAME_SETUP]))


func _on_continue_pressed() -> void:
	if SaveSystem.load_game():
		SceneRouter.goto_current_room()
	else:
		_continue_button.disabled = true


func _on_fullscreen_toggled(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
