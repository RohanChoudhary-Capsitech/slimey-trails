# class_name SettingsData
# Represents the 'settings' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name SettingsData

var music_enabled: bool = true
var sfx_enabled: bool = true
var haptics_enabled: bool = true
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var locale: String = "en"

func _init() -> void:
	schema_version = 1
