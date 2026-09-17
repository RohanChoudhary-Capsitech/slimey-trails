# class_name ProgressionData
# Represents the 'progression' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name ProgressionData

var current_level: int = 1
var unlocked_levels: int = 1
var level_stars: Dictionary = {} # level_id -> int
var xp: int = 0
var areas: Dictionary = {} # area_id -> AreaProgress
var achievements_unlocked: Array = []

func _init() -> void:
	schema_version = 1
