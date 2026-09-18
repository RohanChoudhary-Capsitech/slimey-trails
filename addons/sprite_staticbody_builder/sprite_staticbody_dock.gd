@tool
extends PanelContainer

## Dock UI Controller for Sprite StaticBody Builder.

signal create_requested(options: Dictionary)
signal regenerate_requested(options: Dictionary)
signal preview_toggled(enabled: bool, options: Dictionary)
signal remove_requested()
signal settings_changed(options: Dictionary)

@onready var selected_label: Label = %SelectedLabel
@onready var threshold_slider: HSlider = %ThresholdSlider
@onready var threshold_spin_box: SpinBox = %ThresholdSpinBox
@onready var simplification_option: OptionButton = %SimplificationOption
@onready var custom_epsilon_spin_box: SpinBox = %CustomEpsilonSpinBox
@onready var max_points_spin_box: SpinBox = %MaxPointsSpinBox
@onready var collision_mode_option: OptionButton = %CollisionModeOption
@onready var check_create_static_body: CheckBox = %CheckCreateStaticBody
@onready var check_keep_original_sprite: CheckBox = %CheckKeepOriginalSprite
@onready var check_auto_generate: CheckBox = %CheckAutoGenerate
@onready var btn_create: Button = %BtnCreate
@onready var btn_regenerate: Button = %BtnRegenerate
@onready var btn_preview: Button = %BtnPreview
@onready var btn_remove: Button = %BtnRemove
@onready var status_label: Label = %StatusLabel

var current_sprite: Sprite2D = null
var current_texture_path: String = ""
var _is_updating_ui: bool = false

func _ready() -> void:
	_setup_options()
	_connect_signals()
	update_selection(null, "")

func _setup_options() -> void:
	simplification_option.clear()
	simplification_option.add_item("Low (1.0 px)", PolygonSimplifier.SimplificationLevel.LOW)
	simplification_option.add_item("Medium (2.5 px)", PolygonSimplifier.SimplificationLevel.MEDIUM)
	simplification_option.add_item("High (5.0 px)", PolygonSimplifier.SimplificationLevel.HIGH)
	simplification_option.add_item("Custom", PolygonSimplifier.SimplificationLevel.CUSTOM)
	simplification_option.selected = PolygonSimplifier.SimplificationLevel.MEDIUM

	collision_mode_option.clear()
	collision_mode_option.add_item("Single Polygon", CollisionGenerator.CollisionMode.SINGLE_POLYGON)
	collision_mode_option.add_item("Convex Decomposition", CollisionGenerator.CollisionMode.CONVEX_DECOMPOSITION)
	collision_mode_option.selected = CollisionGenerator.CollisionMode.SINGLE_POLYGON

func _connect_signals() -> void:
	threshold_slider.value_changed.connect(_on_threshold_slider_changed)
	threshold_spin_box.value_changed.connect(_on_threshold_spinbox_changed)
	simplification_option.item_selected.connect(_on_simplification_selected)
	custom_epsilon_spin_box.value_changed.connect(_on_any_setting_changed)
	max_points_spin_box.value_changed.connect(_on_any_setting_changed)
	collision_mode_option.item_selected.connect(_on_any_setting_changed)
	check_create_static_body.toggled.connect(_on_any_setting_changed)
	check_keep_original_sprite.toggled.connect(_on_any_setting_changed)
	check_auto_generate.toggled.connect(_on_any_setting_changed)

	btn_create.pressed.connect(_on_btn_create_pressed)
	btn_regenerate.pressed.connect(_on_btn_regenerate_pressed)
	btn_preview.toggled.connect(_on_btn_preview_toggled)
	btn_remove.pressed.connect(_on_btn_remove_pressed)

