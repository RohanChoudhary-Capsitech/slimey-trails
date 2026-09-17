# class_name ProgressionRepository
# Manages the 'progression' bucket in the Unified Game Data Model.
extends BaseRepository
class_name ProgressionRepository

func _init(cache: MemoryCache) -> void:
	super("progression", ProgressionData, cache)
	is_cloud_synced = true

func get_progression_data() -> ProgressionData:
	return get_data() as ProgressionData
