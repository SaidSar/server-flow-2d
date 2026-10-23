class_name Paths
extends RefCounted
## Rutas del proyecto en un solo lugar.
## El código no debe escribir rutas res:// o user:// a mano: agrégalas aquí.

# Escenas
const MAIN := "res://scenes/main/main.tscn"
const TITLE_MENU := "res://scenes/ui/title_menu.tscn"
const LOADING_SCREEN := "res://scenes/ui/loading_screen.tscn"
const NEW_GAME_SETUP := "res://scenes/ui/new_game_setup.tscn"
const DASHBOARD := "res://scenes/dashboard/dashboard.tscn"

# Datos y recursos
const PALETTE_JSON := "res://data/customization/paleta.json"
const CUSTOMIZATION_CATALOG := "res://resources/customization/customization_catalog.tres"
const SIMULATION_CONFIG := "res://resources/simulation/simulation_config.tres"
## Mejora por id: resources/upgrades/<id>.tres
const UPGRADE := "res://resources/upgrades/%s.tres"
## Etapas en orden de juego.
const STAGE_ORDER: Array[StringName] = [&"startup", &"scale_up", &"enterprise"]
const STAGES := {
	&"startup": "res://resources/stages/startup.tres",
	&"scale_up": "res://resources/stages/scale_up.tres",
	&"enterprise": "res://resources/stages/enterprise.tres",
}

## Textura de una capa personalizable: rooms/<cuarto>/<capa>/<id>.png
const ROOM_LAYER_TEXTURE := "res://assets/art/rooms/%s/%s/%s.png"

# Guardado
const SAVE_FILE := "user://savegame.cfg"
