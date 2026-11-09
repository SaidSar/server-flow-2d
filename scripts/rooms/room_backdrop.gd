class_name RoomBackdrop
extends CanvasLayer
## Fondo exterior detrás del cuarto: una ilustración que cubre toda la pantalla (se recorta en los bordes,
## sin deformarse). Con la opción "Oscuro" no dibuja nada y se ve el color liso del proyecto.

var _picture: TextureRect


func _init() -> void:
	layer = -10
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.visible = false
	add_child(_picture)


## Muestra el fondo elegido; una opción sin ilustración (o desconocida) deja el fondo liso.
func apply(option: CustomizationOption) -> void:
	var texture: Texture2D = null
	if option != null and option.image != "":
		texture = load(Paths.BACKDROP_TEXTURE % option.image) as Texture2D
	_picture.texture = texture
	_picture.visible = texture != null


func has_picture() -> bool:
	return _picture.visible
