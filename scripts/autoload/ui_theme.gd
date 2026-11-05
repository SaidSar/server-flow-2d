extends Node
## Autoload "UiTheme": tema de la interfaz (Oscuro/Claro).
## Los colores de los paneles (HUD, dashboard, tienda, menús) son tokens con un valor por tema. Cambiar
## de tema es un solo cambio: se cambia la paleta y se repinta todo lo que use tokens.
## - En escenas: el nodo (o su StyleBoxFlat) declara metadata/ui_tokens = {propiedad: token}, p. ej.
##   {"font_color": "text_muted"} o {"bg_color": "panel", "border_color": "accent"}. El color que
##   queda en la escena es el del tema oscuro (lo que se ve en el editor); se respeta su alfa.
## - En scripts: DashboardColors.TEXT, DashboardColors.ACCENT... o color(&"token"). Lo que se pinta
##   por código se vuelve a pintar escuchando la señal `changed`.
## El arte del cuarto (paredes, piso, objetos) no usa tokens: tiene su propia personalización.
## El valor se guarda en Settings (user://settings.cfg), igual que el volumen.

signal changed

const DARK := &"dark"
const LIGHT := &"light"
const MODES: Array[StringName] = [DARK, LIGHT]
const META := &"ui_tokens"
## Estilos que se revisan en cada control por si su StyleBoxFlat declara tokens.
const STYLE_NAMES: Array[StringName] = [
	&"panel", &"normal", &"hover", &"pressed", &"disabled", &"focus", &"hover_pressed",
	&"background", &"fill", &"slider", &"grabber_area", &"grabber_area_highlight",
]

