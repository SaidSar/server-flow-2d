class_name StageData
extends Resource
## Etapa de la empresa (Startup, Scale-up, Enterprise) y su cuarto.

@export var id: StringName
@export var display_name: String
## Nombre del cuarto que aparece en el HUD ("Garage", "Oficina"...).
@export var room_name: String
## Escena del cuarto. Vacío si todavía no existe.
@export_file("*.tscn") var room_scene_path: String
@export_range(1, 10) var wave_count: int = 5
@export var starting_coins: int = 100
@export var starting_users: int = 10
@export_multiline var description: String
