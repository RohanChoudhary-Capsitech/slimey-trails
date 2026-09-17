extends BaseRepository
class_name ExampleProfileRepository

func _init(cache: MemoryCache) -> void:
	super("Profile", ExampleProfileData, cache)
	is_cloud_synced = true

func update_player_name(new_name: String) -> void:
	var data = get_data() as ExampleProfileData
	if data:
		data.player_name = new_name
		mark_dirty()

func set_ftue_completed(completed: bool) -> void:
	var data = get_data() as ExampleProfileData
	if data:
		data.ftue_completed = completed
		mark_dirty()
