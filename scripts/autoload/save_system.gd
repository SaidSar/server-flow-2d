extends Node
## Autoload "SaveSystem": guarda y carga la partida en un ConfigFile.
## Guarda la identidad (GameState: personaje, nombres, colores y decoración) y el checkpoint de Simulation: etapa, oleada, monedas,
## niveles de mejoras, disco usado, usuarios atendidos y estadísticas por etapa.
## El checkpoint es el inicio de la oleada en curso, así que "Continuar" vuelve a ese punto.
## Ruta alterna (pruebas, mediciones y partidas de prueba): argumento "--save-path=<ruta>" después
## de "--", variable de entorno SERVERFLOW_SAVE_PATH o, solo en builds debug, el archivo
## user://save_path_override.txt (en Android la app no recibe argumentos: se escribe con adb run-as).
## Así nunca se toca la partida real.
## Partidas múltiples (v0.12.0): hasta MAX_SLOTS partidas. La partida 1 es el archivo de siempre (user://savegame.cfg o la ruta
## alterna), así que las partidas anteriores no se migran ni se mueven; las demás son <nombre>_2.cfg … <nombre>_5.cfg
## al lado de la primera. `save_path` es el archivo de la partida en curso (current_slot).

signal saved

## 3: agrega player/avatar_id (las partidas sin él son de Alex).
## 8: pets/owned (mascotas compradas, un id por mascota). Las partidas anteriores no lo traen y empiezan sin mascotas.
## 7: colors/camiseta (color de la camiseta) y customization/unlocked (opciones de pago compradas: colores pastel y
##    texturas). Las partidas anteriores no los traen: camiseta original y nada desbloqueado.
## 6: player/tutorial_step (paso del tutorial; -1 = terminado). Las partidas anteriores no lo traen y no ven el tutorial.
## 5: decoración inicial entregada por cuarto (decor/initial_granted). Las partidas anteriores no la traen
##    y reciben las ventanas de la oficina al entrar a ella.
## 4: piso por cuarto (colors/piso_<cuarto>) y decoración (sección "decor"). Las partidas
##    anteriores migran su "piso" al garage y empiezan sin decoración.
const SAVE_VERSION := 8
## Partidas guardadas que se pueden tener a la vez.
const MAX_SLOTS := 5
const SECTION_META := "meta"
const SECTION_PLAYER := "player"
const SECTION_COLORS := "colors"
const SECTION_PROGRESS := "progress"
const SECTION_DECOR := "decor"
const SECTION_CUSTOMIZATION := "customization"
const SECTION_PETS := "pets"
const SAVE_PATH_ARG := "--save-path="
const SAVE_PATH_ENV := "SERVERFLOW_SAVE_PATH"
const SAVE_PATH_OVERRIDE_FILE := "user://save_path_override.txt"

var save_path := Paths.SAVE_FILE
## Partida en curso (1 a MAX_SLOTS): la que guardan los autoguardados y carga "Continuar".
var current_slot := 1
## Archivo de la partida 1 (la ruta real o la alterna); las demás partidas salen de él.
var _base_path := Paths.SAVE_FILE
## true si algo leyó o escribió la partida real (Paths.SAVE_FILE). Las pruebas lo revisan.
var real_save_accessed := false


func _ready() -> void:
	_base_path = get_alternate_save_path()
	if _base_path.is_empty():
		_base_path = Paths.SAVE_FILE
	elif OS.is_debug_build():
		print("[SaveSystem] Ruta alterna de guardado: %s" % _base_path)
	select_slot(1)
	# Guardado automático al empezar y al terminar cada oleada (y al pasar de etapa).
	Simulation.checkpoint_created.connect(_on_checkpoint_created)


func _notification(what: int) -> void:
	# Guardado automático al cerrar la ventana (Windows) o al mandar la app a segundo plano (Android).
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


## Ruta alterna pedida por argumento, variable de entorno o archivo de override ("" si no hay).
static func get_alternate_save_path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(SAVE_PATH_ARG):
			return arg.trim_prefix(SAVE_PATH_ARG)
	var from_env := OS.get_environment(SAVE_PATH_ENV)
	if not from_env.is_empty():
		return from_env
	# Un jugador nunca tiene este archivo; en release se ignora por si acaso.
	if OS.is_debug_build() and FileAccess.file_exists(SAVE_PATH_OVERRIDE_FILE):
		return FileAccess.get_file_as_string(SAVE_PATH_OVERRIDE_FILE).strip_edges()
	return ""


