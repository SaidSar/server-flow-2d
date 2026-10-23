class_name ServerState
extends RefCounted
## Un servidor web: su capacidad y qué tan usada está en el último paso.
## Las utilizaciones van de 0 a ∞ (1.0 = 100 %, arriba de 1 hay peticiones que fallan).

const RESOURCE_IDS: Array[StringName] = [&"cpu", &"ram", &"net"]

## Peticiones por segundo que procesa la CPU.
var cpu_cap := 1.0
## Peticiones simultáneas que caben en la RAM.
var ram_slots := 1.0
## Peticiones por segundo que deja pasar la red.
var net_cap := 1.0

var u_cpu := 0.0
var u_ram := 0.0
var u_net := 0.0
## Peticiones por segundo que recibió en el último paso (legítimas + maliciosas).
var load_rps := 0.0
var malicious_rps := 0.0


func get_utilization(resource_id: StringName) -> float:
	match resource_id:
		&"cpu":
			return u_cpu
		&"ram":
			return u_ram
		&"net":
			return u_net
	push_warning("Recurso de servidor desconocido: %s" % resource_id)
	return 0.0


## Utilización del recurso más cargado (el cuello de botella del servidor).
func get_peak() -> float:
	return maxf(u_cpu, maxf(u_ram, u_net))


func get_peak_resource() -> StringName:
	var peak: StringName = &"cpu"
	for resource_id: StringName in RESOURCE_IDS:
		if get_utilization(resource_id) > get_utilization(peak):
			peak = resource_id
	return peak
