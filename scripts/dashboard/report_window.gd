class_name ReportWindow
extends PanelContainer
## Ventana de reporte del dashboard (post-mortem, game over, victoria, meta no alcanzada).
## Nunca es más alta que su área (el Control raíz de la escena, que cubre a su padre: el monitor en el
## post-mortem, el dashboard completo en las demás): el título y los botones siempre se ven y se pueden
## tocar, y el contenido largo (`body`) se desplaza con el dedo o la rueda solo si no cabe.
## Con espacio, la ventana se ensancha y el contenido que lo soporta (`set_wide`) va en dos columnas.

## Separación mínima entre la ventana y el borde de su área.
const AREA_MARGIN := 8.0
## Ancho de la ventana cuando hay espacio.
const MAX_WIDTH := 1100.0
## Desde este ancho de ventana el contenido va lado a lado (estadísticas | causa).
const WIDE_MIN_WIDTH := 960.0
## Alto mínimo del contenido desplazable aunque el área sea muy chica.
const MIN_BODY_HEIGHT := 48.0

## Contenido largo de la ventana (su primer hijo es el contenido real). A los nodos de adentro que
## tengan `set_wide(bool)` (ReportSummary) se les avisa si la ventana es ancha.
@export var body: TouchScrollContainer
@export var max_width := MAX_WIDTH

var _area: Control
var _refit_queued := false
## Alto máximo del contenido desplazable en el último ajuste (para pruebas y mediciones).
var _max_body_height := 0.0


func _ready() -> void:
	_area = owner as Control if owner is Control else get_parent() as Control
	# El reporte desplaza solo cuando no cabe (la lista de la Tienda la muestra siempre).
	body.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_area.resized.connect(refit)
	_area.visibility_changed.connect(refit)
	UiTheme.changed.connect(refit)
	refit()


## Recalcula ancho y alto (al mostrar el reporte, si cambia el área o el tema). Se agrupa por cuadro.
func refit() -> void:
	if _refit_queued:
		return
	_refit_queued = true
	_refit.call_deferred()


func get_max_body_height() -> float:
	return _max_body_height


func is_wide() -> bool:
	return custom_minimum_size.x >= WIDE_MIN_WIDTH


func _refit() -> void:
	_refit_queued = false
	if not is_inside_tree() or not _area.is_visible_in_tree():
		return
	var area := _area.size
	var width := minf(max_width, area.x - 2.0 * AREA_MARGIN)
	custom_minimum_size.x = width
	var content := body.get_child(0) as Control
	body.propagate_call(&"set_wide", [width >= WIDE_MIN_WIDTH])
	# Las etiquetas con ajuste de línea calculan su alto con el ancho ya acomodado.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var fixed := get_combined_minimum_size().y - body.custom_minimum_size.y
	_max_body_height = maxf(MIN_BODY_HEIGHT, area.y - 2.0 * AREA_MARGIN - fixed)
	body.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, _max_body_height)
	body.scroll_vertical = 0
