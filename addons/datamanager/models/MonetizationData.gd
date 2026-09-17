# class_name MonetizationData
# Represents the 'monetization' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name MonetizationData

var ad_watch_counts: Dictionary = {} # adType -> number
var remove_ads_purchased: bool = false
var purchase_history: Array = [] # array<{ productId: string, timestamp: number }>
var entitlements: Dictionary = {} # map<string, any>

func _init() -> void:
	schema_version = 1
