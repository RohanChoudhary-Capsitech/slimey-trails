# class_name LiveOpsData
# Represents the 'liveOps' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name LiveOpsData

var daily_reward: Dictionary = {
	"current_day": 1,
	"last_claimed_date": "",
	"streak": 0
}
var chests: Dictionary = {} # chestId -> { claimed: bool, claimedAt: int }

func _init() -> void:
	schema_version = 1
