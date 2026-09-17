# class_name ProfileData
# Represents the 'profile' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name ProfileData

var display_name: String = "Player"
var is_custom_name: bool = false
var avatar_id: String = "default"
var frame_id: String = ""
var badge_id: String = ""
var country_code: String = ""
var photo_url: Variant = null
var player_title: String = "Novice" # 👈 NEW FIELD ADDED HERE

func _init() -> void:
	schema_version = 1
