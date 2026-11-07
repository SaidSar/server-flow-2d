extends Node
## Autoload "GameState": identidad de la partida en curso (personaje, nombres, colores de los cuartos
## y decoración).
## El progreso (etapa, oleada, monedas, mejoras) vive en Simulation.
## Las escenas leen de aquí y escuchan sus señales; no se hablan entre sí.

## Cambió el nombre del avatar o de la empresa.
signal changed
## Se cambió el color de una capa del cuarto.
signal color_changed(layer: StringName, option_id: StringName)
## Cambió el inventario de decoración o lo colocado en algún cuarto.
signal decor_changed
## Empezó una partida (nueva o cargada).
signal session_started

var is_active := false
## Personaje elegido (resources/avatars/<id>.tres).
var avatar_id: StringName = AvatarData.DEFAULT_ID
var avatar_name := ""
var company_name := ""
## Capa → id de color (ver Customization.get_all_layers()).
var colors: Dictionary[StringName, StringName] = {}
## Decoración comprada y guardada (un id por objeto; se repite si hay varios).
var decor_inventory: Array[StringName] = []
## Cuarto → objetos colocados: {id, ori, x, y} con (x, y) la esquina mínima de la huella en metros.
var decor_placed: Dictionary[StringName, Array] = {}

var _avatar: AvatarData


func start_new_game(new_avatar_name: String, new_company_name: String, new_avatar_id: StringName = AvatarData.DEFAULT_ID) -> void:
	_set_avatar(new_avatar_id)
	avatar_name = new_avatar_name
	company_name = new_company_name
	colors = Customization.sanitize_colors(Customization.DEFAULT_COLORS)
	decor_inventory.clear()
	decor_placed.clear()
	Simulation.new_game()
	_begin_session()


## Restaura la identidad de una partida guardada. Los valores inválidos se corrigen.
func restore(data: Dictionary) -> void:
	# Las partidas anteriores a la selección de personaje no traen avatar_id: son de Alex.
	_set_avatar(StringName(str(data.get("avatar_id", AvatarData.DEFAULT_ID))))
	avatar_name = str(data.get("avatar_name", ""))
	company_name = str(data.get("company_name", ""))
	var saved_colors: Dictionary = data.get("colors", {})
	colors = Customization.sanitize_colors(saved_colors)
	_restore_decor(data.get("decor_inventory", []), data.get("decor_placed", {}))
	_begin_session()


func end_session() -> void:
	is_active = false
	Simulation.end_session()


func to_save_data() -> Dictionary:
	return {
		"avatar_id": String(avatar_id),
		"avatar_name": avatar_name,
		"company_name": company_name,
		"colors": colors.duplicate(),
		"decor_inventory": decor_inventory.duplicate(),
		"decor_placed": decor_placed.duplicate(true),
	}


func get_avatar() -> AvatarData:
	if _avatar == null:
		_set_avatar(avatar_id)
	return _avatar


## "m" o "f", según el personaje (ver TextUtil).
func get_gender() -> String:
	return get_avatar().gender


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


#region Decoración

func get_placed_decor(room_id: StringName) -> Array:
	if not decor_placed.has(room_id):
		decor_placed[room_id] = []
	return decor_placed[room_id]


func place_decor(room_id: StringName, entry: Dictionary) -> void:
	get_placed_decor(room_id).append(entry)
	decor_changed.emit()


## Reemplaza un objeto colocado (al moverlo o girarlo).
func update_placed_decor(room_id: StringName, index: int, entry: Dictionary) -> void:
	get_placed_decor(room_id)[index] = entry
	decor_changed.emit()


func remove_placed_decor(room_id: StringName, index: int) -> Dictionary:
	var entry: Dictionary = get_placed_decor(room_id).pop_at(index)
	decor_changed.emit()
	return entry


func add_to_inventory(decor_id: StringName) -> void:
	decor_inventory.append(decor_id)
	decor_changed.emit()


func take_from_inventory(decor_id: StringName) -> bool:
	var index := decor_inventory.find(decor_id)
	if index < 0:
		return false
	decor_inventory.remove_at(index)
	decor_changed.emit()
	return true


func count_in_inventory(decor_id: StringName) -> int:
	return decor_inventory.count(decor_id)


## El inventario es del jugador, no del cuarto: lo colocado en otros cuartos (a los que ya no se
## regresa al pasar de etapa) vuelve al inventario. Devuelve cuántos objetos movió.
func collect_decor_from_other_rooms(current_room: StringName) -> int:
	var moved := 0
	for room_id: StringName in decor_placed.keys():
		if room_id == current_room:
			continue
		for entry: Dictionary in decor_placed[room_id]:
			decor_inventory.append(StringName(str(entry.get("id", ""))))
			moved += 1
		decor_placed.erase(room_id)
	if moved > 0:
		decor_changed.emit()
	return moved


## Cuántos tiene el jugador entre el inventario y lo colocado en todos los cuartos.
func count_owned(decor_id: StringName) -> int:
	var count := count_in_inventory(decor_id)
	for room_id: StringName in decor_placed:
		for entry: Dictionary in decor_placed[room_id]:
			if StringName(str(entry.get("id", ""))) == decor_id:
				count += 1
	return count


## Ids desconocidos se descartan; las partidas sin decoración empiezan vacías.
func _restore_decor(raw_inventory: Variant, raw_placed: Variant) -> void:
	decor_inventory.clear()
	decor_placed.clear()
	if raw_inventory is Array or raw_inventory is PackedStringArray:
		for decor_id: Variant in raw_inventory:
			if DecorData.find(StringName(str(decor_id))) != null:
				decor_inventory.append(StringName(str(decor_id)))
	if raw_placed is Dictionary:
		for room_id: Variant in raw_placed:
			var entries: Array = []
			if raw_placed[room_id] is Array:
				for entry: Variant in raw_placed[room_id]:
					if entry is Dictionary and DecorData.find(StringName(str((entry as Dictionary).get("id", "")))) != null:
						entries.append(_clean_entry(entry))
			decor_placed[StringName(str(room_id))] = entries


static func _clean_entry(entry: Dictionary) -> Dictionary:
	var clean := {
		"id": str(entry.get("id", "")),
		"ori": str(entry.get("ori", "")),
		"x": float(entry.get("x", 0.0)),
		"y": float(entry.get("y", 0.0)),
	}
	# Altura de los objetos de pared (dz); las partidas anteriores no la tienen y usan la altura base.
	if entry.has("dz"):
		clean["dz"] = float(entry["dz"])
	return clean

#endregion


## Un id desconocido se cambia por el personaje por defecto.
func _set_avatar(new_avatar_id: StringName) -> void:
	_avatar = AvatarData.find(new_avatar_id)
	if _avatar.id != new_avatar_id:
		push_warning("Personaje desconocido %s; se usa %s." % [new_avatar_id, _avatar.id])
	avatar_id = _avatar.id


func _begin_session() -> void:
	is_active = true
	session_started.emit()
	changed.emit()
