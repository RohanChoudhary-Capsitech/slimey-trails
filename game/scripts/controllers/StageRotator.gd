extends Node2D
class_name StageRotator
## Rotates ONLY the stage geometry (walls, props, basket).
## Slime + dog live outside this node and obey world gravity.

@export var sensitivity: float = 90.0   # degrees per 100px drag
@export var limit_deg: float = 0.0      # 0 = unlimited
@export var smoothing: float = 18.0
@export var input_enabled: bool = true

const _SETTLE_EPSILON: float = 0.0005  # radians; below this, stop ticking

var _target_rot: float = 0.0
var _dragging := false
var _limit_rad: float = 0.0

func _ready() -> void:
	_target_rot = rotation
	_limit_rad = deg_to_rad(limit_deg)
	set_physics_process(false)

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return

	if event is InputEventScreenTouch:
		_set_dragging(event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_dragging(event.pressed)
		get_viewport().set_input_as_handled()
	elif _dragging and (event is InputEventScreenDrag or event is InputEventMouseMotion):
		_apply_drag(event.relative.x)
		get_viewport().set_input_as_handled()

func _set_dragging(value: bool) -> void:
	_dragging = value
	set_physics_process(true)  # keep ticking until the lerp settles

func _apply_drag(dx: float) -> void:
	_target_rot += deg_to_rad(dx * sensitivity * 0.01)
	if limit_deg > 0.0:
		_target_rot = clampf(_target_rot, -_limit_rad, _limit_rad)

func _physics_process(delta: float) -> void:
	## AnimatableBody2D children sync to this transform, so pushing works correctly.
	print("i work")
	rotation = lerp_angle(rotation, _target_rot, clampf(smoothing * delta, 0.0, 1.0))

	if not _dragging and absf(angle_difference(rotation, _target_rot)) < _SETTLE_EPSILON:
		rotation = _target_rot
		set_physics_process(false)

func snap_to(rad: float) -> void:
	_target_rot = rad
	rotation = rad
