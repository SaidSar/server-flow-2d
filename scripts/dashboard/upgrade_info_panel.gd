class_name UpgradeInfoPanel
extends Control
## Panel modal con la ficha de una mejora. Se abre al mantener presionada una mejora o al tocar su "i".

@onready var _card: UpgradeInfoCard = %Card
@onready var _close_button: Button = %CloseButton
@onready var _dimmer: ColorRect = %Dimmer


func _ready() -> void:
	_close_button.pressed.connect(hide)
	_dimmer.gui_input.connect(_on_dimmer_input)
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		hide()
		get_viewport().set_input_as_handled()


func show_upgrade(upgrade: UpgradeData) -> void:
	_card.setup(upgrade)
	show()
	_close_button.grab_focus()


## Tocar fuera de la ficha también la cierra.
func _on_dimmer_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		hide()
