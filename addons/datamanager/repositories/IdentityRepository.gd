# class_name IdentityRepository
# Manages the 'identity' bucket in the Unified Game Data Model.
extends BaseRepository
class_name IdentityRepository

func _init(cache: MemoryCache) -> void:
	super("identity", IdentityData, cache)
	is_cloud_synced = true

func get_identity_data() -> IdentityData:
	return get_data() as IdentityData
