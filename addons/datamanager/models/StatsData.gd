# class_name StatsData
# Represents the 'stats' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name StatsData

var matches_played: int = 0
var matches_won: int = 0
var matches_lost: int = 0
var win_streak: int = 0
var custom: Dictionary = {} # Genre-specific counters (level_attempts_by_level, accuracy, etc.)

func _init() -> void:
	schema_version = 1
