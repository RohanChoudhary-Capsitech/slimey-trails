extends BaseRepository
class_name ExampleSettingsRepository

func _init(cache: MemoryCache) -> void:
	super("Settings", ExampleSettingsData, cache)
	
	# Configure this repository to NOT sync with the remote cloud database.
	# Any changes to audio/video options will remain local to the active device.
	is_cloud_synced = false

func set_volume(volume: float) -> void:
	var data = get_data() as ExampleSettingsData
	if data:
		data.audio_volume = clampf(volume, 0.0, 1.0)
		mark_dirty()

func toggle_vsync(enabled: bool) -> void:
	var data = get_data() as ExampleSettingsData
	if data:
		data.vsync_enabled = enabled
		mark_dirty()
