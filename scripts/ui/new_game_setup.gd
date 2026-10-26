extends Control
## Flujo de partida nueva: paso 1 (elegir personaje) → paso 2 (nombre del avatar)
## → paso 3 (nombre de la empresa). Al confirmar crea la partida, la guarda y abre el cuarto.
## "Atrás" regresa al paso anterior conservando lo elegido; desde el paso 1, al título.

@onready var _character_select: CharacterSelect = %CharacterSelect
@onready var _avatar_prompt: NamePrompt = %AvatarPrompt
@onready var _company_prompt: NamePrompt = %CompanyPrompt


func _ready() -> void:
	_character_select.confirmed.connect(_on_character_confirmed)
	_character_select.back_requested.connect(_on_back_to_title)
	_avatar_prompt.confirmed.connect(_on_avatar_confirmed)
	_avatar_prompt.back_requested.connect(_show_step.bind(_character_select))
	_company_prompt.confirmed.connect(_on_company_confirmed)
	_company_prompt.back_requested.connect(_show_step.bind(_avatar_prompt))
	_show_step(_character_select)


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
	GameState.start_new_game(_avatar_prompt.get_value(), company_name, _character_select.get_selected_id())
	SaveSystem.save_game()
	SceneRouter.goto_current_room()


func _on_back_to_title() -> void:
	if not SceneRouter.is_changing():
		SceneRouter.goto(Paths.TITLE_MENU)
