extends Control
## Panel de control (el monitor de la PC del avatar): HUD, monitor de tráfico y consola de mejoras.
## Solo escucha a Simulation y le manda órdenes (comprar, siguiente oleada...); no calcula nada.

const UPGRADE_BUTTON_SCENE := preload("res://scenes/dashboard/upgrade_button.tscn")
## Hueco al final de la consola: ahí flota el engranaje de Ajustes (esquina inferior derecha).
const SETTINGS_SLOT_NAME := "SettingsSlot"
## La CEO que anuncia la ronda de inversión.
const CEO_NAME := "Briseida"
const CEO_ROLE := "CEO"
const CEO_COLOR := Color("#e0569b")
## Con género (TextUtil.format): "{masculino|femenino}".
const INVESTMENT_TEXT := "¡%s, lo logramos! Eres {el mejor|la mejor} SysAdmin que podíamos pedir. Conseguimos una ronda de inversión: +%s monedas para escalar %s."
const INVESTMENT_BUTTON := "¡Vamos!"
const SPEEDS: Array[float] = [1.0, 2.0]
const BACK_FADE_SECONDS := 0.15
const RESOURCE_NAMES := {
	&"cpu": "CPU",
	&"ram": "RAM",
	&"net": "Red",
	&"db": "Consultas",
	&"disk": "Disco",
}
const LEGEND := [
	[DashboardColors.OK, "200 OK"],
	[DashboardColors.WARNING, "Latencia alta"],
	[DashboardColors.DANGER, "Timeout / Error 500"],
	[DashboardColors.MALICIOUS, "Tráfico malicioso (DDoS)"],
]
const SLA_GOOD := 80.0
const SLA_WARNING := 50.0

## Recursos de los que BYTE ya avisó en esta sesión del juego (solo la primera vez que pasan de 85 %).
static var _warned_resources: Dictionary[StringName, bool] = {}

@onready var _title_label: Label = %TitleLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _coins_label: Label = %CoinsLabel
@onready var _users_label: Label = %UsersLabel
@onready var _users_bar: ProgressBar = %UsersBar
@onready var _sla_label: Label = %SlaLabel
@onready var _sla_bar: ProgressBar = %SlaBar
@onready var _speed_button: Button = %SpeedButton
@onready var _back_button: Button = %BackButton
@onready var _top_bar: PanelContainer = %TopBar
@onready var _margin: MarginContainer = $Margin
@onready var _monitor_panel: PanelContainer = %MonitorPanel
@onready var _console_panel: PanelContainer = %ConsolePanel
@onready var _bottleneck_label: Label = %BottleneckLabel
@onready var _legend_box: HBoxContainer = %LegendBox
@onready var _byte: ByteBubble = %ByteBubble
@onready var _upgrade_grid: GridContainer = %UpgradeGrid
@onready var _firewall_check: CheckButton = %FirewallCheck
@onready var _postmortem: Postmortem = %Postmortem
@onready var _game_over: GameOver = %GameOver
@onready var _victory: Victory = %Victory
@onready var _goal_missed: GoalMissed = %GoalMissed
@onready var _upgrade_info: UpgradeInfoPanel = %UpgradeInfoPanel
@onready var _dialog: DialogBox = %DialogBox

var _upgrade_buttons: Array[UpgradeButton] = []
var _sla_fill := DashboardColors.bar_style(DashboardColors.OK)
var _users_fill := DashboardColors.bar_style(DashboardColors.ACCENT)