func is_using_real_save() -> bool:
	return ProjectSettings.globalize_path(_base_path) == ProjectSettings.globalize_path(Paths.SAVE_FILE)


## ¿Existe el archivo de la partida en curso?
func has_save() -> bool:
	_note_access()
	return FileAccess.file_exists(save_path)


#region Partidas

## Archivo de una partida: la 1 es el archivo base; la n, "<base>_n.<ext>" al lado.
func get_slot_path(slot: int) -> String:
	if slot <= 1:
		return _base_path
	return "%s_%d.%s" % [_base_path.get_basename(), slot, _base_path.get_extension()]


func slot_exists(slot: int) -> bool:
	_note_access()
	return slot >= 1 and slot <= MAX_SLOTS and FileAccess.file_exists(get_slot_path(slot))


## Deja la partida `slot` como la en curso (cambia el archivo donde se guarda). No carga nada.
func select_slot(slot: int) -> void:
	current_slot = clampi(slot, 1, MAX_SLOTS)
	save_path = get_slot_path(current_slot)


func count_saves() -> int:
	var total := 0
	for slot in range(1, MAX_SLOTS + 1):
		if slot_exists(slot):
			total += 1
	return total


func has_any_save() -> bool:
	return count_saves() > 0


## Primer lugar libre (1 a MAX_SLOTS); 0 si ya están todos ocupados.
func get_free_slot() -> int:
	for slot in range(1, MAX_SLOTS + 1):
		if not slot_exists(slot):
			return slot
	return 0


## Partida jugada más recientemente (por la fecha de su archivo); 0 si no hay ninguna.
func get_last_slot() -> int:
	var best := 0
	var best_time := -1
	for slot in range(1, MAX_SLOTS + 1):
		if not slot_exists(slot):
			continue
		var modified := int(FileAccess.get_modified_time(get_slot_path(slot)))
		if modified > best_time:
			best = slot
			best_time = modified
	return best


## Resumen de cada partida existente para la lista: slot, empresa, avatar, etapa, oleada, monedas y fecha.
func get_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var last := get_last_slot()
	for slot in range(1, MAX_SLOTS + 1):
		if not slot_exists(slot):
			continue
		var config := ConfigFile.new()
		if config.load(get_slot_path(slot)) != OK:
			continue
		result.append({
			"slot": slot,
			"company": str(config.get_value(SECTION_PLAYER, "company_name", "")),
			"avatar_name": str(config.get_value(SECTION_PLAYER, "avatar_name", "")),
			"stage": str(config.get_value(SECTION_PROGRESS, "stage", String(Paths.STAGE_ORDER[0]))),
			"wave": int(config.get_value(SECTION_PROGRESS, "wave", 1)),
			"coins": int(config.get_value(SECTION_PROGRESS, "coins", 0)),
			"modified": int(FileAccess.get_modified_time(get_slot_path(slot))),
			"is_last": slot == last,
		})
	return result


## Prepara una partida nueva en el primer lugar libre. false si ya hay MAX_SLOTS (no se crea nada).
func begin_new_slot() -> bool:
	var free := get_free_slot()
	if free == 0:
		return false
	select_slot(free)
	return true


## Nombre de empresa que no se repita entre las partidas guardadas: "Mi empresa", "Mi empresa 2", "Mi empresa 3"…
func make_unique_company_name(wanted: String) -> String:
	var base := wanted.strip_edges()
	var taken: Array[String] = []
	for info: Dictionary in get_slots():
		taken.append(String(info["company"]).to_lower())
	if not taken.has(base.to_lower()):
		return base
	var n := 2
	while taken.has(("%s %d" % [base, n]).to_lower()):
		n += 1
	return "%s %d" % [base, n]


## Carga la partida más reciente ("Continuar"). false si no hay o está dañada.
func continue_last() -> bool:
	var slot := get_last_slot()
	return slot > 0 and load_slot(slot)


func load_slot(slot: int) -> bool:
	if not slot_exists(slot):
		return false
	select_slot(slot)
	return load_game()


func delete_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(get_slot_path(slot)))

#endregion


