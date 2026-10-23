class_name SettingsButton
extends CanvasLayer
## Botón flotante de engranaje (esquina inferior derecha) que abre el panel de Ajustes.
## Se instancia en el cuarto y en el dashboard. Mientras el panel está abierto el árbol queda en pausa,
## así que la simulación, la PC, el pincel y las mejoras no responden.

## Separación del borde de la pantalla (más la zona segura del celular).
const MARGIN := 20.0

@onready var _gear_button: Button = %GearButton
@onready var _menu: SettingsMenu = %SettingsMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gear_button.pressed.connect(open)
	_menu.closed.connect(_on_menu_closed)
	get_viewport().size_changed.connect(_place_button)
	_place_button()


func _exit_tree() -> void:
	# Si la escena cambia con el panel abierto, el juego no debe quedarse en pausa.
	if is_open():
		get_tree().paused = false


func _notification(what: int) -> void:
	# Botón "atrás" de Android: cierra el panel (o la confirmación); si está cerrado, lo abre.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if is_open():
			_menu.go_back()
		else:
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


func _on_menu_closed() -> void:
	get_tree().paused = false


## Coloca el engranaje respetando la zona segura (muesca, barra de gestos) en celulares.
func _place_button() -> void:
	var safe := _get_safe_insets()
	_gear_button.offset_right = -(MARGIN + safe.x)
	_gear_button.offset_bottom = -(MARGIN + safe.y)
	_gear_button.offset_left = _gear_button.offset_right - _gear_button.custom_minimum_size.x
	_gear_button.offset_top = _gear_button.offset_bottom - _gear_button.custom_minimum_size.y


## Espacio que ocupa el sistema a la derecha (x) y abajo (y), en coordenadas del viewport.
func _get_safe_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe_area := Rect2(DisplayServer.get_display_safe_area())
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return Vector2.ZERO
	var ratio := get_viewport().get_visible_rect().size / window_size
	return Vector2(screen_size.x - safe_area.end.x, screen_size.y - safe_area.end.y).max(Vector2.ZERO) * ratio
