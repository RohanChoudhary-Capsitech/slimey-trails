class_name BootScene
extends Node

## BootScene — Entry point bootstrap scene
## Wires up UnifiedBootstrapper for DataManager, initializes managers, and transitions to Home.

@export var next_scene_path: String = "res://game/levels/level_1.tscn"

func _ready() -> void:
	GameService.logger.info("Bootstrap sequence started...")
	_init_datamanager()
	_transition_to_game()

func _init_datamanager() -> void:
	var bootstrapper := UnifiedBootstrapper.new()
	bootstrapper.name = "UnifiedBootstrapper"
	add_child(bootstrapper)
	GameService.logger.info("UnifiedBootstrapper initialized")

func _transition_to_game() -> void:
	if not ResourceLoader.exists(next_scene_path):
		GameService.logger.error("Scene does not exist: " + next_scene_path)
		return

	GameService.scene.go_to(next_scene_path)
