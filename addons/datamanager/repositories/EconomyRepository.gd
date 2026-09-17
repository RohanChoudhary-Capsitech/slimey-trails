# class_name EconomyRepository
# Manages the 'economy' bucket in the Unified Game Data Model.
extends BaseRepository
class_name EconomyRepository

func _init(cache: MemoryCache) -> void:
	super("economy", EconomyData, cache)
	is_cloud_synced = true

func get_economy_data() -> EconomyData:
	return get_data() as EconomyData
