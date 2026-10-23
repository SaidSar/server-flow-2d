extends Node
## Escena de arranque: aquí se pueden inicializar servicios y después se abre el menú de título.


func _ready() -> void:
	SceneRouter.goto.call_deferred(Paths.TITLE_MENU)
