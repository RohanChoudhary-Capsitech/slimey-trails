extends Node2D

var _camera:CameraController

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# _camera=ServiceLocator.get_service(&"CameraController") as CameraController
	# if _camera == null:
	# 	# Logger.error("CameraController nahi mila")
	# 	return
	# _camera.enabled=true
	# print(_camera.global_position)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
