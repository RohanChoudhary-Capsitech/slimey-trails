extends Control

@export var next_scene_path: String = "res://game/scenes/gameplay/gameplay.tscn"

@onready var progress_bar: TextureProgressBar = $Panel/TextureProgressBar

func _ready() -> void:
	GameService.logger.info("Loading: started")
	_run_loading()

func _run_loading() -> void:
	progress_bar.min_value = 0
	progress_bar.max_value = 100
	progress_bar.value = 0

	var tween := create_tween()
	tween.tween_property(progress_bar, "value", 100.0, 1.0)
	await tween.finished

	GameService.scene.go_to(next_scene_path)