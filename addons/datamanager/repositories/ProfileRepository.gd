# class_name ProfileRepository
# Manages the 'profile' bucket in the Unified Game Data Model.
extends BaseRepository
class_name ProfileRepository

func _init(cache: MemoryCache) -> void:
	super("profile", ProfileData, cache)
	is_cloud_synced = true

func get_profile_data() -> ProfileData:
	return get_data() as ProfileData
