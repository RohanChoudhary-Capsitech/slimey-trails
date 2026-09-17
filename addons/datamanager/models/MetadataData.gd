# class_name MetadataData
# Represents the 'metadata' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name MetadataData

var revision: int = 1
var created_at: float = 0.0
var last_login_at: float = 0.0
var last_saved_at: float = 0.0
var dirty_buckets: Dictionary = {} # bucket_name -> boolean
var values: Dictionary = {}        # custom/arbitrary key-values

func _init() -> void:
	schema_version = 1
	var now = Time.get_unix_time_from_system()
	created_at = now
	last_login_at = now
	last_saved_at = now
