class_name DbState
extends RefCounted
## La base de datos: consultas por segundo, espacio en disco y caché.

## Consultas por segundo que resuelve.
var iops := 1.0
var disk_gb_cap := 10.0
var disk_gb_used := 0.0
## Fracción de lecturas que responde la caché sin tocar el disco (0..0.9).
var cache_hit := 0.0

## Utilización de consultas en el último paso (0..∞).
var u_db := 0.0


func get_disk_fill() -> float:
	if disk_gb_cap <= 0.0:
		return 1.0
	return clampf(disk_gb_used / disk_gb_cap, 0.0, 1.0)


func is_disk_full() -> bool:
	return disk_gb_used >= disk_gb_cap
