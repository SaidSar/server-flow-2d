class_name SafeArea
extends RefCounted
## Zonas seguras del celular (cámara frontal, esquinas redondeadas, barra de gestos).
## Devuelve cuánto hay que separarse de cada borde, en coordenadas del viewport.
## En escritorio siempre es cero: ahí la "zona segura" es la barra de tareas, no la ventana.


## Márgenes por lado: x = izquierda, y = arriba, z = derecha, w = abajo.
static func get_insets(viewport: Viewport) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var window_rect := Rect2(Vector2(DisplayServer.window_get_position()), Vector2(DisplayServer.window_get_size()))
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window_rect.size.x <= 0.0 or window_rect.size.y <= 0.0 or safe.size.x <= 0.0:
		return Vector4.ZERO
	var ratio := viewport.get_visible_rect().size / window_rect.size
	return Vector4(
		maxf(safe.position.x - window_rect.position.x, 0.0) * ratio.x,
		maxf(safe.position.y - window_rect.position.y, 0.0) * ratio.y,
		maxf(window_rect.end.x - safe.end.x, 0.0) * ratio.x,
		maxf(window_rect.end.y - safe.end.y, 0.0) * ratio.y)


## Ajusta un Control anclado a toda la pantalla para que no entre en las zonas inseguras.
static func fit_full_rect(control: Control) -> void:
	var insets := get_insets(control.get_viewport())
	control.offset_left = insets.x
	control.offset_top = insets.y
	control.offset_right = -insets.z
	control.offset_bottom = -insets.w
