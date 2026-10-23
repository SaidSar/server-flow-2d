extends Control
## Pantalla de carga: precarga en otro hilo lo que pidió SceneRouter y luego abre el destino.
## Se muestra al menos MIN_SECONDS para que no parpadee.

const MIN_SECONDS := 1.0
const STATUS_MESSAGES: Array[String] = [
	"Conectando cables…",
	"Encendiendo servidores…",
	"Configurando la red…",
	"Listo para despegar",
]

@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _status_label: Label = %StatusLabel

var _paths: PackedStringArray = []
var _target := ""
var _elapsed := 0.0
var _finished := false


func _ready() -> void:
	_target = SceneRouter.pending_target
	_paths = SceneRouter.pending_preloads
	for path: String in _paths:
		var error := ResourceLoader.load_threaded_request(path, "", true)
		if error != OK:
			push_error("No se pudo empezar a cargar %s: %s" % [path, error_string(error)])
	_progress_bar.value = 0.0


func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	var real_progress := _get_real_progress()
	var shown_progress := minf(real_progress, _elapsed / MIN_SECONDS)
	_progress_bar.value = shown_progress * 100.0
	var message_index := mini(int(shown_progress * STATUS_MESSAGES.size()), STATUS_MESSAGES.size() - 1)
	_status_label.text = STATUS_MESSAGES[message_index]

	if real_progress >= 1.0 and _elapsed >= MIN_SECONDS:
		_finished = true
		_finish()


func _get_real_progress() -> float:
	if _paths.is_empty():
		return 1.0
	var total := 0.0
	for path: String in _paths:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			total += float(progress[0]) if not progress.is_empty() else 0.0
		else:
			total += 1.0
	return total / _paths.size()


func _finish() -> void:
	for path: String in _paths:
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
			SceneRouter.store_preloaded(path, ResourceLoader.load_threaded_get(path))
		else:
			push_warning("No se pudo precargar %s; se cargará al abrirla." % path)
	SceneRouter.goto(_target)
