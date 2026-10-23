class_name WaveData
extends Resource
## Una oleada de tráfico: rampa base + picos (lanzamientos, campañas) + ataques DDoS.
## Todos los multiplicadores son relativos a StageData.base_rps.

@export_range(10.0, 300.0, 1.0, "suffix:s") var duration_s := 60.0
## Multiplicador del tráfico al inicio (x) y al final (y) de la oleada; crece en línea recta.
@export var ramp := Vector2(1.0, 1.0)
## Picos de tráfico legítimo: (inicio s, duración s, multiplicador extra en la cima).
@export var spikes: Array[Vector3] = []
## Ataques DDoS: (inicio s, duración s, tráfico malicioso en múltiplos de base_rps).
@export var ddos: Array[Vector3] = []
## Lo que BYTE dice al empezar la oleada. Vacío = BYTE no habla.
@export_multiline var tutorial_text := ""


## Multiplicador del tráfico legítimo en el segundo `t` de la oleada.
func traffic_multiplier(t: float) -> float:
	var progress := clampf(t / duration_s, 0.0, 1.0)
	var multiplier := lerpf(ramp.x, ramp.y, progress)
	for spike: Vector3 in spikes:
		multiplier += _envelope(t, spike) * spike.z
	return multiplier


## Tráfico malicioso (en múltiplos de base_rps) en el segundo `t`.
func ddos_multiplier(t: float) -> float:
	var multiplier := 0.0
	for attack: Vector3 in ddos:
		multiplier += _envelope(t, attack) * attack.z
	return multiplier


## Curva suave 0 → 1 → 0 dentro de la ventana (inicio, duración).
static func _envelope(t: float, window: Vector3) -> float:
	if window.y <= 0.0 or t < window.x or t > window.x + window.y:
		return 0.0
	return sin(PI * (t - window.x) / window.y)
