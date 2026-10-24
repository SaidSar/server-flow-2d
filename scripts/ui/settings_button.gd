class_name SettingsButton
extends CanvasLayer
## Botón flotante de engranaje (esquina inferior derecha) que abre el panel de Ajustes.
## Se instancia en el cuarto y en el dashboard. Mientras el panel está abierto el árbol queda en pausa,
## así que la simulación, la PC, el pincel y las mejoras no responden.
## En el celular también atiende el botón "atrás" y la salida de la app (ir al inicio).

## Separación del borde de la pantalla (más la zona segura del celular).
const MARGIN := 20.0

@onready var _gear_button: Button = %GearButton
@onready var _menu: SettingsMenu = %SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gear_button.pressed.connect(open)
	_menu.closed.connect(_on_menu_closed)
	SceneRouter.safe_area_changed.connect(_place_button)
	_place_button()


func _exit_tree() -> void:
	# Si la escena cambia con el panel abierto, el juego no debe quedarse en pausa.
	if is_open():
		get_tree().paused = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_go_back()
		NOTIFICATION_APPLICATION_PAUSED:
			# La app pasa a segundo plano (botón de inicio): guarda y deja el juego en pausa con Ajustes
			# abierto, para que al volver el jugador decida cuándo seguir.
			SaveSystem.save_game()
			open()


func open() -> void:
	if is_open() or SceneRouter.is_changing():
		return
	get_tree().paused = true
	_menu.open()


func close() -> void:
	_menu.close()


func is_open() -> bool:
	return _menu.visible


## Botón "atrás" de Android: primero cierra lo que esté abierto (paneles, fichas, confirmaciones)
## mandando ui_cancel, igual que Esc. Si nadie lo usa, guarda y abre Ajustes en pausa.
func _on_go_back() -> void:
	if is_open():
		_menu.go_back()
		return
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	get_viewport().push_input(cancel)
	if not get_viewport().is_input_handled():
		SaveSystem.save_game()
		open()


func _on_menu_closed() -> void:
	get_tree().paused = false


## Coloca el engranaje respetando la zona segura (cámara, barra de gestos) en celulares.
func _place_button() -> void:
	var insets := SafeArea.get_insets(get_viewport())
	_gear_button.offset_right = -(MARGIN + insets.z)
	_gear_button.offset_bottom = -(MARGIN + insets.w)
	_gear_button.offset_left = _gear_button.offset_right - _gear_button.custom_minimum_size.x
	_gear_button.offset_top = _gear_button.offset_bottom - _gear_button.custom_minimum_size.y
