extends Node
class_name ExampleConflictPopup

## Emitted when the player resolves the conflict by selecting an option.
signal conflict_resolved(choice: String)

var _local_data: Dictionary = {}
var _remote_data: Dictionary = {}

## Simulates UI population with save file comparisons
func setup_conflict(local_data: Dictionary, remote_data: Dictionary) -> void:
	_local_data = local_data
	_remote_data = remote_data
	
	var local_score = local_data.get("high_score", 0)
	var remote_score = remote_data.get("high_score", 0)
	var local_coins = local_data.get("coins", 0)
	var remote_coins = remote_data.get("coins", 0)
	
	print("--- CONFLICT DETAILS ---")
	print("Local device state: High Score = %d, Coins = %d" % [local_score, local_coins])
	print("Cloud backup state: High Score = %d, Coins = %d" % [remote_score, remote_coins])
	print("------------------------")
	
	# In a real UI panel, you would set labels:
	# $LocalScoreLabel.text = str(local_score)
	# $CloudScoreLabel.text = str(remote_score)
	
	# Simulate player clicking a button via code after a frame timeout
	get_tree().create_timer(1.0).timeout.connect(func():
		# Automatically select "local" for test runner environment
		simulate_player_click("local")
	)

## Triggered when a button (Local, Cloud, or Merge) is pressed in the UI.
func simulate_player_click(choice: String) -> void:
	print("[ConflictUI] Player selected option: ", choice)
	conflict_resolved.emit(choice)
