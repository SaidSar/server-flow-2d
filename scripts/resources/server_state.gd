class_name ServerState
extends Resource
## Carga actual (0-100 %) de cada recurso de un servidor.

const RESOURCE_IDS: Array[StringName] = [&"cpu", &"ram", &"network", &"disk"]

@export_range(0.0, 100.0) var cpu: float = 0.0
@export_range(0.0, 100.0) var ram: float = 0.0
@export_range(0.0, 100.0) var network: float = 0.0
@export_range(0.0, 100.0) var disk: float = 0.0


func get_load(resource_id: StringName) -> float:
	match resource_id:
		&"cpu":
			return cpu
		&"ram":
			return ram
		&"network":
			return network
		&"disk":
			return disk
	push_warning("Recurso desconocido: %s" % resource_id)
	return 0.0


func get_peak_load() -> float:
	return maxf(maxf(cpu, ram), maxf(network, disk))
