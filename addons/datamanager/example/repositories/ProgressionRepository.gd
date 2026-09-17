extends BaseRepository
class_name ExampleProgressionRepository

func _init(cache: MemoryCache) -> void:
	super("Progression", ExampleProgressionData, cache)
	is_cloud_synced = true

func update_high_score(score: int) -> bool:
	var data = get_data() as ExampleProgressionData
	if data and score > data.high_score:
		data.high_score = score
		mark_dirty()
		return true
	return false

func record_jumps(count: int) -> void:
	var data = get_data() as ExampleProgressionData
	if data:
		var current = int(data.lifetime_stats.get("total_jumps", 0))
		data.lifetime_stats["total_jumps"] = current + count
		mark_dirty()

func record_height(height: int) -> void:
	var data = get_data() as ExampleProgressionData
	if data:
		var current = int(data.lifetime_stats.get("total_height_m", 0))
		data.lifetime_stats["total_height_m"] = max(current, height)
		mark_dirty()

func unlock_badge(badge_id: String) -> void:
	var data = get_data() as ExampleProgressionData
	if data and not data.badges.has(badge_id):
		data.badges.append(badge_id)
		mark_dirty()