const PALETTES := {
	DARK: {
		# Fondos y paneles
		&"bg": Color("#0b111c"),
		&"screen_bg": Color("#141824"),
		&"side_panel": Color("#141824"),
		&"menu_panel": Color("#1b202e"),
		&"panel": Color("#121b2b"),
		&"panel_border": Color("#22314a"),
		&"inset": Color("#0f1726"),
		&"inset_border": Color("#1e2944"),
		&"card": Color("#16233a"),
		&"card_alt": Color("#1b2232"),
		&"card_border": Color("#3a4458"),
		&"card_border_hover": Color("#5f6b85"),
		&"hud_panel": Color("#0f141e"),
		&"hud_track": Color("#333847"),
		&"track": Color("#292e3d"),
		&"bar_track": Color("#0b111c"),
		&"scroll_track": Color("#ffffff"),
		&"scrim": Color("#0b111c"),
		&"scrim_deep": Color("#000000"),
		## Caja hundida dentro de un panel (consejo y causa del post-mortem).
		&"well": Color("#0b111c"),
		&"link": Color("#24324a"),
		# Botones de mejora
		&"button_hover": Color("#1c2d4a"),
		&"button_pressed": Color("#24395c"),
		&"button_disabled": Color("#0f1726"),
		&"button_disabled_border": Color("#1a2638"),
		&"button_alert": Color("#2a1620"),
		&"swatch_border": Color("#0d0f17"),
		&"swatch_border_hover": Color("#ccd9e6"),
		# Texto
		&"text": Color("#e6edf7"),
		&"text_on_accent": Color("#ffffff"),
		## Nombres destacados (objetos de la Tienda, personajes).
		&"text_title": Color("#ffffff"),
		&"text_muted": Color("#8a9bb5"),
		&"text_soft": Color("#b2bfd1"),
		&"text_hint": Color("#99a6b8"),
		&"text_subtitle": Color("#99b2cc"),
		&"text_footer": Color("#738094"),
		&"hud_text_soft": Color("#99a8c2"),
		&"hud_accent": Color("#99ccff"),
		## Texto que flota sobre el arte del cuarto (no sobre un panel): igual en los dos temas.
		&"float_text": Color("#b2bfd1"),
		&"float_warning": Color("#f5c542"),
		&"float_outline": Color("#0b111c"),
		# Acentos y estados
		&"accent": Color("#5aa9ff"),
		&"highlight": Color("#4fc3f7"),
		&"coin": Color("#f5c542"),
		&"coin_shop": Color("#f9cc57"),
		&"hud_coin": Color("#ffd466"),
		&"hud_ok": Color("#4cbb6d"),
		&"ok": Color("#3ddc84"),
		&"warning": Color("#f5c542"),
		&"danger": Color("#ff4d5e"),
		## Aviso urgente del dashboard (cuello de botella, ataque DDoS).
		&"alert": Color("#ff4d5e"),
		&"malicious": Color("#b06cff"),
		&"blocked": Color("#f59973"),
		&"ceo": Color("#e0569b"),
	},
	LIGHT: {
		&"bg": Color("#eef2f8"),
		&"screen_bg": Color("#e8edf5"),
		&"side_panel": Color("#f8fafd"),
		&"menu_panel": Color("#ffffff"),
		&"panel": Color("#ffffff"),
		&"panel_border": Color("#d3dbe8"),
		&"inset": Color("#f3f6fb"),
		&"inset_border": Color("#d3dbe8"),
		&"card": Color("#f3f6fb"),
		&"card_alt": Color("#f3f6fb"),
		&"card_border": Color("#c3ccdb"),
		&"card_border_hover": Color("#8d99b0"),
		&"hud_panel": Color("#f8fafd"),
		&"hud_track": Color("#d9e0eb"),
		&"track": Color("#d9e0eb"),
		&"bar_track": Color("#dfe5ef"),
		&"scroll_track": Color("#1c2433"),
		&"scrim": Color("#1c2433"),
		&"scrim_deep": Color("#1c2433"),
		&"well": Color("#f0f3f8"),
		&"link": Color("#c3cddd"),
		&"button_hover": Color("#e4edf9"),
		&"button_pressed": Color("#d2e2f7"),
		&"button_disabled": Color("#eef1f6"),
		&"button_disabled_border": Color("#dde3ec"),
		&"button_alert": Color("#fdebee"),
		&"swatch_border": Color("#1c2433"),
		&"swatch_border_hover": Color("#5b6680"),
		&"text": Color("#1c2433"),
		&"text_on_accent": Color("#ffffff"),
		&"text_title": Color("#1c2433"),
		&"text_muted": Color("#56627a"),
		&"text_soft": Color("#46536a"),
		&"text_hint": Color("#56627a"),
		&"text_subtitle": Color("#46566f"),
		&"text_footer": Color("#5f687a"),
		&"hud_text_soft": Color("#46536a"),
		&"hud_accent": Color("#1d5ba6"),
		&"float_text": Color("#b2bfd1"),
		&"float_warning": Color("#f5c542"),
		&"float_outline": Color("#0b111c"),
		&"accent": Color("#1f64c4"),
		&"highlight": Color("#0a6c9f"),
		&"coin": Color("#8a5d00"),
		&"coin_shop": Color("#8a5d00"),
		&"hud_coin": Color("#8a5d00"),
		&"hud_ok": Color("#2a8a4a"),
		&"ok": Color("#17733c"),
		&"warning": Color("#946100"),
		&"danger": Color("#c22339"),
		&"alert": Color("#b3001b"),
		&"malicious": Color("#7a3ed4"),
		&"blocked": Color("#a8481c"),
		&"ceo": Color("#b52a66"),
	},
}

var mode: StringName = DARK


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	Settings.changed.connect(_sync_from_settings)
	_sync_from_settings(true)


## Color de un token en el tema actual.
func color(token: StringName) -> Color:
	var palette: Dictionary = PALETTES[mode]
	if not palette.has(token):
		push_error("Token de color desconocido: %s" % token)
		return Color.MAGENTA
	return palette[token]


func is_light() -> bool:
	return mode == LIGHT


## Aplica los tokens de un nodo (y de sus estilos) con el tema actual.
func apply_to(node: Node) -> void:
	if node.has_meta(META):
		var tokens: Dictionary = node.get_meta(META)
		for property: Variant in tokens:
			_apply_node_token(node, StringName(str(property)), StringName(str(tokens[property])))
	var control := node as Control
	if control == null:
		return
	for style_name: StringName in STYLE_NAMES:
		if control.has_theme_stylebox_override(style_name):
			apply_to_style(control.get_theme_stylebox(style_name))


func apply_to_style(style: StyleBox) -> void:
	if style == null or not style.has_meta(META):
		return
	var tokens: Dictionary = style.get_meta(META)
	for property: Variant in tokens:
		var current: Variant = style.get(StringName(str(property)))
		if current is Color:
			style.set(StringName(str(property)), _with_alpha(color(StringName(str(tokens[property]))), current))