## Updates dock state based on currently selected scene node or FileSystem texture
func update_selection(sprite: Sprite2D, texture_path: String = "") -> void:
	current_sprite = sprite
	current_texture_path = texture_path

	if sprite != null and is_instance_valid(sprite):
		selected_label.text = "[ Detected Sprite: " + sprite.name + " ]"
		selected_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5))

		# Check if already has CollisionPolygon2D
		var has_collision: bool = false
		var parent: Node = sprite.get_parent()
		if parent is StaticBody2D:
			for child in parent.get_children():
				if child is CollisionPolygon2D:
					has_collision = true
					break
		else:
			for child in sprite.get_children():
				if child is CollisionPolygon2D:
					has_collision = true
					break

		btn_create.disabled = false
		btn_regenerate.disabled = not has_collision
		btn_remove.disabled = not has_collision
		btn_preview.disabled = false

		if has_collision:
			set_status("Ready. Collision detected (Regenerate or Update available).", Color(0.3, 0.8, 1.0))
		else:
			set_status("Sprite ready. Click 'Create StaticBody' to build collision.", Color(0.8, 0.9, 1.0))

	elif not texture_path.is_empty():
		var fname: String = texture_path.get_file()
		selected_label.text = "[ Detected Texture: " + fname + " ]"
		selected_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

		btn_create.disabled = false
		btn_regenerate.disabled = true
		btn_remove.disabled = true
		btn_preview.disabled = true
		btn_preview.button_pressed = false
		set_status("Texture selected in FileSystem. Click 'Create StaticBody' to place in scene.", Color(1.0, 0.85, 0.4))

	else:
		selected_label.text = "No Sprite2D selected"
		selected_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

		btn_create.disabled = true
		btn_regenerate.disabled = true
		btn_remove.disabled = true
		btn_preview.disabled = true
		btn_preview.button_pressed = false
		set_status("Select a Sprite2D or texture in the editor to begin.", Color(0.6, 0.6, 0.6))

## Returns a dictionary of all active user options in the dock
func get_current_options() -> Dictionary:
	return {
		"alpha_threshold": threshold_spin_box.value,
		"simplification": simplification_option.selected,
		"custom_epsilon": custom_epsilon_spin_box.value,
		"max_points": int(max_points_spin_box.value),
		"collision_mode": collision_mode_option.selected,
		"create_staticbody": check_create_static_body.button_pressed,
		"keep_original_sprite": check_keep_original_sprite.button_pressed,
		"generate_collision_auto": check_auto_generate.button_pressed
	}

## Displays an informative status message to the user
func set_status(msg: String, color: Color = Color(0.8, 0.8, 0.8)) -> void:
	if status_label != null:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", color)

func is_preview_active() -> bool:
	return btn_preview.button_pressed

func set_preview_pressed(pressed: bool) -> void:
	btn_preview.button_pressed = pressed

# --- Event handlers ---

func _on_threshold_slider_changed(val: float) -> void:
	if _is_updating_ui:
		return
	_is_updating_ui = true
	threshold_spin_box.value = val
	_is_updating_ui = false
	settings_changed.emit(get_current_options())

func _on_threshold_spinbox_changed(val: float) -> void:
	if _is_updating_ui:
		return
	_is_updating_ui = true
	threshold_slider.value = val
	_is_updating_ui = false
	settings_changed.emit(get_current_options())

func _on_simplification_selected(idx: int) -> void:
	custom_epsilon_spin_box.visible = (idx == PolygonSimplifier.SimplificationLevel.CUSTOM)
	settings_changed.emit(get_current_options())

func _on_any_setting_changed(_val = null) -> void:
	settings_changed.emit(get_current_options())

func _on_btn_create_pressed() -> void:
	create_requested.emit(get_current_options())

func _on_btn_regenerate_pressed() -> void:
	regenerate_requested.emit(get_current_options())

func _on_btn_preview_toggled(pressed: bool) -> void:
	preview_toggled.emit(pressed, get_current_options())

func _on_btn_remove_pressed() -> void:
	remove_requested.emit()
