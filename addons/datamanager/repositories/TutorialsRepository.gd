# class_name TutorialsRepository
# Manages the 'tutorials' bucket in the Unified Game Data Model.
extends BaseRepository
class_name TutorialsRepository

func _init(cache: MemoryCache) -> void:
	super("tutorials", TutorialsData, cache)
	is_cloud_synced = true

func get_tutorials_data() -> TutorialsData:
	return get_data() as TutorialsData
