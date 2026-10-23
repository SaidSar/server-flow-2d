extends Control
## Flujo de partida nueva: ventana 1 (nombre del avatar) → ventana 2 (nombre de la empresa).
## Al confirmar crea la partida, la guarda y abre el cuarto.

@onready var _avatar_prompt: NamePrompt = %AvatarPrompt
@onready var _company_prompt: NamePrompt = %CompanyPrompt


func _ready() -> void:
	_avatar_prompt.confirmed.connect(_on_avatar_confirmed)
	_company_prompt.confirmed.connect(_on_company_confirmed)
	_company_prompt.back_requested.connect(_show_avatar_prompt)
	_show_avatar_prompt()


func _show_avatar_prompt() -> void:
	_company_prompt.hide()
	_avatar_prompt.show()


func _on_avatar_confirmed(_avatar_name: String) -> void:
	_avatar_prompt.hide()
	_company_prompt.show()


func _on_company_confirmed(company_name: String) -> void:
	if SceneRouter.is_changing():
		return
	GameState.start_new_game(_avatar_prompt.get_value(), company_name)
	SaveSystem.save_game()
	SceneRouter.goto_current_room()