func _ready() -> void:
	# Abrir esta escena sola (F6) arranca una partida de prueba.
	if not Simulation.has_session():
		Simulation.new_game()

	_top_bar.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.PANEL_BORDER, 2, 14, 14.0))
	_monitor_panel.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.PANEL_BORDER, 2, 14, 6.0))
	_console_panel.add_theme_stylebox_override(&"panel", DashboardColors.panel_style(DashboardColors.PANEL, DashboardColors.PANEL_BORDER, 2, 14, 16.0))
	_sla_bar.add_theme_stylebox_override(&"fill", _sla_fill)
	_sla_bar.add_theme_stylebox_override(&"background", DashboardColors.bar_style(DashboardColors.BACKGROUND))
	_users_bar.add_theme_stylebox_override(&"fill", _users_fill)
	_users_bar.add_theme_stylebox_override(&"background", DashboardColors.bar_style(DashboardColors.BACKGROUND))
	# Respeta la cámara frontal y la barra de gestos del celular.
	_fit_safe_area()
	SceneRouter.safe_area_changed.connect(_fit_safe_area)
	_build_legend()
	_build_console()

	Simulation.tick.connect(_on_tick)
	Simulation.bottleneck_changed.connect(_on_bottleneck_changed)
	Simulation.wave_started.connect(_on_wave_started)
	Simulation.wave_finished.connect(_on_wave_finished)
	Simulation.stage_completed.connect(_on_stage_completed)
	Simulation.game_over.connect(_on_game_over)
	Simulation.stage_failed.connect(_on_stage_failed)
	Simulation.infrastructure_changed.connect(_refresh)
	Simulation.phase_changed.connect(_on_phase_changed)
	_speed_button.pressed.connect(_on_speed_pressed)
	_back_button.pressed.connect(_go_to_room)
	_firewall_check.toggled.connect(Simulation.set_firewall_on)
	_postmortem.next_wave_requested.connect(_on_next_wave_requested)
	_postmortem.room_requested.connect(_go_to_room)
	_postmortem.shop_requested.connect(_on_shop_requested)
	_game_over.retry_requested.connect(_on_retry_requested)
	_game_over.menu_requested.connect(_on_menu_requested)
	_victory.continue_requested.connect(_on_victory_continue)
	_goal_missed.repeat_requested.connect(_on_repeat_stage_requested)
	_goal_missed.room_requested.connect(_go_to_room)

	_on_bottleneck_changed(Simulation.bottleneck, Simulation.bottleneck_node)
	_refresh()
	_resume()


func _process(_delta: float) -> void:
	if _bottleneck_label.visible:
		_bottleneck_label.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") and not _is_blocking_modal_open():
		_go_to_room()
		get_viewport().set_input_as_handled()


func _fit_safe_area() -> void:
	SafeArea.fit_full_rect(_margin)


## Pantallas que no se cierran con Esc (hay que elegir una opción).
func _is_blocking_modal_open() -> bool:
	return _game_over.visible or _victory.visible or _goal_missed.visible or _dialog.visible


## Retoma lo que estaba pasando al abrir el dashboard (la simulación sigue aunque estés en el garage).
func _resume() -> void:
	if Simulation.pending_stage_report != null:
		_show_victory(Simulation.pending_stage_report)
		return
	match Simulation.phase:
		Simulation.Phase.READY:
			Simulation.start_wave()
		Simulation.Phase.BETWEEN_WAVES:
			_show_postmortem(Simulation.report)
		Simulation.Phase.GAME_OVER:
			_on_game_over(Simulation.report)
		Simulation.Phase.STAGE_FAILED:
			_on_stage_failed(Simulation.report)


#region HUD

func _on_tick(_snapshot: SimSnapshot) -> void:
	_refresh()


