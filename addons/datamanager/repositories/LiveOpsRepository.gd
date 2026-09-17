# class_name LiveOpsRepository
# Manages the 'liveOps' bucket in the Unified Game Data Model.
extends BaseRepository
class_name LiveOpsRepository

func _init(cache: MemoryCache) -> void:
	super("liveOps", LiveOpsData, cache)
	is_cloud_synced = true

func get_live_ops_data() -> LiveOpsData:
	return get_data() as LiveOpsData
