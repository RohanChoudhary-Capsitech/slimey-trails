# class_name InventoryData
# Represents the 'inventory' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name InventoryData

var equipped: Dictionary = {} # slot_type -> item_id
var owned: Dictionary = {} # category -> array<item_id>
var boosters: Dictionary = {} # booster_id -> count

func _init() -> void:
	schema_version = 1
