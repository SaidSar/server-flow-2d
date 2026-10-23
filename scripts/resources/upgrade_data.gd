class_name UpgradeData
extends Resource
## Mejora que el jugador puede comprar para su infraestructura.

@export var id: StringName
@export var display_name: String
## Explicación educativa que verá el jugador.
@export_multiline var description: String
@export var cost: int = 100
## Qué mejora: cpu, ram, network, disk, sla o servers.
@export var target: StringName
## Cuánto mejora el objetivo (puntos de capacidad, de SLA o número de servidores).
@export var amount: float = 10.0
## Etapa a partir de la cual está disponible.
@export var required_stage: StringName = &"startup"
@export var icon: Texture2D
