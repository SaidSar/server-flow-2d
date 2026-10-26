class_name Avatar
extends Node2D
## Personaje sentado en la PC (Alex, Alexa... según su AvatarData). Alterna los cuadros de
## tecleo; con estrés muestra otro sprite. Las poses son recortes del mismo lienzo 2x que el
## cuarto; cada una tiene su propio offset.

const TYPING_FRAME_SECONDS := 0.25

@onready var _sprite: Sprite2D = %Sprite
@onready var _name_label: Label = %NameLabel
@onready var _frame_timer: Timer = %FrameTimer

var _typing_textures: Array[Texture2D] = []
var _stressed_texture: Texture2D
var _frame := 0
var _is_stressed := false


func _ready() -> void:
	_frame_timer.wait_time = TYPING_FRAME_SECONDS
	_frame_timer.timeout.connect(_on_frame_timer_timeout)
	if _typing_textures.is_empty():
		set_avatar(AvatarData.find(AvatarData.DEFAULT_ID))


func set_avatar(data: AvatarData) -> void:
	_typing_textures = data.load_typing_textures()
	_stressed_texture = data.load_stressed_texture()
	_frame = 0
	_refresh_texture()


func set_display_name(display_name: String) -> void:
	_name_label.text = display_name
	_name_label.visible = not display_name.is_empty()


func set_stressed(stressed: bool) -> void:
	if stressed == _is_stressed:
		return
	_is_stressed = stressed
	if stressed:
		_frame_timer.stop()
	else:
		_frame_timer.start()
	_refresh_texture()


func is_stressed() -> bool:
	return _is_stressed


func _on_frame_timer_timeout() -> void:
	if _typing_textures.is_empty():
		return
	_frame = (_frame + 1) % _typing_textures.size()
	_refresh_texture()


func _refresh_texture() -> void:
	if _is_stressed and _stressed_texture != null:
		Customization.apply_layer(_sprite, _stressed_texture)
	elif not _typing_textures.is_empty():
		Customization.apply_layer(_sprite, _typing_textures[_frame])
