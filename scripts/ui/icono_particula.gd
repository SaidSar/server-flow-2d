extends Sprite2D

const CARPETA_ICONOS: String = "res://assets/IconosSVG/"

@export var escala_min: float = 0.09
@export var escala_max: float = .28

static var _texturas: Array[Texture2D] = []
static var _texturas_cargadas: bool = false

var velocidad_caida: float = 100.0
var velocidad_rotacion: float = 0.0

func _ready() -> void:
	if not _texturas_cargadas:
		_cargar_texturas()
		_texturas_cargadas = true

	if _texturas.size() > 0:
		texture = _texturas.pick_random()

	velocidad_caida = randf_range(80.0, 180.0)
	velocidad_rotacion = randf_range(-1.0, 1.0)

	var escala_aleatoria = randf_range(escala_min, escala_max)
	scale = Vector2(escala_aleatoria, escala_aleatoria)

	modulate.a = randf_range(0.4, 0.9)
	# El material es compartido: todos los íconos toman el color del tema actual.
	(material as ShaderMaterial).set_shader_parameter(&"tinte", UiTheme.color(&"title_particle"))

func _process(delta: float) -> void:
	position.y += velocidad_caida * delta
	rotation += velocidad_rotacion * delta

	if position.y > get_viewport_rect().size.y + 100:
		queue_free()

func _cargar_texturas() -> void:
	var dir = DirAccess.open(CARPETA_ICONOS)
	if dir == null:
		push_error("No se pudo abrir la carpeta: " + CARPETA_ICONOS)
		return

	dir.list_dir_begin()
	var nombre = dir.get_next()
	while nombre != "":
		if not dir.current_is_dir():
			var nombre_limpio = nombre.trim_suffix(".import")
			var ruta = CARPETA_ICONOS + nombre_limpio
			if ruta.get_extension().to_lower() in ["svg", "png", "webp", "jpg", "jpeg"]:
				var tex = load(ruta)
				if tex is Texture2D:
					_texturas.append(tex)

		nombre = dir.get_next()
	dir.list_dir_end()
