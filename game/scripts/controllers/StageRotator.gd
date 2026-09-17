extends Node2D
class_name StageRotator
## Rotates ONLY the stage geometry (walls, props, basket).
## Slime + dog live outside this node and obey world gravity.

@export var sensitivity: float = 90.0   # degrees per 100px drag
@export var limit_deg: float = 0.0      # 0 = unlimited
@export var smoothing: float = 18.0
@export var input_enabled: bool = true

var _target_rot: float = 0.0
var _dragging := false
var _last_x: float = 0.0

func _ready() -> void:
	_target_rot = rotation

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
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
	# AnimatableBody2D children sync to this transform, so pushing works correctly.
	rotation = lerp_angle(rotation, _target_rot, clampf(smoothing * delta, 0.0, 1.0))

func snap_to(rad: float) -> void:
	_target_rot = rad
	rotation = rad
