# class_name SettingsRepository
# Manages the 'settings' bucket in the Unified Game Data Model.
extends BaseRepository
class_name SettingsRepository

func _init(cache: MemoryCache) -> void:
	super("settings", SettingsData, cache)
	is_cloud_synced = true

func get_settings_data() -> SettingsData:
	return get_data() as SettingsData
