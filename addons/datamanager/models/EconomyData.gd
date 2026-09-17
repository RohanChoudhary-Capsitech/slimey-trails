# class_name EconomyData
# Represents the 'economy' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name EconomyData

var currencies: Dictionary = {
	"coins": 0,
	"lives": 3
}

func _init() -> void:
	schema_version = 1
