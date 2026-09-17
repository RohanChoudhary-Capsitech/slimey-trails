# class_name DeviceData
# Represents the 'device' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name DeviceData

var app_version: String = "1.0.0"

func _init() -> void:
	schema_version = 1
