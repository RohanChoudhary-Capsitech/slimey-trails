# class_name MonetizationRepository
# Manages the 'monetization' bucket in the Unified Game Data Model.
extends BaseRepository
class_name MonetizationRepository

func _init(cache: MemoryCache) -> void:
	super("monetization", MonetizationData, cache)
	is_cloud_synced = true

func get_monetization_data() -> MonetizationData:
	return get_data() as MonetizationData
