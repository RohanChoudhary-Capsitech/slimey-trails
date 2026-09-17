class_name UIController
extends Control

# UIController — base class for every screen/panel
# PDF §4 CPU: _process and _physics_process are disabled by default.
#   UI panels do not need per-frame ticking; enable in subclass only if needed.
# PDF §6 DI: managers resolved via ServiceLocator — no direct node references.
# PDF §5: close() calls UIManager.pop() which queue_frees this node immediately.

var _ui_manager:   UIManager
var _audio:        AudioManager
var _game_manager: GameManager

func _ready() -> void:
	_ui_manager   = GameService.ui
	_audio        = GameService.audio
	_game_manager = GameService.game
	# PDF §4: UI screens don't need per-frame ticking by default
	set_process(false)
	set_physics_process(false)
	_on_ready()

## Override this instead of _ready() — managers are already injected.
func _on_ready() -> void:
	pass

## Closes this panel. UIManager.pop() calls queue_free() immediately (PDF §5).
func close() -> void:
	_ui_manager.pop()
