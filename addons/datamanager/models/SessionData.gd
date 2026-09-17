# class_name SessionData
# Represents the 'session' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name SessionData

var screen_time_seconds: float = 0.0
var last_session_date_utc: String = ""
var session_count: int = 1

func _init() -> void:
	schema_version = 1
