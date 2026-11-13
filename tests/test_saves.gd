extends SceneTree
## Partidas múltiples (v0.12.0): hasta 5 espacios, la partida 1 es el archivo de siempre, nombres únicos de empresa,
## "Continuar" abre la más reciente y la pantalla Partidas carga/borra con confirmación.
## Corre con una partida alterna: godot --headless --path . -s res://tests/test_saves.gd -- --save-path=user://test_saves.cfg

var _failures: PackedStringArray = []
var _save: Node
var _game_state: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_save = root.get_node("SaveSystem")
	_game_state = root.get_node("GameState")
	if _save.call("is_using_real_save"):
		printerr("test_saves: corre la prueba con una partida alterna, p. ej.: -- --save-path=user://test_saves.cfg")
		quit(1)
		return
	_save.call("delete_save")

	_test_paths()
	_test_slots()
	_test_names()
	await _test_last_and_continue()
	await _test_title_ui()

	_save.call("delete_save")
	_check(not _save.get("real_save_accessed"), "no se tocó la partida real")
	if _failures.is_empty():
		print("test_saves: OK")
		quit(0)
	else:
		for failure in _failures:
			printerr("FALLO: ", failure)
		quit(1)


func _make_game(company: String) -> void:
	_game_state.call("start_new_game", "Prueba", company)


## Crea una partida en el primer lugar libre, como hace el registro de una partida nueva.
func _new_slot(company: String) -> int:
	if not _save.call("begin_new_slot"):
		return 0
	_make_game(_save.call("make_unique_company_name", company))
	_save.call("save_game")
	return _save.get("current_slot")


func _test_paths() -> void:
	var base: String = _save.call("get_slot_path", 1)
	_check(base == _save.get("save_path") or _save.get("current_slot") != 1, "la partida 1 usa el archivo base")
	_check(_save.call("get_slot_path", 2) == base.get_basename() + "_2." + base.get_extension(), "la partida 2 va al lado: %s" % _save.call("get_slot_path", 2))
	_check(_save.call("get_slot_path", 5).ends_with("_5.cfg"), "la partida 5 termina en _5.cfg")
	_check(_save.call("count_saves") == 0 and not _save.call("has_any_save"), "empieza sin partidas")
	_check(_save.call("get_free_slot") == 1 and _save.call("get_last_slot") == 0, "sin partidas: lugar 1 libre y ninguna es la última")
	_check(not _save.call("continue_last"), "Continuar sin partidas no hace nada")


func _test_slots() -> void:
	for i in 5:
		var slot := _new_slot("Empresa %d" % (i + 1))
		_check(slot == i + 1, "la partida %d se guarda en el lugar %d (%d)" % [i + 1, i + 1, slot])
		_check(_save.call("slot_exists", i + 1), "existe el archivo de la partida %d" % (i + 1))
	_check(_save.call("count_saves") == 5, "hay 5 partidas")
	_check(_save.call("get_free_slot") == 0, "con 5 partidas no hay lugar libre")
	_check(not _save.call("begin_new_slot"), "no se crea una sexta partida")
	_check(_save.get("current_slot") == 5, "la sexta no cambió la partida en curso")
	var slots: Array = _save.call("get_slots")
	_check(slots.size() == 5 and slots[0]["company"] == "Empresa 1" and slots[4]["company"] == "Empresa 5", "la lista trae las 5 empresas en orden")
	_check(slots[0].has("stage") and slots[0].has("wave") and slots[0].has("coins"), "cada partida trae etapa, oleada y monedas")
	# Borrar una libera ese lugar (el primero libre es el hueco, no el final).
	_save.call("delete_slot", 3)
	_check(_save.call("count_saves") == 4 and not _save.call("slot_exists", 3), "borrar una quita solo esa")
	_check(_save.call("slot_exists", 2) and _save.call("slot_exists", 4), "las demás siguen")
	_check(_new_slot("Nueva") == 3, "la nueva ocupa el hueco que dejó la borrada")
	_save.call("delete_save")
	_check(_save.call("count_saves") == 0 and _save.get("current_slot") == 1, "delete_save borra todas y vuelve a la 1")


func _test_names() -> void:
	_check(_save.call("make_unique_company_name", "Mi empresa") == "Mi empresa", "sin repetir se queda igual")
	_check(_new_slot("Mi empresa") == 1, "primera partida")
	_check(_save.call("make_unique_company_name", "Mi empresa") == "Mi empresa 2", "repetido: Mi empresa 2")
	_check(_new_slot("Mi empresa") == 2 and _game_state.get("company_name") == "Mi empresa 2", "la segunda se llama Mi empresa 2")
	_check(_save.call("make_unique_company_name", "mi empresa") == "mi empresa 3", "no distingue mayúsculas y sigue con el 3")
	_check(_save.call("make_unique_company_name", "  Mi empresa  ") == "Mi empresa 3", "ignora espacios sobrantes")
	_save.call("delete_save")


