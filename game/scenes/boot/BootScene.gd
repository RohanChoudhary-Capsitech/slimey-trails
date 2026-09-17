class_name BootScene
extends Node

## BootScene — Entry point bootstrap scene
## Wires up UnifiedBootstrapper for DataManager, initializes managers, and transitions to Home.

@export var next_scene_path: String = "res://game/scenes/Home/Home.tscn"

func _ready() -> void:
	Logger.info("Bootstrap sequence started...")
	
	# 1. Initialize core managers (plain Nodes registering with ServiceLocator)
	_init_managers()
	
	# 2. Initialize DataManager UnifiedBootstrapper
	_init_datamanager()
	
	# 3. Transition to initial game scene / Home
	_transition_to_game()

func _init_managers() -> void:
	# Ensure all core managers exist in the scene tree and register with ServiceLocator
	_ensure_manager(&"GameManager", GameManager)
	_ensure_manager(&"AudioManager", AudioManager)
	_ensure_manager(&"HapticsManager", HapticsManager)
	_ensure_manager(&"SaveManager", SaveManager)
	_ensure_manager(&"SceneManager", SceneManager)
	_ensure_manager(&"UIManager", UIManager)
	_ensure_manager(&"NetworkManager", NetworkManager)

func _ensure_manager(service_name: StringName, script_type: Variant) -> void:
	if not ServiceLocator.has_service(service_name):
		var mgr = script_type.new()
		mgr.name = String(service_name)
		add_child(mgr)

func _init_datamanager() -> void:
	var bootstrapper := UnifiedBootstrapper.new()
	bootstrapper.name = "UnifiedBootstrapper"
	add_child(bootstrapper)
	Logger.info("UnifiedBootstrapper initialized")

func _transition_to_game() -> void:
	var scene_mgr = ServiceLocator.get_service(&"SceneManager") as SceneManager
	if scene_mgr and ResourceLoader.exists(next_scene_path):
		scene_mgr.change_scene(next_scene_path)
	else:
		Logger.info("Bootstrap complete. Ready for gameplay scenes.")
