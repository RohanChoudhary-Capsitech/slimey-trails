# class_name MetadataRepository
# Manages the 'metadata' bucket in the Unified Game Data Model.
extends BaseRepository
class_name MetadataRepository

func _init(cache: MemoryCache) -> void:
	super("metadata", MetadataData, cache)
	is_cloud_synced = true

func get_metadata_data() -> MetadataData:
	return get_data() as MetadataData
