class_name CustomizationOption
extends Resource
## Una opción de color para una capa personalizable del cuarto.

## Identificador usado en el guardado y en el nombre del PNG (<capa>/<id>.png).
@export var id: StringName
## Nombre visible en el juego (tooltip de la muestra).
@export var display_name: String
## Color de la muestra en el panel de personalización.
@export var color: Color = Color.WHITE
## Monedas que cuesta desbloquearla (una sola vez; sirve en todas las capas y cuartos). 0 = gratis.
@export var price := 0
## "render": cada color tiene su PNG renderizado en Blender. "tinte": se recolorea en el juego (shader) a partir del
## render `base_id`. "patron": se dibuja un patrón repetido sobre el render `base_id`.
@export_enum("render", "tinte", "patron") var kind := "render"
## Opción cuyo render se usa de base (da la forma y las sombras). Solo tinte y patrón.
@export var base_id: StringName = &""
## Opción de la misma capa con otro color, para detectar qué píxeles son el material (y no el pizarrón,
## por ejemplo). Vacío = toda la capa. Solo paredes.
@export var mask_id: StringName = &""
## Archivo del patrón en assets/art/texturas/ (sin .png). Solo patrón.
@export var pattern: String = ""
## Metros del cuarto que cubre un repetido del patrón.
@export var tile_m := 1.0
## Archivo de la ilustración en assets/art/fondos/ (sin .png). Solo fondo; vacío = sin ilustración (fondo liso).
@export var image: String = ""


## ¿Se dibuja con el shader en lugar de un PNG propio?
func is_procedural() -> bool:
	return kind == "tinte" or kind == "patron"
