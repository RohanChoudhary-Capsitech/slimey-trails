class_name SkinController
extends UIController

@onready var back_button: Button = $Panel/BackButton

func _on_ready() -> void:
	back_button.pressed.connect(close)