class_name RoomProjection
extends RefCounted
## Proyección isométrica de un cuarto: metros del mundo ↔ píxeles del lienzo 2x.
## lienzo = origen + x·ex + y·ey + z·ez. El nodo Layers del cuarto está a escala 0.5, así que
## estas coordenadas son locales a Layers.
## La cámara mira desde +x/−y: más x o menos y = más cerca de la cámara (más abajo en pantalla).

## Muros donde se cuelga decoración: "der" = plano y = máximo, "izq" = plano x = 0.
const WALL_RIGHT := &"der"
const WALL_LEFT := &"izq"

var origin := Vector2.ZERO
var ex := Vector2.ZERO
var ey := Vector2.ZERO
var ez := Vector2.ZERO
var cell_m := 0.5
## Piso en metros, leído de "cuadricula" en el JSON de cada cuarto (0..9 × 0..9 en la oficina,
## 0..12 × 0..12 en el data center).
var bounds := Rect2()
## Zonas donde no se puede poner decoración (escritorio, puerta, racks...).
var occupied: Array[Rect2] = []


static func from_dict(projection: Dictionary, grid: Dictionary) -> RoomProjection:
	var result := RoomProjection.new()
	result.origin = parse_vector(projection.get("origen"))
	result.ex = parse_vector(projection.get("ex"))
	result.ey = parse_vector(projection.get("ey"))
	result.ez = parse_vector(projection.get("ez"))
	result.cell_m = float(grid.get("celda_m", 0.5))
	if not grid.has("x") or not grid.has("y"):
		push_error("La cuadrícula del cuarto no trae su tamaño (cuadricula.x / cuadricula.y).")
	var range_x := parse_vector(grid.get("x"))
	var range_y := parse_vector(grid.get("y"))
	result.bounds = Rect2(range_x.x, range_y.x, range_x.y - range_x.x, range_y.y - range_y.x)
	for zone: Variant in grid.get("ocupado_m", []):
		if zone is Dictionary:
			var zx := parse_vector((zone as Dictionary).get("x"))
			var zy := parse_vector((zone as Dictionary).get("y"))
			result.occupied.append(Rect2(zx.x, zy.x, zx.y - zx.x, zy.y - zy.x))
	return result


func world_to_canvas(x: float, y: float, z: float = 0.0) -> Vector2:
	return origin + ex * x + ey * y + ez * z


## Punto del piso (z = 0) bajo un punto del lienzo.
func canvas_to_world(point: Vector2) -> Vector2:
	return _solve(point - origin, ex, ey)


## Punto de un muro bajo un punto del lienzo: (coordenada a lo largo del muro, altura z).
## `wall_coord` es la y del muro derecho o la x del muro izquierdo.
func canvas_to_wall(point: Vector2, wall: StringName, wall_coord: float) -> Vector2:
	if wall == WALL_RIGHT:
		return _solve(point - origin - ey * wall_coord, ex, ez)
	return _solve(point - origin - ex * wall_coord, ey, ez)


## Redondea a la cuadrícula.
func snap(value: float) -> float:
	return roundf(value / cell_m) * cell_m


## Coeficientes (a, b) tales que a·u + b·v = target.
static func _solve(target: Vector2, u: Vector2, v: Vector2) -> Vector2:
	var det := u.x * v.y - v.x * u.y
	if is_zero_approx(det):
		return Vector2.ZERO
	return Vector2((target.x * v.y - v.x * target.y) / det, (u.x * target.y - target.x * u.y) / det)


static func parse_vector(raw: Variant) -> Vector2:
	if raw is Array and (raw as Array).size() >= 2:
		return Vector2(float(raw[0]), float(raw[1]))
	return Vector2.ZERO
