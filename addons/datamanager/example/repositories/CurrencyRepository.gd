extends BaseRepository
class_name ExampleCurrencyRepository

func _init(cache: MemoryCache) -> void:
	super("Currency", ExampleCurrencyData, cache)
	is_cloud_synced = true

func add_coins(amount: int) -> void:
	var data = get_data() as ExampleCurrencyData
	if data:
		data.coins += amount
		mark_dirty()

func spend_coins(amount: int) -> bool:
	var data = get_data() as ExampleCurrencyData
	if data and data.coins >= amount:
		data.coins -= amount
		mark_dirty()
		return true
	return false

func add_gold_stamps(amount: int) -> void:
	var data = get_data() as ExampleCurrencyData
	if data:
		data.gold_stamps += amount
		mark_dirty()

func buy_powerup(type: String) -> bool:
	var data = get_data() as ExampleCurrencyData
	if not data:
		return false
		
	# Assume powerups cost 100 coins each
	const POWERUP_COST = 100
	
	if data.coins < POWERUP_COST:
		return false
		
	match type:
		"paperplane":
			if data.free_paperplanes < data.powerup_buy_limit:
				data.coins -= POWERUP_COST
				data.free_paperplanes += 1
				mark_dirty()
				return true
		"jump_boost":
			if data.free_jump_boosts < data.powerup_buy_limit:
				data.coins -= POWERUP_COST
				data.free_jump_boosts += 1
				mark_dirty()
				return true
				
	return false
