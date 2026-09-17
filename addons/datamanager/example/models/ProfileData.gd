extends BaseModel
class_name ExampleProfileData

var player_name: String = "Player"
var custom_player_name: String = ""
var tutorial_state: int = 0
var ftue_completed: bool = false
var creation_date: String = ""
var ads_removed: bool = false

func serialize() -> Dictionary:
	return {
		"player_name": player_name,
		"custom_player_name": custom_player_name,
		"tutorial_state": tutorial_state,
		"ftue_completed": ftue_completed,
		"creation_date": creation_date,
		"ads_removed": ads_removed,
		"last_saved_timestamp": last_saved_timestamp
	}

func deserialize(dict: Dictionary) -> void:
	player_name = dict.get("player_name", "Player")
	custom_player_name = dict.get("custom_player_name", "")
	tutorial_state = int(dict.get("tutorial_state", 0))
	ftue_completed = bool(dict.get("ftue_completed", false))
	creation_date = dict.get("creation_date", "")
	ads_removed = bool(dict.get("ads_removed", false))
	last_saved_timestamp = float(dict.get("last_saved_timestamp", 0.0))

func clone() -> BaseModel:
	var copy = ExampleProfileData.new()
	copy.player_name = player_name
	copy.custom_player_name = custom_player_name
	copy.tutorial_state = tutorial_state
	copy.ftue_completed = ftue_completed
	copy.creation_date = creation_date
	copy.ads_removed = ads_removed
	copy.last_saved_timestamp = last_saved_timestamp
	return copy

func equals(other: BaseModel) -> bool:
	var o = other as ExampleProfileData
	if not o:
		return false
	return (
		player_name == o.player_name and
		custom_player_name == o.custom_player_name and
		tutorial_state == o.tutorial_state and
		ftue_completed == o.ftue_completed and
		creation_date == o.creation_date and
		ads_removed == o.ads_removed
	)
