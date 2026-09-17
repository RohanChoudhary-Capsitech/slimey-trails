extends BaseModel
class_name ExampleCurrencyData

var coins: int = 0
var silver_stamps: int = 0
var gold_stamps: int = 0
var free_paperplanes: int = 1
var free_jump_boosts: int = 1
var powerup_buy_limit: int = 3

func serialize() -> Dictionary:
	return {
		"coins": coins,
		"silver_stamps": silver_stamps,
		"gold_stamps": gold_stamps,
		"free_paperplanes": free_paperplanes,
		"free_jump_boosts": free_jump_boosts,
		"powerup_buy_limit": powerup_buy_limit,
		"last_saved_timestamp": last_saved_timestamp
	}

func deserialize(dict: Dictionary) -> void:
	coins = int(dict.get("coins", 0))
	silver_stamps = int(dict.get("silver_stamps", 0))
	gold_stamps = int(dict.get("gold_stamps", 0))
	free_paperplanes = int(dict.get("free_paperplanes", 1))
	free_jump_boosts = int(dict.get("free_jump_boosts", 1))
	powerup_buy_limit = int(dict.get("powerup_buy_limit", 3))
	last_saved_timestamp = float(dict.get("last_saved_timestamp", 0.0))

func clone() -> BaseModel:
	var copy = ExampleCurrencyData.new()
	copy.coins = coins
	copy.silver_stamps = silver_stamps
	copy.gold_stamps = gold_stamps
	copy.free_paperplanes = free_paperplanes
	copy.free_jump_boosts = free_jump_boosts
	copy.powerup_buy_limit = powerup_buy_limit
	copy.last_saved_timestamp = last_saved_timestamp
	return copy

func equals(other: BaseModel) -> bool:
	var o = other as ExampleCurrencyData
	if not o:
		return false
	return (
		coins == o.coins and
		silver_stamps == o.silver_stamps and
		gold_stamps == o.gold_stamps and
		free_paperplanes == o.free_paperplanes and
		free_jump_boosts == o.free_jump_boosts and
		powerup_buy_limit == o.powerup_buy_limit
	)
