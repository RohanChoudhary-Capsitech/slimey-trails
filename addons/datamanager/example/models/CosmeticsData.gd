extends BaseModel
class_name ExampleCosmeticsData

var active_skin: String = "DEFAULT"
var unlocked_skin_ids: Array[String] = ["DEFAULT", "FEMALE_00"]
var active_trail: String = "Default"
var unlocked_trail_ids: Array[String] = ["Default"]
var active_impact: String = "Default"
var unlocked_impact_ids: Array[String] = ["Default"]
var ad_watch_counts: Dictionary = {}

func serialize() -> Dictionary:
	return {
		"active_skin": active_skin,
		"unlocked_skin_ids": unlocked_skin_ids,
		"active_trail": active_trail,
		"unlocked_trail_ids": unlocked_trail_ids,
		"active_impact": active_impact,
		"unlocked_impact_ids": unlocked_impact_ids,
		"ad_watch_counts": ad_watch_counts,
		"last_saved_timestamp": last_saved_timestamp
	}

func deserialize(dict: Dictionary) -> void:
	active_skin = dict.get("active_skin", "DEFAULT")
	
	# Convert generic arrays to typed String arrays safely
	unlocked_skin_ids.clear()
	for s in dict.get("unlocked_skin_ids", ["DEFAULT", "FEMALE_00"]):
		unlocked_skin_ids.append(str(s))
		
	active_trail = dict.get("active_trail", "Default")
	
	unlocked_trail_ids.clear()
	for t in dict.get("unlocked_trail_ids", ["Default"]):
		unlocked_trail_ids.append(str(t))
		
	active_impact = dict.get("active_impact", "Default")
	
	unlocked_impact_ids.clear()
	for im in dict.get("unlocked_impact_ids", ["Default"]):
		unlocked_impact_ids.append(str(im))
		
	ad_watch_counts = dict.get("ad_watch_counts", {}).duplicate()
	last_saved_timestamp = float(dict.get("last_saved_timestamp", 0.0))

func clone() -> BaseModel:
	var copy = ExampleCosmeticsData.new()
	copy.active_skin = active_skin
	copy.unlocked_skin_ids = unlocked_skin_ids.duplicate()
	copy.active_trail = active_trail
	copy.unlocked_trail_ids = unlocked_trail_ids.duplicate()
	copy.active_impact = active_impact
	copy.unlocked_impact_ids = unlocked_impact_ids.duplicate()
	copy.ad_watch_counts = ad_watch_counts.duplicate(true)
	copy.last_saved_timestamp = last_saved_timestamp
	return copy

func equals(other: BaseModel) -> bool:
	var o = other as ExampleCosmeticsData
	if not o:
		return false
	return (
		active_skin == o.active_skin and
		unlocked_skin_ids == o.unlocked_skin_ids and
		active_trail == o.active_trail and
		unlocked_trail_ids == o.unlocked_trail_ids and
		active_impact == o.active_impact and
		unlocked_impact_ids == o.unlocked_impact_ids and
		ad_watch_counts == o.ad_watch_counts
	)
