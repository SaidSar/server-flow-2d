class_name TextUtil
extends RefCounted
## Textos con género: eligen la forma según el personaje de la partida (AvatarData.gender).
## Prefiere frases neutras y usa esto solo donde no se pueda.

## "{masculino|femenino}", p. ej. "Bienvenid{o|a}" o "{el mejor|la mejor}".
const GENDER_PATTERN := "\\{([^{}|]*)\\|([^{}|]*)\\}"

static var _gender_regex: RegEx


## g("Bienvenido", "Bienvenida"). `gender` vacío = el del personaje de la partida.
static func g(masculine: String, feminine: String, gender: String = "") -> String:
	return feminine if _resolve(gender) == "f" else masculine


## Reemplaza cada "{masculino|femenino}" por la forma que toca. Sirve para textos de datos (.tres).
static func format(text: String, gender: String = "") -> String:
	if _gender_regex == null:
		_gender_regex = RegEx.create_from_string(GENDER_PATTERN)
	return _gender_regex.sub(text, "$2" if _resolve(gender) == "f" else "$1", true)


static func _resolve(gender: String) -> String:
	return gender if not gender.is_empty() else GameState.get_avatar().gender
