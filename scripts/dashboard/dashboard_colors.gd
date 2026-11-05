class_name DashboardColors
extends RefCounted
## Colores de la interfaz y helpers de estilo. Los valores vienen de la paleta del tema actual
## (UiTheme): no son constantes, así que lo que se pinta por código debe volver a pintarse cuando
## UiTheme emite `changed`. Los valores iniciales son los del tema oscuro.

static var BACKGROUND := Color("#0b111c")
static var PANEL := Color("#121b2b")
static var PANEL_BORDER := Color("#22314a")
## Bloques dentro de un panel (los dos grupos de la barra superior).
static var INSET := Color("#0f1726")
static var INSET_BORDER := Color("#1e2944")
## Tarjetas (mejoras, fichas, BYTE, diálogos).
static var CARD := Color("#16233a")
## Filas de la Tienda y tarjetas de personaje.
static var CARD_ALT := Color("#1b2232")
static var CARD_BORDER := Color("#3a4458")
static var CARD_BORDER_HOVER := Color("#5f6b85")
## Fondo de barras de progreso y sliders.
static var BAR_TRACK := Color("#0b111c")
static var HUD_TRACK := Color("#333847")
static var BUTTON_HOVER := Color("#1c2d4a")
static var BUTTON_PRESSED := Color("#24395c")
static var BUTTON_DISABLED := Color("#0f1726")
static var BUTTON_DISABLED_BORDER := Color("#1a2638")
static var BUTTON_ALERT := Color("#2a1620")
static var SWATCH_BORDER := Color("#0d0f17")
static var SWATCH_BORDER_HOVER := Color("#ccd9e6")
static var SCROLL_TRACK := Color("#ffffff")
static var ACCENT := Color("#5aa9ff")
static var HIGHLIGHT := Color("#4fc3f7")
static var OK := Color("#3ddc84")
static var WARNING := Color("#f5c542")
static var DANGER := Color("#ff4d5e")
static var MALICIOUS := Color("#b06cff")
static var BLOCKED := Color("#f59973")
static var CEO := Color("#e0569b")
static var TEXT := Color("#e6edf7")
static var TEXT_ON_ACCENT := Color("#ffffff")
static var TEXT_TITLE := Color("#ffffff")
static var TEXT_MUTED := Color("#8a9bb5")
static var TEXT_SOFT := Color("#b2bfd1")
static var TEXT_HINT := Color("#99a6b8")
static var LINK := Color("#24324a")

## Token de la paleta → variable de esta clase.
const _TOKENS := {
	&"bg": &"BACKGROUND", &"panel": &"PANEL", &"panel_border": &"PANEL_BORDER",
	&"inset": &"INSET", &"inset_border": &"INSET_BORDER", &"card": &"CARD", &"card_alt": &"CARD_ALT",
	&"card_border": &"CARD_BORDER", &"card_border_hover": &"CARD_BORDER_HOVER",
	&"bar_track": &"BAR_TRACK", &"hud_track": &"HUD_TRACK",
	&"button_hover": &"BUTTON_HOVER", &"button_pressed": &"BUTTON_PRESSED",
	&"button_disabled": &"BUTTON_DISABLED", &"button_disabled_border": &"BUTTON_DISABLED_BORDER",
	&"button_alert": &"BUTTON_ALERT", &"swatch_border": &"SWATCH_BORDER", &"swatch_border_hover": &"SWATCH_BORDER_HOVER",
	&"scroll_track": &"SCROLL_TRACK", &"accent": &"ACCENT", &"highlight": &"HIGHLIGHT", &"ok": &"OK",
	&"warning": &"WARNING", &"danger": &"DANGER", &"malicious": &"MALICIOUS", &"blocked": &"BLOCKED",
	&"ceo": &"CEO", &"text": &"TEXT", &"text_on_accent": &"TEXT_ON_ACCENT", &"text_title": &"TEXT_TITLE", &"text_muted": &"TEXT_MUTED",
	&"text_soft": &"TEXT_SOFT", &"text_hint": &"TEXT_HINT", &"link": &"LINK",
}


## La llama UiTheme al cambiar de tema.
static func use_palette(palette: Dictionary) -> void:
	var script: GDScript = load("res://scripts/dashboard/dashboard_colors.gd")
	for token: StringName in _TOKENS:
		if palette.has(token):
			script.set(_TOKENS[token], palette[token])


## Color de una barra de utilización: verde < 65 %, amarillo 65–85 %, rojo > 85 %.
static func for_utilization(utilization: float) -> Color:
	if utilization > 0.85:
		return DANGER
	if utilization >= 0.65:
		return WARNING
	return OK


static func panel_style(fill: Color = PANEL, border: Color = PANEL_BORDER, border_width: int = 2, radius: int = 14, margin: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


static func bar_style(fill: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(5)
	return style
