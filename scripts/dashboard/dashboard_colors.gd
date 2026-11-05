class_name DashboardColors
extends RefCounted
## Paleta del dashboard (panel de monitoreo oscuro) y helpers de estilo.

const BACKGROUND := Color("#0b111c")
const PANEL := Color("#121b2b")
const PANEL_BORDER := Color("#22314a")
## Bloques dentro de un panel (los dos grupos de la barra superior).
const INSET := Color("#0f1726")
const INSET_BORDER := Color("#1e2944")
const ACCENT := Color("#5aa9ff")
const OK := Color("#3ddc84")
const WARNING := Color("#f5c542")
const DANGER := Color("#ff4d5e")
const MALICIOUS := Color("#b06cff")
const TEXT := Color("#e6edf7")
const TEXT_MUTED := Color("#8a9bb5")
const LINK := Color("#24324a")


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
