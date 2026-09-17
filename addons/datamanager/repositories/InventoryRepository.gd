# class_name InventoryRepository
# Manages the 'inventory' bucket in the Unified Game Data Model.
extends BaseRepository
class_name InventoryRepository

func _init(cache: MemoryCache) -> void:
	super("inventory", InventoryData, cache)
	is_cloud_synced = true

func get_inventory_data() -> InventoryData:
	return get_data() as InventoryData
