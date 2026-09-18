extends Node2D

@export var sensitivity: float = 90.0
@export var limit_deg: float = 0.0
@export var smoothing: float = 18.0
@export var input_enabled: bool = true

var _level_instance: Node2D = null
var _target_rot: float = 0.0
var _dragging := false
var _last_x: float = 0.0

func _ready() -> void:
	_load_selected_level()

func _load_selected_level() -> void:
	var level_id: int = GameService.game.selected_level
	var path: String = GameService.config.get_level_scene_path(level_id)

	var packed: PackedScene = load(path)
	if packed == null:
		GameService.logger.error("Gameplay: failed to load level", { "path": path })
		return

	_level_instance = packed.instantiate()
	add_child(_level_instance)
	move_child(_level_instance, 0)
	_target_rot = _level_instance.rotation
	GameService.logger.info("Gameplay: loaded level", { "level_id": level_id, "path": path })

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled or _level_instance == null:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_dragging = true
			_last_x = event.position.x
		else:
			_dragging = false
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		var dx: float = event.position.x - _last_x
		_last_x = event.position.x
		_target_rot += deg_to_rad(dx * sensitivity * 0.01)
		if limit_deg > 0.0:
			_target_rot = clampf(_target_rot, -deg_to_rad(limit_deg), deg_to_rad(limit_deg))

func _physics_process(delta: float) -> void:
	if _level_instance == null:
		return
	_level_instance.rotation = lerp_angle(_level_instance.rotation, _target_rot, clampf(smoothing * delta, 0.0, 1.0))

func snap_to(rad: float) -> void:
	_target_rot = rad
	if _level_instance:
		_level_instance.rotation = rad