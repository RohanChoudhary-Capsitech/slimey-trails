class_name UIManager
extends Node

# UIManager — screen stack with on-demand instantiation and immediate free
# PDF §5 (Small panels): push_packed() instantiates on demand; pop() calls
#   queue_free() immediately so nothing sits idle in VRAM.
# PDF §5 (Big scenes): large scenes are handled by SceneManager — UIManager
#   manages panels only, not full scene transitions.
# PDF §4 CPU: hidden screens use hide(), reducing draw calls on inactive panels.

var _stack: Array[Control] = []

func _ready() -> void:
	pass

# ── Push ──────────────────────────────────────────────────────────────────

## PDF §5: Pass a PackedScene — UIManager owns instantiation and lifetime.
## Use this for all panels (<~10 MB). Instantiated here, freed on pop().
func push_packed(packed: PackedScene) -> void:
	if not _stack.is_empty():
		_stack.back().hide()
	var screen := packed.instantiate() as Control
	add_child(screen)
	_stack.append(screen)
	GameService.bus.screen_opened.emit(screen.name)
	GameService.logger.debug("UI push", { "screen": screen.name })

## Legacy: push a pre-instantiated Control (kept for compatibility).
## Prefer push_packed() for all new panels.
func push(screen: Control) -> void:
	if not _stack.is_empty():
		_stack.back().hide()
	_stack.append(screen)
	GameService.bus.screen_opened.emit(screen.name)
	GameService.logger.debug("UI push", { "screen": screen.name })

# ── Pop ───────────────────────────────────────────────────────────────────

## PDF §5: queue_free() immediately — no idle VRAM from off-screen panels.
func pop() -> void:
	if _stack.is_empty():
		return
	var screen: Control = _stack.pop_back()
	GameService.bus.screen_closed.emit(screen.name)
	GameService.logger.debug("UI pop", { "screen": screen.name })
	screen.queue_free()
	if not _stack.is_empty():
		_stack.back().show()

func pop_to_root() -> void:
	while _stack.size() > 1:
		pop()

func replace_packed(packed: PackedScene) -> void:
	pop()
	push_packed(packed)

func replace(screen: Control) -> void:
	pop()
	push(screen)

# ── Queries ───────────────────────────────────────────────────────────────

func current() -> Control:
	return _stack.back() if not _stack.is_empty() else null

func stack_size() -> int:
	return _stack.size()