func _refresh() -> void:
	var stage := Simulation.stage
	_title_label.text = "%s · %s" % [_company_name(), stage.display_name]
	var wave_text := "Oleada %d/%d" % [Simulation.wave_number, Simulation.get_wave_count()]
	if Simulation.phase == Simulation.Phase.RUNNING:
		wave_text += " · %d s" % maxi(ceili(Simulation.wave.duration_s - Simulation.wave_time), 0)
	_wave_label.text = wave_text
	_coins_label.text = NumberFormat.thousands(Simulation.coins)
	_users_label.text = "%s / %s" % [NumberFormat.thousands(Simulation.users_served), NumberFormat.thousands(stage.user_goal)]
	_users_bar.max_value = maxi(stage.user_goal, 1)
	_users_bar.value = mini(Simulation.users_served, stage.user_goal)
	var goal_reached := Simulation.users_served >= stage.user_goal
	_users_fill.bg_color = DashboardColors.OK if goal_reached else DashboardColors.ACCENT
	_users_label.add_theme_color_override(&"font_color", DashboardColors.OK if goal_reached else DashboardColors.TEXT)
	_sla_label.text = "SLA %.1f %%" % Simulation.sla
	_sla_bar.value = Simulation.sla
	if Simulation.sla >= SLA_GOOD:
		_sla_fill.bg_color = DashboardColors.OK
	elif Simulation.sla >= SLA_WARNING:
		_sla_fill.bg_color = DashboardColors.WARNING
	else:
		_sla_fill.bg_color = DashboardColors.DANGER
	_speed_button.text = "%d×" % roundi(Simulation.speed)
	_firewall_check.visible = Simulation.has_firewall
	_firewall_check.set_pressed_no_signal(Simulation.firewall_on)
	for button: UpgradeButton in _upgrade_buttons:
		button.refresh()


func _on_phase_changed(_phase: Simulation.Phase) -> void:
	_refresh()


func _on_speed_pressed() -> void:
	var index := SPEEDS.find(Simulation.speed)
	Simulation.set_speed(SPEEDS[(index + 1) % SPEEDS.size()])
	_refresh()

#endregion


#region Monitor y BYTE

func _build_legend() -> void:
	for entry: Array in LEGEND:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.bg_color = entry[0]
		style.set_corner_radius_all(9)
		dot.add_theme_stylebox_override(&"panel", style)
		_legend_box.add_child(dot)
		var label := Label.new()
		label.text = entry[1]
		label.add_theme_font_size_override(&"font_size", 18)
		label.add_theme_color_override(&"font_color", DashboardColors.TEXT_MUTED)
		_legend_box.add_child(label)


func _on_bottleneck_changed(resource: StringName, node: StringName) -> void:
	_bottleneck_label.visible = resource != &""
	if resource == &"":
		_highlight_fixes(&"")
		return
	_bottleneck_label.text = _bottleneck_text(resource, node)
	_highlight_fixes(resource)
	if not _warned_resources.has(resource):
		_warned_resources[resource] = true
		_byte.say(_byte_warning(resource))


func _bottleneck_text(resource: StringName, node: StringName) -> String:
	if resource == &"ddos":
		return "⚠ Ataque DDoS: tráfico malicioso saturando los servidores web"
	var node_name := "de la base de datos"
	if node == Simulation.NODE_WEB:
		node_name = "de los servidores web" if Simulation.servers.size() > 1 else "del Servidor Web #1"
	return "⚠ Cuello de botella: %s %s" % [RESOURCE_NAMES.get(resource, resource), node_name]


func _byte_warning(resource: StringName) -> String:
	var fixes := PackedStringArray()
	for upgrade: UpgradeData in Simulation.get_upgrades():
		if resource in upgrade.fixes and Simulation.is_unlocked(upgrade):
			fixes.append(upgrade.display_name)
	if resource == &"ddos":
		return "¡Tráfico malicioso! Los paquetes morados son un ataque DDoS. %s" % (
			"Enciende el Firewall para bloquearlos." if Simulation.has_firewall else "Instala el Firewall para bloquearlos.")
	var advice := " Compra %s en la consola." % " o ".join(fixes) if not fixes.is_empty() else ""
	return "%s pasó del 85 %%: es el cuello de botella.%s" % [RESOURCE_NAMES.get(resource, resource), advice]


func _on_wave_started(_wave_number: int) -> void:
	_postmortem.hide()
	_game_over.hide()
	_byte.say(TextUtil.format(Simulation.wave.tutorial_text))
	_refresh()

#endregion


#region Consola

