
extends UIController

@export var close_button: Button

@export var _sound_on: TextureButton
@export var _sound_off: TextureButton

func _on_ready() -> void:
	close_button.pressed.connect(close)
	_sound_on.pressed.connect(_on_sound_pressed.bind(false))
	_sound_off.pressed.connect(_on_sound_pressed.bind(true))
	GameService.bus.sound_changed.connect(_refresh_sound)
	_refresh_sound(GameService.save.is_sound_enabled())

# func _on_close_pressed() -> void:
# 	close()
func _on_sound_pressed(enabled: bool) -> void:
	GameService.save.set_sound_enabled(enabled)

func _refresh_sound(enabled: bool) -> void:
	_sound_on.visible = enabled
	_sound_off.visible = not enabled