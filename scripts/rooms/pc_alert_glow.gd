class_name PcAlertGlow
extends Polygon2D
## Destello rojo sobre la pantalla del monitor de la mesa mientras los servidores están saturados,
## para que el jugador sepa desde el cuarto que hay problemas. Se dibuja encima del sprite de la mesa
## (hijo de Desk), así que sigue su desplazamiento y no toca el PNG.

## Esquinas de la cara de la pantalla en píxeles del sprite de la mesa (448×400, lienzo 2x):
## arriba-izquierda, arriba-derecha, abajo-derecha, abajo-izquierda. Son iguales para los 3 colores de mesa.
const SCREEN_CORNERS: PackedVector2Array = [
	Vector2(116, 67), Vector2(223, 17), Vector2(223, 97), Vector2(116, 149),
]
const ALERT_COLOR := Color("#ff4d5e")
const ALPHA_MIN := 0.15
const ALPHA_MAX := 0.5
## Velocidad del parpadeo en radianes por segundo (~1.4 destellos por segundo).
const PULSE_SPEED := 9.0

var _active := false


func _init() -> void:
	name = &"PcAlertGlow"
	polygon = SCREEN_CORNERS
	color = ALERT_COLOR
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	self.material = material
	visible = false
	set_process(false)


func set_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	visible = active
	set_process(active)
	modulate.a = ALPHA_MAX


func is_active() -> bool:
	return _active


func _process(_delta: float) -> void:
	var wave := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * PULSE_SPEED)
	modulate.a = lerpf(ALPHA_MIN, ALPHA_MAX, wave)
