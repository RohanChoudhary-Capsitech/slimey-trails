extends BaseModel
class_name ExampleProgressionData

var high_score: int = 0
var lifetime_stats: Dictionary = {
	"total_jumps": 0,
	"total_height_m": 0
}
var badges: Array[String] = []
var claimed_achievement_tiers: Dictionary = {}
var quest_chains: Dictionary = {}

func _init() -> void:
	schema_version = 2

## Demonstrates schema migrations. Called automatically by BaseRepository if 
## loaded local/cloud files have an older version.
func migrate_schema(data: Dictionary, saved_version: int) -> Dictionary:
	var migrated = data.duplicate(true)
	if saved_version < 2:
		DataManagerLogger.info("Migrating ProgressionData from version %d to 2." % saved_version, "MODEL")
		# 1. Inject default achievements dictionary if missing
		if not migrated.has("claimed_achievement_tiers"):
			migrated["claimed_achievement_tiers"] = {}
		# 2. Simulate renaming a legacy field "total_height" to "total_height_m"
		if migrated.has("lifetime_stats"):
			var stats = migrated["lifetime_stats"]
			if stats.has("total_height") and not stats.has("total_height_m"):
				stats["total_height_m"] = stats["total_height"]
				stats.erase("total_height")
				migrated["lifetime_stats"] = stats
	return migrated

func serialize() -> Dictionary:
	return {
		"high_score": high_score,
		"lifetime_stats": lifetime_stats,
		"badges": badges,
		"claimed_achievement_tiers": claimed_achievement_tiers,
		"quest_chains": quest_chains,
		"last_saved_timestamp": last_saved_timestamp
	}

func deserialize(dict: Dictionary) -> void:
	high_score = int(dict.get("high_score", 0))
	lifetime_stats = dict.get("lifetime_stats", {
		"total_jumps": 0,
		"total_height_m": 0
	}).duplicate()
	
	badges.clear()
	for b in dict.get("badges", []):
		badges.append(str(b))
		
	claimed_achievement_tiers = dict.get("claimed_achievement_tiers", {}).duplicate()
	quest_chains = dict.get("quest_chains", {}).duplicate()
	last_saved_timestamp = float(dict.get("last_saved_timestamp", 0.0))

func clone() -> BaseModel:
	var copy = ExampleProgressionData.new()
	copy.high_score = high_score
	copy.lifetime_stats = lifetime_stats.duplicate(true)
	copy.badges = badges.duplicate()
	copy.claimed_achievement_tiers = claimed_achievement_tiers.duplicate(true)
	copy.quest_chains = quest_chains.duplicate(true)
	copy.last_saved_timestamp = last_saved_timestamp
	return copy

func equals(other: BaseModel) -> bool:
	var o = other as ExampleProgressionData
	if not o:
		return false
	return (
		high_score == o.high_score and
		lifetime_stats == o.lifetime_stats and
		badges == o.badges and
		claimed_achievement_tiers == o.claimed_achievement_tiers and
		quest_chains == o.quest_chains
	)
