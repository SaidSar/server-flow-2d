extends Node
## Autoload "GameState": datos de la partida en curso.
## Las escenas leen de aquí y escuchan sus señales; no se hablan entre sí.

## Algún dato del HUD cambió (monedas, usuarios, nombres...).
signal changed
## Se cambió el color de una capa del cuarto.
signal color_changed(layer: StringName, option_id: StringName)
## Empezó una partida (nueva o cargada).
signal session_started

const DEFAULT_STAGE: StringName = &"startup"

var is_active := false
var avatar_name := ""
var company_name := ""
## Capa → id de color (ver Customization.LAYER_ORDER).
var colors: Dictionary[StringName, StringName] = {}
var stage: StringName = DEFAULT_STAGE
var wave := 1
var coins := 0
var users := 0


func start_new_game(new_avatar_name: String, new_company_name: String) -> void:
	avatar_name = new_avatar_name
	company_name = new_company_name
	stage = DEFAULT_STAGE
	wave = 1
	coins = get_stage_data().starting_coins
	colors = Customization.sanitize_colors(Customization.DEFAULT_COLORS)
	_begin_session()


## Restaura una partida guardada. Los valores inválidos se corrigen.
func restore(data: Dictionary) -> void:
	avatar_name = str(data.get("avatar_name", ""))
	company_name = str(data.get("company_name", ""))
	var stage_id := StringName(str(data.get("stage", DEFAULT_STAGE)))
	stage = stage_id if Paths.STAGES.has(stage_id) else DEFAULT_STAGE
	wave = clampi(int(data.get("wave", 1)), 1, get_stage_data().wave_count)
	coins = maxi(int(data.get("coins", 0)), 0)
	var saved_colors: Dictionary = data.get("colors", {})
	colors = Customization.sanitize_colors(saved_colors)
	_begin_session()


func to_save_data() -> Dictionary:
	return {
		"avatar_name": avatar_name,
		"company_name": company_name,
		"colors": colors.duplicate(),
		"stage": stage,
		"wave": wave,
		"coins": coins,
	}


func get_color(layer: StringName) -> StringName:
	return colors.get(layer, Customization.get_default_option(layer))


func set_color(layer: StringName, option_id: StringName) -> void:
	if not Customization.is_valid_option(layer, option_id):
		push_warning("Color inválido %s/%s" % [layer, option_id])
		return
	if colors.get(layer, &"") == option_id:
		return
	colors[layer] = option_id
	color_changed.emit(layer, option_id)


func apply_colors(new_colors: Dictionary[StringName, StringName]) -> void:
	for layer: StringName in new_colors:
		set_color(layer, new_colors[layer])


func add_coins(amount: int) -> void:
	if amount == 0:
		return
	coins = maxi(coins + amount, 0)
	changed.emit()


## Datos de una etapa; sin argumento, la etapa actual.
func get_stage_data(stage_id: StringName = &"") -> StageData:
	var id := stage if stage_id == &"" else stage_id
	var path: String = Paths.STAGES.get(id, Paths.STAGES[DEFAULT_STAGE])
	return load(path) as StageData


func _begin_session() -> void:
	users = get_stage_data().starting_users
	is_active = true
	session_started.emit()
	changed.emit()
