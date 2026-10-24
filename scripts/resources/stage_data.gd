class_name StageData
extends Resource
## Etapa de la empresa (Startup, Scale-up, Enterprise): su cuarto, su meta y sus oleadas.

@export var id: StringName
## Número de etapa (1, 2, 3). Las mejoras se desbloquean por número.
@export_range(1, 10) var number := 1
@export var display_name: String
## Nombre del cuarto ("Garage", "Oficina"...). El HUD muestra display_name; este nombre
## solo aparece como "Cuarto temporal" cuando otra etapa usa este cuarto.
@export var room_name: String
## Escena del cuarto. Vacío si todavía no existe.
@export_file("*.tscn") var room_scene_path: String
## true si el cuarto de esta etapa ya existe. Si es false, se usa el de la etapa 1
## y el HUD avisa que es un cuarto temporal.
@export var room_ready := false
@export_multiline var description: String

@export_group("Meta y economía")
## Usuarios atendidos (peticiones exitosas) para completar la etapa.
@export var user_goal := 1000
## Monedas por petición atendida rápido (verde); las lentas (amarillo) dan la mitad.
@export var coin_per_req := 1.0
## Ronda de inversión: monedas que recibe la empresa al llegar a esta etapa.
@export var investment_coins := 0
## Fracción de peticiones exitosas que exige el SLA (0.95 = 95 %).
@export_range(0.0, 1.0) var sla_target := 0.95

@export_group("Tráfico")
## Tráfico base en peticiones por segundo; las oleadas lo multiplican.
@export var base_rps := 1.0
## GB que ocupa en el disco de la BD cada escritura.
@export var gb_per_write := 0.01
@export var waves: Array[WaveData] = []
## Ids de las mejoras que se desbloquean al llegar a esta etapa.
@export var unlocks: Array[StringName] = []


func get_wave(wave_number: int) -> WaveData:
	if waves.is_empty():
		return null
	return waves[clampi(wave_number - 1, 0, waves.size() - 1)]


func get_wave_count() -> int:
	return waves.size()
