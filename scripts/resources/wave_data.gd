class_name WaveData
extends Resource
## Una oleada de tráfico: rampa base + picos (lanzamientos, campañas).
## Todos los multiplicadores son relativos a StageData.base_rps.
## Los ataques DDoS no van aquí: los genera la simulación con los parámetros de la etapa.

@export_range(10.0, 300.0, 1.0, "suffix:s") var duration_s := 60.0
## Multiplicador del tráfico al inicio (x) y al final (y) de la oleada; crece en línea recta.
@export var ramp := Vector2(1.0, 1.0)
## Picos de tráfico legítimo: (inicio s, duración s, multiplicador extra en la cima).
@export var spikes: Array[Vector3] = []
## Lo que BYTE dice al empezar la oleada. Vacío = BYTE no habla.
@export_multiline var tutorial_text := ""


## Multiplicador del tráfico legítimo en el segundo `t` de la oleada.
func traffic_multiplier(t: float) -> float:
	var progress := clampf(t / duration_s, 0.0, 1.0)
	var multiplier := lerpf(ramp.x, ramp.y, progress)
	for spike: Vector3 in spikes:
		multiplier += envelope(t, spike) * spike.z
	return multiplier


## Curva suave 0 → 1 → 0 dentro de la ventana (inicio, duración).
static func envelope(t: float, window: Vector3) -> float:
	if window.y <= 0.0 or t < window.x or t > window.x + window.y:
		return 0.0
	return sin(PI * (t - window.x) / window.y)
