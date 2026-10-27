class_name DecorOrientation
extends Resource
## Una orientación de un objeto de decoración: su sprite y su huella.

@export_file("*.png") var sprite_path: String
## Píxel del sprite donde cae el punto (0,0,0) del objeto: la esquina mínima de su huella.
@export var anchor := Vector2.ZERO
## Huella en metros. Piso: (largo en x, largo en y). Pared: (largo a lo largo del muro, grosor).
@export var footprint_m := Vector2.ZERO
@export var footprint_cells := Vector2i.ONE


func load_texture() -> Texture2D:
	return load(sprite_path) as Texture2D
