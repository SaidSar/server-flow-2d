extends Control
## Menú de título: Nueva partida, Continuar (la última partida jugada), Partidas (hasta 5: cargar o borrar), Opciones y Salir.
## Con 5 partidas, Nueva partida avisa del límite y ofrece ir a Partidas.
## Salir (botón o "atrás" de Android) pide confirmación antes de cerrar el juego.
## Opciones abre el mismo panel de ajustes del engranaje (SettingsMenu), fuera de una partida.

@onready var _new_game_button: Button = %NewGameButton
@onready var _continue_button: Button = %ContinueButton
@onready var _saves_button: Button = %SavesButton
@onready var _options_button: Button = %OptionsButton
@onready var _quit_button: Button = %QuitButton
@onready var _options_panel: SettingsMenu = %OptionsPanel
@onready var _quit_confirm_panel: Control = %QuitConfirmPanel
@onready var _confirm_quit_button: Button = %ConfirmQuitButton
@onready var _cancel_quit_button: Button = %CancelQuitButton


@export var icono_escena: PackedScene  # IconoParticula.tscn
var tiempo_entre_iconos: float = .75
var tiempo_acumulado: float = 0.0
var _saves_panel: SavesPanel
var _limit_dialog: ConfirmDialog


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
	_saves_panel = SavesPanel.new()
	_saves_panel.name = "SavesPanel"
	add_child(_saves_panel)
	_saves_panel.closed.connect(_on_saves_closed)
	_saves_panel.load_requested.connect(_on_load_requested)
	_saves_panel.saves_changed.connect(_refresh_saves)
	_refresh_saves()
	_quit_confirm_panel.hide()

	_new_game_button.pressed.connect(_on_new_game_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	_saves_button.pressed.connect(open_saves)
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
	if _limit_dialog != null:
		_close_limit_dialog()
	elif _saves_panel.visible:
		_saves_panel.go_back()
	elif _quit_confirm_panel.visible:
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


## Continuar y el contador de Partidas según las partidas guardadas.
func _refresh_saves() -> void:
	var count := SaveSystem.count_saves()
	_continue_button.disabled = count == 0
	_saves_button.text = "Partidas  %d/%d" % [count, SaveSystem.MAX_SLOTS] if count > 0 else "Partidas"


func open_saves() -> void:
	_saves_panel.open()


func is_saves_open() -> bool:
	return _saves_panel.visible


func get_saves_panel() -> SavesPanel:
	return _saves_panel


func get_limit_dialog() -> ConfirmDialog:
	return _limit_dialog


func _on_saves_closed() -> void:
	_refresh_saves()
	_saves_button.grab_focus()


func _on_load_requested(slot: int) -> void:
	if SceneRouter.is_changing():
		return
	if SaveSystem.load_slot(slot):
		SceneRouter.goto_current_room()
	else:
		_refresh_saves()


## Con el máximo de partidas no se crea otra: avisa y ofrece ir a Partidas a borrar una.
func _show_limit_dialog() -> void:
	if _limit_dialog != null:
		return
	var options: Array[Dictionary] = [{"id": &"cerrar", "text": "Cerrar"}, {"id": &"partidas", "text": "Ir a Partidas"}]
	_limit_dialog = ConfirmDialog.create("Tienes %d partidas" % SaveSystem.MAX_SLOTS, "Borra una en Partidas para crear una nueva.", options, 0)
	_limit_dialog.chosen.connect(_on_limit_chosen)
	add_child(_limit_dialog)


func _on_limit_chosen(id: StringName) -> void:
	_close_limit_dialog()
	if id == &"partidas":
		open_saves()


func _close_limit_dialog() -> void:
	if _limit_dialog != null:
		_limit_dialog.queue_free()
		remove_child(_limit_dialog)
		_limit_dialog = null
	_new_game_button.grab_focus()


func _on_new_game_pressed() -> void:
	if SaveSystem.count_saves() >= SaveSystem.MAX_SLOTS:
		_show_limit_dialog()
		return
	var first_room := Simulation.load_stage(Paths.STAGE_ORDER[0]).room_scene_path
	SceneRouter.goto_via_loading(Paths.NEW_GAME_SETUP, PackedStringArray([first_room, Paths.NEW_GAME_SETUP]))


func _on_continue_pressed() -> void:
	if SaveSystem.continue_last():
		SceneRouter.goto_current_room()
	else:
		_refresh_saves()