func _sync_from_settings(force: bool = false) -> void:
	var wanted: StringName = Settings.ui_theme if Settings.ui_theme in MODES else DARK
	if wanted == mode and not force:
		return
	mode = wanted
	DashboardColors.use_palette(PALETTES[mode])
	_apply_project_theme()
	_apply_tree(get_tree().root)
	changed.emit()


func _on_node_added(node: Node) -> void:
	apply_to(node)


func _apply_tree(node: Node) -> void:
	apply_to(node)
	for child: Node in node.get_children():
		_apply_tree(child)


func _apply_node_token(node: Node, property: StringName, token: StringName) -> void:
	if node is ColorRect and property == &"color":
		var rect := node as ColorRect
		rect.color = _with_alpha(color(token), rect.color)
	elif node is CanvasItem and property == &"modulate":
		var item := node as CanvasItem
		item.modulate = _with_alpha(color(token), item.modulate)
	elif node is Control:
		var control := node as Control
		var current := control.get_theme_color(property) if control.has_theme_color_override(property) else Color.WHITE
		control.add_theme_color_override(property, _with_alpha(color(token), current))


static func _with_alpha(value: Color, keep: Color) -> Color:
	return Color(value, keep.a)


## El tema del proyecto (main_theme.tres): el tooltip siempre; y en el tema claro, los controles que
## hoy usan el estilo por defecto de Godot (botones, sliders, casillas, campos de texto, etiquetas).
## En el tema oscuro esos se dejan como están.
func _apply_project_theme() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	apply_to_style(theme.get_stylebox(&"panel", &"TooltipPanel"))
	theme.set_color(&"font_color", &"TooltipLabel", color(&"text"))
	var light := is_light()
	var colors := {
		&"Label": [&"font_color"],
		&"Button": [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color", &"font_disabled_color"],
		&"CheckButton": [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color", &"font_hover_pressed_color", &"font_disabled_color"],
		&"LineEdit": [&"font_color", &"font_placeholder_color", &"caret_color", &"clear_button_color", &"clear_button_color_pressed"],
		&"ProgressBar": [&"font_color"],
	}
	for type: StringName in colors:
		for item: StringName in colors[type]:
			if not light:
				if theme.has_color(item, type):
					theme.clear_color(item, type)
			elif item == &"font_disabled_color" or item == &"font_placeholder_color" or item == &"clear_button_color":
				theme.set_color(item, type, color(&"text_muted"))
			elif item == &"clear_button_color_pressed":
				theme.set_color(item, type, color(&"accent"))
			else:
				theme.set_color(item, type, color(&"text"))
	var styles := {
		&"Button": {&"normal": [&"inset", &"panel_border"], &"hover": [&"button_hover", &"accent"], &"pressed": [&"button_pressed", &"accent"], &"hover_pressed": [&"button_pressed", &"accent"], &"disabled": [&"button_disabled", &"button_disabled_border"], &"focus": [&"", &"accent"]},
		&"LineEdit": {&"normal": [&"panel", &"panel_border"], &"focus": [&"", &"accent"]},
		&"HSlider": {&"slider": [&"bar_track", &""]},
	}
	for type: StringName in styles:
		for item: StringName in styles[type]:
			if not light:
				if theme.has_stylebox(item, type):
					theme.clear_stylebox(item, type)
				continue
			var pair: Array = styles[type][item]
			theme.set_stylebox(item, type, _flat_style(pair[0], pair[1]))


## Ícono de interruptor (CheckButton) con los colores del tema: pista de acento y perilla clara
## encendido; pista gris y perilla de texto apagado.
func switch_icon(on: bool) -> Texture2D:
	var track := color(&"accent") if on else color(&"card_border")
	var knob := color(&"text_on_accent") if on else color(&"text")
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="64" height="36"><rect x="1" y="1" width="62" height="34" rx="17" fill="#%s"/><circle cx="%d" cy="18" r="12" fill="#%s"/></svg>' % [
		track.to_html(false), 46 if on else 18, knob.to_html(false)]
	var image := Image.new()
	if image.load_svg_from_string(svg) != OK:
		push_error("No se pudo dibujar el ícono del interruptor.")
		return null
	return ImageTexture.create_from_image(image)


func _flat_style(fill: StringName, border: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = fill != &""
	if fill != &"":
		style.bg_color = color(fill)
	if border != &"":
		style.border_color = color(border)
		style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10.0)
	return style
