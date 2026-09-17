# class_name TutorialsData
# Represents the 'tutorials' bucket in the Unified Game Data Model.
# Serialized to snake_case automatically by BaseModel reflection.
extends BaseModel
class_name TutorialsData

var seen: Dictionary = {} # tutorialId -> bool
var ftue_completed: bool = false
var terms_accepted: bool = false

func _init() -> void:
	schema_version = 1
