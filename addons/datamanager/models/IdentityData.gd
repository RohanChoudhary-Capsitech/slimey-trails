# class_name IdentityData
# Represents the 'identity' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name IdentityData

var user_id: String = ""
var auth_provider: String = "guest" # "guest" | "google" | "apple" | "playgames"
var signed_in: bool = false
var email: Variant = null
var fcm_token: String = ""

func _init() -> void:
	schema_version = 1
