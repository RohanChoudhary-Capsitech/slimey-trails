extends BaseModel
class_name ExampleSettingsData

var audio_volume: float = 0.8
var screen_resolution: Vector2i = Vector2i(1920, 1080)
var vsync_enabled: bool = true

func serialize() -> Dictionary:
	return {
		"audio_volume": audio_volume,
		"screen_resolution_x": screen_resolution.x,
		"screen_resolution_y": screen_resolution.y,
		"vsync_enabled": vsync_enabled,
		"last_saved_timestamp": last_saved_timestamp
	}

func deserialize(dict: Dictionary) -> void:
	audio_volume = float(dict.get("audio_volume", 0.8))
	var res_x = int(dict.get("screen_resolution_x", 1920))
	var res_y = int(dict.get("screen_resolution_y", 1080))
	screen_resolution = Vector2i(res_x, res_y)
	vsync_enabled = bool(dict.get("vsync_enabled", true))
	last_saved_timestamp = float(dict.get("last_saved_timestamp", 0.0))

func clone() -> BaseModel:
	var copy = ExampleSettingsData.new()
	copy.audio_volume = audio_volume
	copy.screen_resolution = screen_resolution
	copy.vsync_enabled = vsync_enabled
	copy.last_saved_timestamp = last_saved_timestamp
	return copy

func equals(other: BaseModel) -> bool:
	var o = other as ExampleSettingsData
	if not o:
		return false
	return (
		is_equal_approx(audio_volume, o.audio_volume) and
		screen_resolution == o.screen_resolution and
		vsync_enabled == o.vsync_enabled
	)
