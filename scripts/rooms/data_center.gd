class_name DataCenterRoom
extends RoomBase
## Data center (etapa 3 · Enterprise). Además de lo de RoomBase tiene dos capas fijas propias, en
## su offset de capas_offsets (data/rooms/data_center.json):
## - el vidrio: partición solo decorativa entre el escritorio y el bay (no bloquea ni habilita nada);
## - la placa del Firewall en la pared: apagada hasta que se compra y se enciende la mejora.
## El bay de 9 racks va en RackBay, encima del vidrio (orden_capas del JSON).

@export var glass_texture: Texture2D
@export var firewall_off_texture: Texture2D
@export var firewall_on_texture: Texture2D

@onready var _glass: Sprite2D = %Glass
@onready var _firewall_plate: Sprite2D = %FirewallPlate


func _ready() -> void:
	super._ready()
	Customization.apply_layer(_glass, glass_texture)
	_refresh_firewall()
	Simulation.infrastructure_changed.connect(_refresh_firewall)


func is_firewall_plate_on() -> bool:
	return _firewall_plate.texture == firewall_on_texture


func _refresh_firewall() -> void:
	var texture := firewall_on_texture if Simulation.is_firewall_active() else firewall_off_texture
	if _firewall_plate.texture != texture:
		Customization.apply_layer(_firewall_plate, texture)
