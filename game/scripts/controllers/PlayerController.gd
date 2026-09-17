class_name PlayerController
extends CharacterBody2D

# PlayerController — resolves managers via ServiceLocator, handles input → movement
# PDF §4 CPU: physics_process disabled at start; re-enabled only when visible.
#   Saves per-frame CPU for any player node that is off-screen or pooled.
# PDF §6 DI: all manager refs obtained via ServiceLocator — no hard node paths.
# Override _on_ready() and _move() in your game-specific player script.

var _game_manager: GameManager
var _audio:        AudioManager
var _save:         SaveManager

func _ready() -> void:
	_game_manager = GameService.game
	_audio        = GameService.audio
	_save         = GameService.save
	# PDF §4: disabled by default; visibility_changed re-enables when on-screen
	set_physics_process(false)
	visibility_changed.connect(_on_visibility_changed)
	_on_ready()

## Override this instead of _ready() — managers are already injected.
func _on_ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if not _game_manager.is_playing():
		return
	_move(delta)
	move_and_slide()

## Override this to implement movement logic.
func _move(_delta: float) -> void:
	pass

func die() -> void:
	GameService.logger.info("Player died")
	GameService.bus.player_died.emit()

# ── PDF §4: disable physics tick when player leaves the screen ────────────

func _on_visibility_changed() -> void:
	set_physics_process(is_visible_in_tree())
