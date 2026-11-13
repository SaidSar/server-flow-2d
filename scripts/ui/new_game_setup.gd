extends Control
## Flujo de partida nueva: paso 1 (elegir personaje) → paso 2 (nombre del avatar)
## → paso 3 (nombre de la empresa). Al confirmar crea la partida, la guarda y abre el cuarto.
## "Atrás" regresa al paso anterior conservando lo elegido; desde el paso 1, al título.

@onready var _character_select: CharacterSelect = %CharacterSelect
@onready var _avatar_prompt: NamePrompt = %AvatarPrompt
@onready var _company_prompt: NamePrompt = %CompanyPrompt
@onready var _center: CenterContainer = %Center

## Alto del teclado del teléfono en pantalla, en unidades del viewport (0 = cerrado).
var _keyboard_height := 0.0


func _ready() -> void:
	_character_select.confirmed.connect(_on_character_confirmed)
	_character_select.back_requested.connect(_on_back_to_title)
	_avatar_prompt.confirmed.connect(_on_avatar_confirmed)
	_avatar_prompt.back_requested.connect(_show_step.bind(_character_select))
	_company_prompt.confirmed.connect(_on_company_confirmed)
	_company_prompt.back_requested.connect(_show_step.bind(_avatar_prompt))
	# La escala se reduce desde el centro de la ventana, así que el pivote sigue a su tamaño.
	for prompt: NamePrompt in [_avatar_prompt, _company_prompt]:
		prompt.resized.connect(func() -> void: prompt.pivot_offset = prompt.size * 0.5)
	_show_step(_character_select)


func _process(_delta: float) -> void:
	var window_height := float(DisplayServer.window_get_size().y)
	if window_height <= 0.0:
		return
	var ratio := get_viewport().get_visible_rect().size.y / window_height
	var height := float(DisplayServer.virtual_keyboard_get_height()) * ratio
	if not is_equal_approx(height, _keyboard_height):
		apply_keyboard_height(height)


## El teclado en pantalla tapa la parte baja: la ventana de nombre se compacta y se centra en lo que queda libre.
func apply_keyboard_height(height: float) -> void:
	_keyboard_height = maxf(height, 0.0)
	var open := _keyboard_height > 0.0
	_center.offset_bottom = -_keyboard_height
	for prompt: NamePrompt in [_avatar_prompt, _company_prompt]:
		prompt.set_compact(open)
		_fit_prompt(prompt)


## Si aun compacta no cabe sobre el teclado, se reduce para que se vean el campo y los botones.
func _fit_prompt(prompt: NamePrompt) -> void:
	prompt.pivot_offset = prompt.size * 0.5
	var free_height := _center.size.y
	var needed := prompt.get_combined_minimum_size().y
	var factor := minf(1.0, free_height * 0.96 / maxf(needed, 1.0)) if _keyboard_height > 0.0 else 1.0
	prompt.scale = Vector2(factor, factor)


func _show_step(step: Control) -> void:
	for panel: Control in [_character_select, _avatar_prompt, _company_prompt]:
		panel.visible = panel == step


func _on_character_confirmed(avatar_id: StringName) -> void:
	_avatar_prompt.set_placeholder(AvatarData.find(avatar_id).display_name)
	_show_step(_avatar_prompt)


func _on_avatar_confirmed(_avatar_name: String) -> void:
	_show_step(_company_prompt)


func _on_company_confirmed(company_name: String) -> void:
	if SceneRouter.is_changing():
		return
	# La partida nueva va al primer lugar libre y su empresa no repite el nombre de otra guardada ("Mi empresa 2").
	if not SaveSystem.begin_new_slot():
		SceneRouter.goto(Paths.TITLE_MENU)
		return
	GameState.start_new_game(_avatar_prompt.get_value(), SaveSystem.make_unique_company_name(company_name), _character_select.get_selected_id())
	SaveSystem.save_game()
	SceneRouter.goto_current_room()


func _on_back_to_title() -> void:
	if not SceneRouter.is_changing():
		SceneRouter.goto(Paths.TITLE_MENU)
