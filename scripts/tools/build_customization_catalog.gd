extends SceneTree
## Regenera resources/customization/customization_catalog.tres a partir de paleta.json.
## Uso: godot --headless --path . -s res://scripts/tools/build_customization_catalog.gd


func _initialize() -> void:
	var catalog := CustomizationCatalog.from_palette_json(Paths.PALETTE_JSON)
	var error := ResourceSaver.save(catalog, Paths.CUSTOMIZATION_CATALOG)
	if error != OK:
		push_error("No se pudo guardar el catálogo: %s" % error_string(error))
		quit(1)
		return
	print("Catálogo generado en %s (paredes: %d, pisos: %d, puertas: %d, mesas: %d)" % [
		Paths.CUSTOMIZATION_CATALOG,
		catalog.walls.size(),
		catalog.floors.size(),
		catalog.doors.size(),
		catalog.desks.size(),
	])
	quit(0)
