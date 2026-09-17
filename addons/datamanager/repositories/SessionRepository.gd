# class_name SessionRepository
# Manages the 'session' bucket in the Unified Game Data Model.
extends BaseRepository
class_name SessionRepository

func _init(cache: MemoryCache) -> void:
	super("session", SessionData, cache)
	is_cloud_synced = true

func get_session_data() -> SessionData:
	return get_data() as SessionData
