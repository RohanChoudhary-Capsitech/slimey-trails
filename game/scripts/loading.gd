extends Control

@export var next_scene_path: String = "res://game/scenes/gameplay/gameplay.tscn"
@export var settings_panel: PackedScene
# @onready var progress_bar: TextureProgressBar = $Panel/TextureProgressBar
@export var startBtn :TextureButton
@export var settingsBtn :TextureButton

func _ready() -> void:
	GameService.logger.info("Loading: started")
	startBtn.pressed.connect(_on_start_pressed)
	settingsBtn.pressed.connect(_on_settings_pressed)
	# _run_loading()

func _on_start_pressed() -> void:
	GameService.logger.info("Loading: start pressed")
	GameService.game.set_selected_level(3)
	GameService.scene.go_to(next_scene_path)

func _on_settings_pressed() -> void:
	GameService.logger.info("Loading: settings pressed")
	if settings_panel:
		GameService.ui.push_packed(settings_panel)

# func _run_loading() -> void:
# 	progress_bar.min_value = 0
# 	progress_bar.max_value = 100
# 	progress_bar.value = 0

# 	var tween := create_tween()
# 	tween.tween_property(progress_bar, "value", 100.0, 1.0)
# 	await tween.finished
# 	GameService.game.set_selected_level(3)
# 	GameService.scene.go_to(next_scene_path)