class_name CustomizationOption
extends Resource
## Una opción de color para una capa personalizable del cuarto.

## Identificador usado en el guardado y en el nombre del PNG (<capa>/<id>.png).
@export var id: StringName
## Nombre visible en el juego (tooltip de la muestra).
@export var display_name: String
## Color de la muestra en el panel de personalización.
@export var color: Color = Color.WHITE
