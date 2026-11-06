extends Control
## Menú de título: Nueva partida, Continuar, Opciones y Salir.
## Salir (botón o "atrás" de Android) pide confirmación antes de cerrar el juego.
## Opciones abre el mismo panel de ajustes del engranaje (SettingsMenu), fuera de una partida.

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _options_panel: SettingsMenu = %OptionsPanel
@onready var _quit_confirm_panel: Control = %QuitConfirmPanel
@onready var _confirm_quit_button: Button = %ConfirmQuitButton
@onready var _cancel_quit_button: Button = %CancelQuitButton


@export var icono_escena: PackedScene  # IconoParticula.tscn
var tiempo_entre_iconos: float = .75
var tiempo_acumulado: float = 0.0


func _process(delta: float) -> void:
	tiempo_acumulado += delta
	if tiempo_acumulado >= tiempo_entre_iconos:
		tiempo_acumulado = 0.0
		generar_icono()

func generar_icono() -> void:
	if icono_escena == null:
		return
	var nuevo_icono = icono_escena.instantiate()
	var ancho_pantalla = get_viewport_rect().size.x
	nuevo_icono.position = Vector2(randf_range(0, ancho_pantalla), -50)
	add_child(nuevo_icono)

func _ready() -> void:
	GameState.end_session()
	_continue_button.disabled = not SaveSystem.has_save()
	_quit_confirm_panel.hide()

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_options_button.pressed.connect(_options_panel.open.bind(true, false))
	_options_panel.closed.connect(_options_button.grab_focus)
	_quit_button.pressed.connect(ask_quit)
	_confirm_quit_button.pressed.connect(SceneRouter.quit_game)
	_cancel_quit_button.pressed.connect(_cancel_quit)
	_new_game_button.grab_focus()


func _notification(what: int) -> void:
	# Botón "atrás" de Android: igual que Esc.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		go_back()
		get_viewport().set_input_as_handled()


## Cierra Opciones o la confirmación; si no hay nada abierto, pregunta si quiere salir.
func go_back() -> void:
	if _quit_confirm_panel.visible:
		_cancel_quit()
	elif _options_panel.visible:
		_options_panel.close()
	else:
		ask_quit()


func ask_quit() -> void:
	_quit_confirm_panel.show()
	_cancel_quit_button.grab_focus()


func is_confirming_quit() -> bool:
	return _quit_confirm_panel.visible


func _cancel_quit() -> void:
	_quit_confirm_panel.hide()
	_quit_button.grab_focus()


func _on_new_game_pressed() -> void:
	var first_room := Simulation.load_stage(Paths.STAGE_ORDER[0]).room_scene_path
	SceneRouter.goto_via_loading(Paths.NEW_GAME_SETUP, PackedStringArray([first_room, Paths.NEW_GAME_SETUP]))


func _on_continue_pressed() -> void:
	if SaveSystem.load_game():
		SceneRouter.goto_current_room()
	else:
		_continue_button.disabled = true

