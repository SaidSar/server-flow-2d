class_name PetShop
extends RefCounted
## Reglas de compra de mascotas. Usan la misma Tienda que la decoración: abre en Scale-up y solo entre
## oleadas (DecorShop.is_open). Las monedas se mueven con Simulation.adjust_coins para que los checkpoints cuadren.
## También se pueden vender (entre oleadas, como comprar): devuelven venta_pct del precio y liberan un lugar del máximo.


## Por qué no se puede comprar ("" si se puede).
static func get_buy_block_reason(pet: PetData) -> String:
	if GameState.pets.size() >= PetData.get_max_total():
		return "Máximo de mascotas (%d)" % PetData.get_max_total()
	if Simulation.coins < pet.price:
		return "Faltan monedas"
	return ""


static func can_buy(pet: PetData) -> bool:
	return DecorShop.is_open() and get_buy_block_reason(pet).is_empty()


static func buy(pet: PetData) -> bool:
	if not can_buy(pet):
		return false
	Simulation.adjust_coins(-pet.price)
	GameState.add_pet(pet.id)
	return true


## Por qué no se puede vender ("" si se puede).
static func get_sell_block_reason(pet: PetData) -> String:
	if GameState.count_pets(pet.id) <= 0:
		return "No tienes ninguno"
	return ""


static func can_sell(pet: PetData) -> bool:
	return DecorShop.is_open() and get_sell_block_reason(pet).is_empty()


static func sell(pet: PetData) -> bool:
	if not can_sell(pet):
		return false
	# Primero las monedas y luego la mascota: pets_changed refresca la Tienda con el saldo ya actualizado.
	Simulation.adjust_coins(pet.get_sell_price())
	return GameState.remove_pet(pet.id)
