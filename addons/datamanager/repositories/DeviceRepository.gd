# class_name DeviceRepository
# Manages the 'device' bucket in the Unified Game Data Model.
extends BaseRepository
class_name DeviceRepository

func _init(cache: MemoryCache) -> void:
	super("device", DeviceData, cache)
	is_cloud_synced = true

func get_device_data() -> DeviceData:
	return get_data() as DeviceData