func _build_console() -> void:
	for upgrade: UpgradeData in Simulation.get_upgrades():
		var button := UPGRADE_BUTTON_SCENE.instantiate() as UpgradeButton
		_upgrade_grid.add_child(button)
		button.setup(upgrade)
		button.purchase_requested.connect(_on_purchase_requested)
		button.info_requested.connect(_on_info_requested)
		_upgrade_buttons.append(button)
	var settings_slot := Control.new()
	settings_slot.name = SETTINGS_SLOT_NAME
	settings_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_slot.custom_minimum_size.y = UpgradeButton.HEIGHT
	_upgrade_grid.add_child(settings_slot)


func _highlight_fixes(resource: StringName) -> void:
	for button: UpgradeButton in _upgrade_buttons:
		button.set_highlighted(resource != &"" and resource in button.upgrade.fixes and Simulation.is_unlocked(button.upgrade))


func _on_purchase_requested(upgrade_id: StringName) -> void:
	Simulation.purchase(upgrade_id)


func _on_info_requested(upgrade_id: StringName) -> void:
	var upgrade := Simulation.get_upgrade(upgrade_id)
	if upgrade != null:
		_upgrade_info.show_upgrade(upgrade)


func get_upgrade_button(upgrade_id: StringName) -> UpgradeButton:
	for button: UpgradeButton in _upgrade_buttons:
		if button.upgrade.id == upgrade_id:
			return button
	return null

#endregion


#region Fin de oleada

func _on_wave_finished(report: WaveReport) -> void:
	_show_postmortem(report)


func _show_postmortem(report: WaveReport) -> void:
	_byte.clear()
	_postmortem.show_report(report, Simulation.wave_number, Simulation.get_wave_count())


func _on_next_wave_requested() -> void:
	Simulation.start_wave()


func _on_game_over(report: WaveReport) -> void:
	_byte.clear()
	_postmortem.hide()
	_game_over.show_report(report, _company_name())


func _on_stage_failed(report: WaveReport) -> void:
	_byte.clear()
	_postmortem.hide()
	_goal_missed.show_report(report)


func _on_repeat_stage_requested() -> void:
	_goal_missed.hide()
	Simulation.repeat_stage()


func _on_retry_requested() -> void:
	Simulation.retry_wave()


func _on_menu_requested() -> void:
	SceneRouter.goto(Paths.TITLE_MENU)


func _on_stage_completed(report: WaveReport) -> void:
	_show_victory(report)


func _show_victory(report: WaveReport) -> void:
	_byte.clear()
	_postmortem.hide()
	var completed_stage := Simulation.load_stage(report.stage_id)
	var unlock_names := PackedStringArray()
	var investment := 0
	if Simulation.stage.id != report.stage_id:
		investment = Simulation.stage.investment_coins
		for upgrade_id: StringName in Simulation.stage.unlocks:
			var upgrade := Simulation.get_upgrade(upgrade_id)
			if upgrade != null:
				unlock_names.append(upgrade.display_name)
	_victory.show_report(report, completed_stage.display_name, unlock_names, investment)


func _on_victory_continue() -> void:
	_victory.hide()
	# Antes de entregar la ronda de inversión, Briseida la anuncia.
	if Simulation.pending_investment > 0:
		var avatar := GameState.avatar_name if not GameState.avatar_name.is_empty() else "equipo"
		_dialog.show_dialog(CEO_NAME, CEO_ROLE,
			TextUtil.format(INVESTMENT_TEXT % [avatar, NumberFormat.thousands(Simulation.pending_investment), _company_name()]),
			INVESTMENT_BUTTON, CEO_COLOR)
		await _dialog.closed
	Simulation.acknowledge_stage_report()
	_go_to_room()

#endregion


func _company_name() -> String:
	return GameState.company_name if not GameState.company_name.is_empty() else Hud.DEFAULT_COMPANY_NAME


## Botón "Tienda" del post-mortem: vuelve al cuarto y abre la tienda al llegar.
func _on_shop_requested() -> void:
	if not SceneRouter.is_changing():
		SceneRouter.open_shop_on_return = true
		_go_to_room()


func _go_to_room() -> void:
	if SceneRouter.is_changing():
		return
	SceneRouter.returning_from_dashboard = true
	SceneRouter.goto_current_room(BACK_FADE_SECONDS)
