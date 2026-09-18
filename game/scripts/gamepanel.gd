extends UIController

const SKIN_SCENE: PackedScene = preload("res://game/scenes/gameplay/Skin.tscn")

@onready var skin_button: TextureButton = $Panel/Bg/Skin

func _on_ready() -> void:
	skin_button.pressed.connect(_on_skin_pressed)

func _on_skin_pressed() -> void:
	GameService.ui.push_packed(SKIN_SCENE)