class_name UpgradeData
extends Resource
## Mejora de infraestructura que se compra en la consola del dashboard.

enum EffectMode {
	## capacidad = base + efecto × nivel
	ADD,
	## capacidad = base × (1 + efecto) ^ nivel
	MULTIPLY,
}

@export var id: StringName
@export var display_name: String
## Efecto corto que se ve en el botón ("+50 % CPU").
@export var short_effect: String
@export_multiline var description: String
## Concepto real que enseña; aparece en el tooltip del botón.
@export_multiline var concept: String
## Qué cambia: cpu_cap, ram_slots, net_cap, iops, disk_gb_cap, cache_hit, add_server, firewall o backup.
@export var target: StringName
@export var effect_mode: EffectMode = EffectMode.MULTIPLY
@export var effect_per_level := 0.5
## 0 = sin límite (acciones como el respaldo).
@export var max_level := 5
@export var base_cost := 50
@export var cost_growth := 1.6
## Número de etapa a partir de la cual está disponible.
@export_range(1, 10) var unlock_stage := 1
## Cuellos de botella que resuelve (cpu, ram, net, db, disk, ddos); su botón se resalta en rojo.
@export var fixes: Array[StringName] = []
@export var icon: Texture2D


## Las acciones (respaldo) se usan cuantas veces se quiera y no suben de nivel.
func is_action() -> bool:
	return max_level == 0


func cost_at(level: int) -> int:
	if is_action():
		return base_cost
	return roundi(base_cost * pow(cost_growth, level))


func is_maxed(level: int) -> bool:
	return not is_action() and level >= max_level


## Aplica `level` niveles de esta mejora a un valor base.
func apply(base_value: float, level: int) -> float:
	if effect_mode == EffectMode.MULTIPLY:
		return base_value * pow(1.0 + effect_per_level, level)
	return base_value + effect_per_level * level
