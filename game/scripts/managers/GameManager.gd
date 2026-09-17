class_name GameManager
extends Node

# GameManager — top-level game state machine
# States: IDLE → PLAYING ↔ PAUSED → GAME_OVER → IDLE

enum State { IDLE, PLAYING, PAUSED, GAME_OVER }

var state: State = State.IDLE :
	set(v):
		state = v
		GameService.logger.info("GameManager state", { "state": State.keys()[v] })

func _ready() -> void:
	pass

func start() -> void:
	if state != State.IDLE:
		return
	state = State.PLAYING
	GameService.bus.game_started.emit()

func pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	GameService.bus.game_paused.emit()

func resume() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	GameService.bus.game_resumed.emit()

func game_over(reason: String = "") -> void:
	state = State.GAME_OVER
	get_tree().paused = false
	GameService.bus.game_over.emit(reason)

func reset() -> void:
	state = State.IDLE

func is_playing() -> bool:
	return state == State.PLAYING
