class_name DecorShop
extends RefCounted
## Reglas de la tienda de decoración (solo estética): cuándo abre, qué se puede comprar y cuánto
## se devuelve. Las monedas se mueven con Simulation.adjust_coins para que los checkpoints cuadren.
## Comprar mete el objeto al inventario de inmediato: si la app se cierra a mitad de la colocación,
## no se pierde nada.

## Etapa en la que completar desbloquea el trofeo.
const TROPHY_STAGE := &"scale_up"
const TEXT_LOCKED := "Disponible en Scale-up"
const TEXT_DURING_WAVE := "Solo entre oleadas"


static func is_unlocked() -> bool:
	return Simulation.stage != null and Simulation.stage.number >= DecorData.get_unlock_stage()


static func is_between_waves() -> bool:
	return Simulation.phase == Simulation.Phase.READY or Simulation.phase == Simulation.Phase.BETWEEN_WAVES


static func is_open() -> bool:
	return GameState.is_active and Simulation.has_session() and is_unlocked() and is_between_waves()


## Por qué la tienda está cerrada ("" si está abierta).
static func get_closed_reason() -> String:
	if not is_unlocked():
		return TEXT_LOCKED
	if not is_between_waves():
		return TEXT_DURING_WAVE
	return ""


static func is_trophy_claimable() -> bool:
	return Simulation.is_stage_completed(TROPHY_STAGE) and GameState.count_owned(DecorData.TROPHY_ID) == 0


## Por qué no se puede comprar ("" si se puede).
static func get_buy_block_reason(decor: DecorData) -> String:
	if decor.is_trophy():
		if GameState.count_owned(decor.id) > 0:
			return "Reclamado"
		if not Simulation.is_stage_completed(TROPHY_STAGE):
			return "Completa Scale-up"
	if Simulation.coins < decor.price:
		return "Faltan monedas"
	return ""


static func can_buy(decor: DecorData) -> bool:
	return is_open() and get_buy_block_reason(decor).is_empty()


static func buy(decor: DecorData) -> bool:
	if not can_buy(decor):
		return false
	Simulation.adjust_coins(-decor.price)
	GameState.add_to_inventory(decor.id)
	return true


## Cancela una compra recién hecha: sale del inventario y se devuelve el precio completo.
static func refund(decor: DecorData) -> void:
	if GameState.take_from_inventory(decor.id):
		Simulation.adjust_coins(decor.price)


static func sell_placed(room_id: StringName, index: int) -> bool:
	var entry: Dictionary = GameState.get_placed_decor(room_id)[index]
	var decor := DecorData.find(StringName(str(entry.get("id", ""))))
	if decor == null or decor.is_trophy():
		return false
	GameState.remove_placed_decor(room_id, index)
	Simulation.adjust_coins(decor.get_sell_price())
	return true


static func store_placed(room_id: StringName, index: int) -> void:
	var entry := GameState.remove_placed_decor(room_id, index)
	GameState.add_to_inventory(StringName(str(entry.get("id", ""))))