func _test_last_and_continue() -> void:
	_new_slot("Primera")
	OS.delay_msec(1100)
	_new_slot("Segunda")
	_check(_save.call("get_last_slot") == 2, "la última partida es la jugada más recientemente")
	var last_flags: Array = []
	for info: Dictionary in _save.call("get_slots"):
		last_flags.append(info["is_last"])
	_check(last_flags == [false, true], "la lista marca solo la última")
	_game_state.call("end_session")
	_check(_save.call("continue_last") and _game_state.get("company_name") == "Segunda", "Continuar abre la última")
	# Cargar la primera y guardar la vuelve la más reciente.
	OS.delay_msec(1100)
	_check(_save.call("load_slot", 1) and _game_state.get("company_name") == "Primera" and _save.get("current_slot") == 1, "Cargar abre esa partida y la deja en curso")
	_save.call("save_game")
	_check(_save.call("get_last_slot") == 1, "al guardar, esa pasa a ser la última")
	_check(not _save.call("load_slot", 4), "cargar un lugar vacío no hace nada")
	# El autoguardado va solo a la partida en curso.
	var other_before := FileAccess.get_modified_time(_save.call("get_slot_path", 2))
	_game_state.set("company_name", "Primera editada")
	_save.call("save_game")
	_check(FileAccess.get_modified_time(_save.call("get_slot_path", 2)) == other_before, "guardar no toca las otras partidas")
	_save.call("load_slot", 2)
	_check(_game_state.get("company_name") == "Segunda", "la otra partida sigue intacta")
	_save.call("delete_save")
	await process_frame


## Pantalla de título: contador, límite de 5, Partidas, borrar con confirmación.
func _test_title_ui() -> void:
	_game_state.call("end_session")
	for i in 5:
		_new_slot("UI %d" % (i + 1))
	_game_state.call("end_session")
	var title := (load("res://scenes/ui/title_menu.tscn") as PackedScene).instantiate()
	root.add_child(title)
	await process_frame
	var new_button := title.get_node("%NewGameButton") as Button
	var continue_button := title.get_node("%ContinueButton") as Button
	var saves_button := title.get_node("%SavesButton") as Button
	_check(not continue_button.disabled, "Continuar activo con partidas")
	_check("5/5" in saves_button.text, "el botón Partidas muestra 5/5 (%s)" % saves_button.text)
	# Límite: Nueva partida avisa y no cambia de escena.
	new_button.pressed.emit()
	await process_frame
	var limit: Control = title.call("get_limit_dialog")
	_check(limit != null, "con 5 partidas Nueva partida avisa del límite")
	# Cerrar.
	(limit.call("get_button", &"cerrar") as Button).pressed.emit()
	await process_frame
	_check(title.call("get_limit_dialog") == null and not title.call("is_saves_open"), "Cerrar quita el aviso")
	# Ir a Partidas.
	new_button.pressed.emit()
	await process_frame
	((title.call("get_limit_dialog") as Control).call("get_button", &"partidas") as Button).pressed.emit()
	await process_frame
	_check(title.call("is_saves_open"), "Ir a Partidas abre la lista")
	var panel: Control = title.call("get_saves_panel")
	for slot in range(1, 6):
		_check(panel.call("get_load_button", slot) != null and (panel.call("get_delete_button", slot) as Button) != null, "la partida %d trae Cargar y Borrar" % slot)
	# Borrar: No no borra; Sí borra.
	(panel.call("get_delete_button", 3) as Button).pressed.emit()
	await process_frame
	_check(panel.call("is_confirming_delete"), "Borrar pregunta")
	var dialog: Control = panel.call("get_dialog")
	_check((dialog.call("get_button", &"no") as Button) != null and (dialog.call("get_button", &"si") as Button) != null, "la pregunta trae No y Sí")
	_check((dialog.call("get_button", &"no") as Button).has_focus(), "No es el botón por defecto")
	(dialog.call("get_button", &"no") as Button).pressed.emit()
	await process_frame
	_check(not panel.call("is_confirming_delete") and _save.call("count_saves") == 5, "No no borra nada")
	(panel.call("get_delete_button", 3) as Button).pressed.emit()
	await process_frame
	(panel.call("get_dialog") as Control).emit_signal("chosen", &"cancel")
	await process_frame
	_check(not panel.call("is_confirming_delete") and _save.call("count_saves") == 5, "tocar fuera cancela sin borrar")
	(panel.call("get_delete_button", 3) as Button).pressed.emit()
	await process_frame
	((panel.call("get_dialog") as Control).call("get_button", &"si") as Button).pressed.emit()
	await process_frame
	await process_frame
	_check(_save.call("count_saves") == 4 and not _save.call("slot_exists", 3), "Sí borra esa partida")
	_check(panel.call("get_load_button", 3) == null and panel.call("get_load_button", 4) != null, "la lista se actualiza")
	_check("4/5" in saves_button.text, "el contador baja a 4/5 (%s)" % saves_button.text)
	# Ya hay lugar: Nueva partida deja de avisar del límite.
	panel.call("close")
	await process_frame
	_check(not title.call("is_saves_open"), "Cerrar regresa al menú")
	# Atrás de Android cierra Partidas.
	title.call("open_saves")
	title.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	_check(not title.call("is_saves_open"), "atrás cierra Partidas")
	# Sin partidas: Continuar apagado.
	for slot in range(1, 6):
		_save.call("delete_slot", slot)
	title.call("_refresh_saves")
	_check(continue_button.disabled and saves_button.text == "Partidas", "sin partidas Continuar está apagado y Partidas sin contador")
	title.queue_free()
	await process_frame


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
