extends Node

# GameService — Single entry point for all game logic dependencies
# PDF §2 Architecture: explicit separation for game devs.
# All game-related managers and singletons are initialized here.

# ── Core Singletons ────────────────────────────────────────────────────────
var config: Node
var logger: Node
var bus: Node

# ── Managers ───────────────────────────────────────────────────────────────
var audio: AudioManager
var game: GameManager
var haptics: HapticsManager
var network: NetworkManager
var save: SaveManager
var scene: SceneManager
var ui: UIManager

func _ready() -> void:
	# 1. Initialize core singletons first (no dependencies)
	config = _instantiate_and_add("res://game/autoloads/GameConfig.gd", "GameConfig")
	logger = _instantiate_and_add("res://game/autoloads/Logger.gd", "Logger")
	bus = _instantiate_and_add("res://game/autoloads/GameBus.gd", "GameBus")
	
	# 2. Initialize managers
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)
	
	game = GameManager.new()
	game.name = "GameManager"
	add_child(game)
	
	haptics = HapticsManager.new()
	haptics.name = "HapticsManager"
	add_child(haptics)
	
	network = NetworkManager.new()
	network.name = "NetworkManager"
	add_child(network)
	
	save = SaveManager.new()
	save.name = "SaveManager"
	add_child(save)
	
	scene = SceneManager.new()
	scene.name = "SceneManager"
	add_child(scene)
	
	ui = UIManager.new()
	ui.name = "UIManager"
	add_child(ui)
	
	logger.info("GameService initialized")

func _instantiate_and_add(script_path: String, node_name: String) -> Node:
	var script = load(script_path)
	if script == null:
		push_error("GameService: Failed to load " + script_path)
		return null
		
	var node = script.new()
	if node is Node:
		node.name = node_name
		add_child(node)
	return node
