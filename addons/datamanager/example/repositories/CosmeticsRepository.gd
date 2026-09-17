extends BaseRepository
class_name ExampleCosmeticsRepository

func _init(cache: MemoryCache) -> void:
	super("Cosmetics", ExampleCosmeticsData, cache)
	is_cloud_synced = true

func unlock_skin(skin_id: String) -> void:
	var data = get_data() as ExampleCosmeticsData
	if data and not data.unlocked_skin_ids.has(skin_id):
		data.unlocked_skin_ids.append(skin_id)
		mark_dirty()

func equip_skin(skin_id: String) -> bool:
	var data = get_data() as ExampleCosmeticsData
	if data and data.unlocked_skin_ids.has(skin_id):
		data.active_skin = skin_id
		mark_dirty()
		return true
	return false

func increment_ad_watch_count(cosmetic_id: String) -> void:
	var data = get_data() as ExampleCosmeticsData
	if data:
		var current = int(data.ad_watch_counts.get(cosmetic_id, 0))
		data.ad_watch_counts[cosmetic_id] = current + 1
		mark_dirty()
