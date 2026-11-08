class_name TutorialStep
extends RefCounted
## Un paso del tutorial de Briseida y BYTE (data/tutorial/tutorial_steps.json).

const SPEAKER_BRISEIDA := &"briseida"
const SPEAKER_BYTE := &"byte"
const SCENE_ROOM := &"room"
const SCENE_DASHBOARD := &"dashboard"
const EXPRESSIONS: Array[StringName] = [&"normal", &"contenta", &"preocupada"]
const ACTIONS: Array[StringName] = [&"none", &"tap_pc", &"buy_upgrade"]
const EVENTS: Array[StringName] = [&"tap_pc", &"buy_upgrade", &"wave_finished"]
const WAITS: Array[StringName] = [&"", &"wave_finished"]
const HIGHLIGHTS: Array[StringName] = [&"", &"pc", &"health", &"console"]

var id: StringName = &""
var scene: StringName = SCENE_ROOM
var speaker: StringName = SPEAKER_BRISEIDA
var expression: StringName = &"normal"
var text := ""
var action: StringName = &"none"
## Eventos que también completan el paso (además de `action`).
var also_on: Array[StringName] = []
var wait_for: StringName = &""
var highlight: StringName = &""


static func from_dict(data: Dictionary) -> TutorialStep:
	var step := TutorialStep.new()
	step.id = StringName(str(data.get("id", "")))
	step.scene = StringName(str(data.get("scene", SCENE_ROOM)))
	step.speaker = StringName(str(data.get("speaker", SPEAKER_BRISEIDA)))
	step.expression = StringName(str(data.get("expression", "normal")))
	step.text = str(data.get("text", ""))
	step.action = StringName(str(data.get("action", "none")))
	for event: Variant in data.get("also_on", []):
		step.also_on.append(StringName(str(event)))
	step.wait_for = StringName(str(data.get("wait_for", "")))
	step.highlight = StringName(str(data.get("highlight", "")))
	return step


## Lee todos los pasos del JSON. Un archivo ausente o dañado devuelve una lista vacía (y un error en consola).
static func load_all(path: String = Paths.TUTORIAL_STEPS_JSON) -> Array[TutorialStep]:
	var steps: Array[TutorialStep] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not (parsed as Dictionary).get("steps") is Array:
		push_error("Tutorial: no se pudo leer %s" % path)
		return steps
	for entry: Variant in (parsed as Dictionary)["steps"]:
		if entry is Dictionary:
			steps.append(from_dict(entry))
	return steps


func is_byte() -> bool:
	return speaker == SPEAKER_BYTE


## El paso espera que el jugador haga algo (la caja de Briseida se hace pequeña y no tapa la pantalla).
func needs_action() -> bool:
	return action != &"none"


func is_completed_by(event: StringName) -> bool:
	return (needs_action() and action == event) or event in also_on


## Lista de problemas del paso (vacía si está bien). La usan las pruebas.
func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	if id == &"":
		problems.append("sin id")
	if text.strip_edges().is_empty():
		problems.append("%s: sin texto" % id)
	if not scene in [SCENE_ROOM, SCENE_DASHBOARD]:
		problems.append("%s: scene desconocida (%s)" % [id, scene])
	if not speaker in [SPEAKER_BRISEIDA, SPEAKER_BYTE]:
		problems.append("%s: speaker desconocido (%s)" % [id, speaker])
	if speaker == SPEAKER_BRISEIDA and not expression in EXPRESSIONS:
		problems.append("%s: expression desconocida (%s)" % [id, expression])
	if not action in ACTIONS:
		problems.append("%s: action desconocida (%s)" % [id, action])
	for event: StringName in also_on:
		if not event in EVENTS:
			problems.append("%s: also_on desconocido (%s)" % [id, event])
	if not wait_for in WAITS:
		problems.append("%s: wait_for desconocido (%s)" % [id, wait_for])
	if not highlight in HIGHLIGHTS:
		problems.append("%s: highlight desconocido (%s)" % [id, highlight])
	if is_byte() and needs_action():
		problems.append("%s: BYTE no puede pedir una acción (se cierra con OK)" % id)
	return problems