func save_game() -> bool:
	if not GameState.is_active or not Simulation.has_session():
		return false
	_note_access()

	var data := GameState.to_save_data()
	var config := ConfigFile.new()
	config.set_value(SECTION_META, "version", SAVE_VERSION)
	config.set_value(SECTION_PLAYER, "avatar_id", data["avatar_id"])
	config.set_value(SECTION_PLAYER, "avatar_name", data["avatar_name"])
	config.set_value(SECTION_PLAYER, "company_name", data["company_name"])
	config.set_value(SECTION_PLAYER, "tutorial_step", data["tutorial_step"])
	var colors: Dictionary = data["colors"]
	for layer: StringName in colors:
		config.set_value(SECTION_COLORS, layer, String(colors[layer]))
	var inventory := PackedStringArray()
	for decor_id: StringName in data["decor_inventory"]:
		inventory.append(String(decor_id))
	var unlocked := PackedStringArray()
	for option_id: StringName in data["unlocked_options"]:
		unlocked.append(String(option_id))
	config.set_value(SECTION_CUSTOMIZATION, "unlocked", unlocked)
	var owned_pets := PackedStringArray()
	for pet_id: StringName in data["pets"]:
		owned_pets.append(String(pet_id))
	config.set_value(SECTION_PETS, "owned", owned_pets)
	config.set_value(SECTION_DECOR, "inventory", inventory)
	var granted := PackedStringArray()
	for room_id: StringName in data["decor_initial_granted"]:
		granted.append(String(room_id))
	config.set_value(SECTION_DECOR, "initial_granted", granted)
	var placed: Dictionary = data["decor_placed"]
	for room_id: StringName in placed:
		config.set_value(SECTION_DECOR, "placed_" + room_id, placed[room_id])
	var progress := Simulation.get_checkpoint()
	for key: String in progress:
		config.set_value(SECTION_PROGRESS, key, progress[key])

	var error := config.save(save_path)
	if error != OK:
		push_error("No se pudo guardar la partida en %s: %s" % [save_path, error_string(error)])
		return false
	saved.emit()
	return true


## Carga la partida guardada. Devuelve false si no hay o está dañada.
func load_game() -> bool:
	_note_access()
	var config := ConfigFile.new()
	var error := config.load(save_path)
	if error != OK:
		push_warning("No se pudo cargar la partida de %s: %s" % [save_path, error_string(error)])
		return false

	var colors: Dictionary = {}
	if config.has_section(SECTION_COLORS):
		for key: String in config.get_section_keys(SECTION_COLORS):
			colors[StringName(key)] = StringName(str(config.get_value(SECTION_COLORS, key, "")))
	var decor_placed: Dictionary = {}
	if config.has_section(SECTION_DECOR):
		for key: String in config.get_section_keys(SECTION_DECOR):
			if key.begins_with("placed_"):
				decor_placed[key.trim_prefix("placed_")] = config.get_value(SECTION_DECOR, key, [])
	var progress: Dictionary = {}
	if config.has_section(SECTION_PROGRESS):
		for key: String in config.get_section_keys(SECTION_PROGRESS):
			progress[key] = config.get_value(SECTION_PROGRESS, key)

	GameState.restore({
		"avatar_id": config.get_value(SECTION_PLAYER, "avatar_id", String(AvatarData.DEFAULT_ID)),
		"avatar_name": config.get_value(SECTION_PLAYER, "avatar_name", ""),
		"company_name": config.get_value(SECTION_PLAYER, "company_name", ""),
		"tutorial_step": config.get_value(SECTION_PLAYER, "tutorial_step", GameState.TUTORIAL_DONE),
		"colors": colors,
		"unlocked_options": config.get_value(SECTION_CUSTOMIZATION, "unlocked", PackedStringArray()),
		"pets": config.get_value(SECTION_PETS, "owned", PackedStringArray()),
		"decor_inventory": config.get_value(SECTION_DECOR, "inventory", PackedStringArray()),
		"decor_placed": decor_placed,
		"decor_initial_granted": config.get_value(SECTION_DECOR, "initial_granted", PackedStringArray()),
	})
	Simulation.load_checkpoint(progress)
	return true


## Borra TODAS las partidas (las pruebas empiezan siempre de cero). Para borrar una sola: delete_slot.
func delete_save() -> void:
	_note_access()
	for slot in range(1, MAX_SLOTS + 1):
		delete_slot(slot)
	select_slot(1)


func _note_access() -> void:
	if is_using_real_save():
		real_save_accessed = true


func _on_checkpoint_created() -> void:
	save_game()
