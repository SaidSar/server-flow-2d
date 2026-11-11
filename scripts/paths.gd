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
## Posición de cada capa recortada en el lienzo 2x del cuarto.
const LAYER_OFFSETS_JSON := "res://data/customization/layer_offsets.json"
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

## Personajes elegibles: resources/avatars/<id>.tres
const AVATARS_DIR := "res://resources/avatars"
const AVATAR := "res://resources/avatars/%s.tres"
## Patrones repetibles de paredes y pisos: assets/art/texturas/<id>.png (256 px = 1 m).
const PATTERN_TEXTURE := "res://assets/art/texturas/%s.png"
const PETS_JSON := "res://data/pets/mascotas.json"
const PET_SHEET := "res://assets/art/mascotas/%s.png"
const BACKDROP_TEXTURE := "res://assets/art/fondos/%s.png"
## Shader que recolorea o estampa un patrón sobre el render de una pared o piso.
const SURFACE_SHADER := "res://assets/shaders/superficie.gdshader"
## Shader que recolorea la sudadera/camiseta del avatar.
const SHIRT_SHADER := "res://assets/shaders/camiseta.gdshader"
## Retrato de Briseida (la CEO) para sus diálogos: PNG con fondo transparente.
const CEO_PORTRAIT := "res://assets/art/characters/briseida/briseida_retrato.png"
## Busto de Briseida (cintura para arriba) del tutorial: briseida_busto_<expresión>.png, 533×800, fondo transparente.
const CEO_BUST := "res://assets/art/characters/briseida/briseida_busto_%s.png"
## Busto de BYTE (512×512, fondo transparente): byte_<expresión>.png con normal, contenta, preocupada y alerta.
const BYTE_BUST := "res://assets/art/characters/byte/byte_%s.png"

## Cuartos: data/rooms/<id>.json (lienzo, offsets, proyección...).
const ROOM_IDS: Array[StringName] = [&"garage", &"oficina", &"data_center"]
const ROOM_DATA := "res://data/rooms/%s.json"
## Guion del tutorial de Briseida y BYTE.
const TUTORIAL_STEPS_JSON := "res://data/tutorial/tutorial_steps.json"
## Catálogo de la tienda de decoración.
const DECOR_CATALOG_JSON := "res://data/decor/catalogo.json"

## Textura de una capa personalizable: rooms/<cuarto>/<capa>/<id>.png
const ROOM_LAYER_TEXTURE := "res://assets/art/rooms/%s/%s/%s.png"

# Guardado
const SAVE_FILE := "user://savegame.cfg"
const SETTINGS_FILE := "user://settings.cfg"
