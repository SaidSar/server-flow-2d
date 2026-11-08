extends Node
## Autoload "Tutorial": en qué paso va el tutorial de Briseida y BYTE.
## El paso vive en GameState.tutorial_step (se guarda con la partida). Una partida nueva empieza en 0;
## las partidas guardadas antes del tutorial no lo ven. "Ver tutorial otra vez" (Ajustes) lo reinicia.
## No dibuja nada: el cuarto y el dashboard tienen un TutorialOverlay que escucha estas señales y
## avisa lo que hace el jugador con notify_action().

## Cambió el paso, o el tutorial empezó o terminó.
signal step_changed
## El tutorial terminó; `skipped` = el jugador lo saltó.
signal finished(skipped: bool)

var steps: Array[TutorialStep] = []


func _ready() -> void:
	steps = TutorialStep.load_all()


## true mientras la partida en curso tiene un paso pendiente.
func is_active() -> bool:
	return GameState.is_active and get_step_index() >= 0 and get_step_index() < steps.size()


func get_step_index() -> int:
	return GameState.tutorial_step


func get_step_count() -> int:
	return steps.size()


## El paso actual (null si el tutorial no está activo).
func current() -> TutorialStep:
	return steps[get_step_index()] if is_active() else null


## Empieza (o repite) el tutorial desde el principio.
func start() -> void:
	if steps.is_empty():
		return
	GameState.tutorial_step = 0
	step_changed.emit()
	SaveSystem.save_game()  # Si la app se cierra a media repetición, el tutorial se retoma.


func advance() -> void:
	if not is_active():
		return
	GameState.tutorial_step += 1
	if GameState.tutorial_step >= steps.size():
		_finish(false)
	else:
		step_changed.emit()


## "Saltar tutorial".
func skip() -> void:
	if is_active():
		_finish(true)


## El jugador hizo algo que el tutorial vigila (tap_pc, buy_upgrade, wave_finished).
## Avanza solo si el paso actual lo esperaba.
func notify_action(event: StringName) -> void:
	var step := current()
	if step != null and step.is_completed_by(event):
		advance()


## ¿Ya pasó lo que el paso actual esperaba para mostrarse? (wait_for)
func is_ready(step: TutorialStep) -> bool:
	match step.wait_for:
		&"wave_finished":
			return Simulation.phase in [Simulation.Phase.BETWEEN_WAVES, Simulation.Phase.GAME_OVER, Simulation.Phase.STAGE_FAILED] \
				or Simulation.pending_stage_report != null
	return true


## Reemplaza {jugador} y {empresa} y elige el género ({masculino|femenino}).
static func format(text: String) -> String:
	var player := GameState.avatar_name if not GameState.avatar_name.is_empty() else "equipo"
	var company := GameState.company_name if not GameState.company_name.is_empty() else "la empresa"
	return TextUtil.format(text.replace("{jugador}", player).replace("{empresa}", company))


## ¿Ya había llegado el tutorial al paso donde BYTE se presenta? (se calcula al terminar, antes de borrar el paso)
var byte_intro_seen := false


func _finish(skipped: bool) -> void:
	byte_intro_seen = false
	for i in mini(get_step_index() + 1, steps.size()):
		if steps[i].is_byte():
			byte_intro_seen = true
			break
	GameState.tutorial_step = GameState.TUTORIAL_DONE
	step_changed.emit()
	finished.emit(skipped)
	SaveSystem.save_game()
