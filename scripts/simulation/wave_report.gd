class_name WaveReport
extends RefCounted
## Resumen de una oleada para el post-mortem, el game over y la victoria.

enum Outcome { IN_PROGRESS, SURVIVED, SLA_ZERO, GOAL_MISSED, STAGE_COMPLETE }

## Causa → explicación educativa del post-mortem.
const CAUSE_EXPLANATIONS := {
	&"ram": "Demasiadas peticiones al mismo tiempo: la RAM no alcanzó para atenderlas. Más RAM = más concurrencia.",
	&"disk": "El disco de la BD se llenó y las escrituras fallaron. Haz respaldos o amplía el disco.",
	&"net": "El ancho de banda se saturó: los paquetes hicieron fila.",
	&"cpu": "El procesador no alcanzó: cada petición tardó más (latencia).",
	&"db": "La base de datos fue el cuello de botella. La caché acelera las lecturas frecuentes.",
	&"ddos": "Un ataque DDoS (denegación de servicio distribuida): muchos equipos mandan peticiones basura a la vez para saturar tus servidores y que los usuarios reales no puedan entrar. El firewall revisa cada paquete y descarta el tráfico malicioso antes de que llegue a los servidores, a cambio de un poco de latencia.",
}
const CAUSE_TITLES := {
	&"ram": "RAM",
	&"disk": "Disco",
	&"net": "Red",
	&"cpu": "CPU",
	&"db": "Base de datos",
	&"ddos": "DDoS",
}
const NO_FAILURES_TEXT := "¡Sin fallos! Tu infraestructura aguantó toda la oleada."
## Consejo de "Meta no alcanzada" cuando casi no hubo fallos.
const GOAL_ADVICE_TEXT := "Tus servidores aguantaron, pero atendiste pocos usuarios. Mejora antes de los picos para que no se pierda ninguna petición."

var stage_id: StringName
var wave_number := 1
var outcome: Outcome = Outcome.IN_PROGRESS

## Peticiones legítimas que llegaron.
var requests := 0.0
var green := 0.0
var yellow := 0.0
## Fallos por sobrecarga (rojo).
var timeouts := 0.0
## Escrituras que fallaron por disco lleno.
var errors_500 := 0.0
## Causa → peticiones fallidas.
var failures_by_cause: Dictionary[StringName, float] = {}
var sla_start := 0.0
var sla_end := 0.0
var coins_earned := 0.0
var latency_sum := 0.0

## Totales de la etapa al terminar esta oleada (para la victoria).
var stage_users_served := 0
var stage_user_goal := 0
var stage_avg_sla := 0.0
var stage_avg_latency_ms := 0.0
## Fallos de toda la etapa por causa.
var stage_failures_by_cause: Dictionary[StringName, float] = {}
var stars := 0


func get_served() -> int:
	return roundi(green + yellow)


func get_avg_latency_ms() -> float:
	return latency_sum / requests if requests > 0.0 else 0.0


func add_failures(cause: StringName, amount: float) -> void:
	if amount <= 0.0:
		return
	failures_by_cause[cause] = failures_by_cause.get(cause, 0.0) + amount


## Causa con más fallos, o &"" si no hubo fallos que valga la pena reportar.
func get_main_cause() -> StringName:
	return _main_cause_of(failures_by_cause)


## Causa con más fallos en toda la etapa.
func get_stage_main_cause() -> StringName:
	return _main_cause_of(stage_failures_by_cause)


## Consejo para "Meta no alcanzada": la explicación de la causa principal de la etapa.
func get_stage_advice() -> String:
	return str(CAUSE_EXPLANATIONS.get(get_stage_main_cause(), GOAL_ADVICE_TEXT))


static func _main_cause_of(failures: Dictionary[StringName, float]) -> StringName:
	var main: StringName = &""
	var most := 0.5
	for cause: StringName in failures:
		if failures[cause] > most:
			most = failures[cause]
			main = cause
	return main


func get_main_cause_title() -> String:
	return str(CAUSE_TITLES.get(get_main_cause(), ""))


func get_main_cause_explanation() -> String:
	return str(CAUSE_EXPLANATIONS.get(get_main_cause(), NO_FAILURES_TEXT))
