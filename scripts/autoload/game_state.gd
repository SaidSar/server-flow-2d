extends Node
## Autoload "GameState": identidad de la partida en curso (avatar, empresa y colores del cuarto).
## El progreso (etapa, oleada, monedas, mejoras) vive en Simulation.
## Las escenas leen de aquí y escuchan sus señales; no se hablan entre sí.

## Cambió el nombre del avatar o de la empresa.
signal changed
## Se cambió el color de una capa del cuarto.
signal color_changed(layer: StringName, option_id: StringName)
## Empezó una partida (nueva o cargada).
signal session_started

var is_active := false
var avatar_name := ""
var company_name := ""
## Capa → id de color (ver Customization.LAYER_ORDER).
var colors: Dictionary[StringName, StringName] = {}


func start_new_game(new_avatar_name: String, new_company_name: String) -> void:
	avatar_name = new_avatar_name
	company_name = new_company_name
	colors = Customization.sanitize_colors(Customization.DEFAULT_COLORS)
	Simulation.new_game()
	_begin_session()


## Restaura la identidad de una partida guardada. Los valores inválidos se corrigen.
func restore(data: Dictionary) -> void:
	avatar_name = str(data.get("avatar_name", ""))
	company_name = str(data.get("company_name", ""))
	var saved_colors: Dictionary = data.get("colors", {})
	colors = Customization.sanitize_colors(saved_colors)
	_begin_session()


func end_session() -> void:
	is_active = false
	Simulation.end_session()


func to_save_data() -> Dictionary:
	return {
		"avatar_name": avatar_name,
		"company_name": company_name,
		"colors": colors.duplicate(),
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


func _begin_session() -> void:
	is_active = true
	session_started.emit()
	changed.emit()
