class_name NumberFormat
extends RefCounted
## Formato de números para la UI.


## 1234567 → "1,234,567".
static func thousands(value: int) -> String:
	var digits := str(absi(value))
	var groups := PackedStringArray()
	while digits.length() > 3:
		groups.insert(0, digits.right(3))
		digits = digits.left(digits.length() - 3)
	groups.insert(0, digits)
	return ("-" if value < 0 else "") + ",".join(groups)


## Cantidad de tráfico tal como la ve el jugador: simulación × display_scale, con separador de miles.
static func traffic(value: float, display_scale: float) -> String:
	return thousands(roundi(value * display_scale))
