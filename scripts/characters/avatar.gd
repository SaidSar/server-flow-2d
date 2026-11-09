class_name Avatar
extends Node2D
## Personaje sentado en la PC (Alex, Alexa... según su AvatarData). Alterna los cuadros de
## tecleo; con estrés muestra otro sprite. Las poses son recortes del mismo lienzo 2x que el
## cuarto; cada una tiene su propio offset.

const TYPING_FRAME_SECONDS := 0.25
## Aviso "!!" sobre la cabeza mientras hay saturación: salta y late para llamar la atención.
const ALERT_BOUNCE_PX := 14.0
const ALERT_BOUNCE_SECONDS := 0.28
const ALERT_SCALE := 1.18

@onready var _sprite: Sprite2D = %Sprite
@onready var _name_label: Label = %NameLabel
@onready var _frame_timer: Timer = %FrameTimer
@onready var _alert_label: Label = %AlertLabel

var _typing_textures: Array[Texture2D] = []
var _stressed_texture: Texture2D
var _frame := 0
var _is_stressed := false
var _alert_tween: Tween
var _alert_rest_y := 0.0
var _shirt_material: ShaderMaterial


func _ready() -> void:
	_frame_timer.wait_time = TYPING_FRAME_SECONDS
	_frame_timer.timeout.connect(_on_frame_timer_timeout)
	if _typing_textures.is_empty():
		set_avatar(AvatarData.find(AvatarData.DEFAULT_ID))
	GameState.color_changed.connect(_on_color_changed)


func set_avatar(data: AvatarData) -> void:
	_typing_textures = data.load_typing_textures()
	_stressed_texture = data.load_stressed_texture()
	_frame = 0
	_refresh_texture()
	_setup_shirt(data)


## Color de la camiseta: se recolorea la sudadera con un shader (ver assets/shaders/camiseta.gdshader).
func set_shirt(option_id: StringName) -> void:
	if _shirt_material == null:
		return
	var option := Customization.find_option(&"camiseta", option_id)
	# "Original" (o un id desconocido) deja el render tal cual.
	var recolor := option != null and option_id != Customization.get_default_option(&"camiseta")
	_shirt_material.set_shader_parameter(&"recolor", recolor)
	if recolor:
		_shirt_material.set_shader_parameter(&"target", option.color)


func is_shirt_recolored() -> bool:
	return _shirt_material != null and bool(_shirt_material.get_shader_parameter(&"recolor"))


func _setup_shirt(data: AvatarData) -> void:
	if _shirt_material == null:
		_shirt_material = ShaderMaterial.new()
		_shirt_material.shader = load(Paths.SHIRT_SHADER) as Shader
		_sprite.material = _shirt_material
	_shirt_material.set_shader_parameter(&"base_hue", data.shirt_hue)
	_shirt_material.set_shader_parameter(&"base_sv", Vector2(data.shirt_saturation, data.shirt_value))
	set_shirt(GameState.get_color(&"camiseta"))


func _on_color_changed(layer: StringName, option_id: StringName) -> void:
	if layer == &"camiseta":
		set_shirt(option_id)


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
	_refresh_alert()


func is_stressed() -> bool:
	return _is_stressed


## ¿Se ve el "!!" sobre la cabeza?
func is_alert_visible() -> bool:
	return _alert_label.visible


func _refresh_alert() -> void:
	if _alert_tween != null:
		_alert_tween.kill()
		_alert_tween = null
	if _alert_rest_y == 0.0:
		_alert_rest_y = _alert_label.position.y
	_alert_label.position.y = _alert_rest_y
	_alert_label.scale = Vector2.ONE
	_alert_label.visible = _is_stressed
	if not _is_stressed:
		return
	_alert_tween = create_tween().set_loops()
	_alert_tween.set_parallel().set_trans(Tween.TRANS_SINE)
	_alert_tween.tween_property(_alert_label, "position:y", _alert_rest_y - ALERT_BOUNCE_PX, ALERT_BOUNCE_SECONDS).set_ease(Tween.EASE_OUT)
	_alert_tween.tween_property(_alert_label, "scale", Vector2.ONE * ALERT_SCALE, ALERT_BOUNCE_SECONDS).set_ease(Tween.EASE_OUT)
	_alert_tween.chain().set_parallel()
	_alert_tween.tween_property(_alert_label, "position:y", _alert_rest_y, ALERT_BOUNCE_SECONDS).set_ease(Tween.EASE_IN)
	_alert_tween.tween_property(_alert_label, "scale", Vector2.ONE, ALERT_BOUNCE_SECONDS).set_ease(Tween.EASE_IN)


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
