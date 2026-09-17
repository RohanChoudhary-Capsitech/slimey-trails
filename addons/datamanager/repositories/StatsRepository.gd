# class_name StatsRepository
# Manages the 'stats' bucket in the Unified Game Data Model.
extends BaseRepository
class_name StatsRepository

func _init(cache: MemoryCache) -> void:
	super("stats", StatsData, cache)
	is_cloud_synced = true

func get_stats_data() -> StatsData:
	return get_data() as StatsData
