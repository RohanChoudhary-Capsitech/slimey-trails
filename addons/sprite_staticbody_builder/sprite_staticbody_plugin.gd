@tool
extends EditorPlugin

## Main EditorPlugin for Sprite StaticBody Builder.
## Integrates the dock, tracks editor selection, provides Undo/Redo actions,
## and renders real-time 2D viewport collision outlines.

const DOCK_SCENE := preload("res://addons/sprite_staticbody_builder/sprite_staticbody_dock.tscn")
const DEFAULT_SETTINGS := preload("res://addons/sprite_staticbody_builder/resources/default_settings.tres")

var dock_instance: PanelContainer = null
var preview_helper: CollisionPreview = null

var _current_sprite: Sprite2D = null
var _current_texture_path: String = ""

func _enter_tree() -> void:
	preview_helper = CollisionPreview.new()

	# Instantiate dock
	dock_instance = DOCK_SCENE.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock_instance)

	# Connect dock signals
	dock_instance.create_requested.connect(_on_create_requested)
	dock_instance.regenerate_requested.connect(_on_regenerate_requested)
	dock_instance.preview_toggled.connect(_on_preview_toggled)
	dock_instance.remove_requested.connect(_on_remove_requested)
	dock_instance.settings_changed.connect(_on_settings_changed)

	# Connect editor selection
	var editor_selection := EditorInterface.get_selection()
	editor_selection.selection_changed.connect(_on_selection_changed)

	# Initial selection check
	_on_selection_changed()

func _exit_tree() -> void:
	if preview_helper != null:
		preview_helper.clear()
		preview_helper.is_active = false
		preview_helper = null

	var editor_selection := EditorInterface.get_selection()
	if editor_selection.selection_changed.is_connected(_on_selection_changed):
		editor_selection.selection_changed.disconnect(_on_selection_changed)

	if dock_instance != null:
		remove_control_from_docks(dock_instance)
		dock_instance.queue_free()
		dock_instance = null

# --- 2D Viewport Overlay Drawing for Preview ---

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if preview_helper != null and preview_helper.is_active:
		preview_helper.draw_on_overlay(overlay)

# --- Selection & Context Handling ---

func _on_selection_changed() -> void:
	var selected_nodes: Array[Node] = EditorInterface.get_selection().get_selected_nodes()
	var detected_sprite: Sprite2D = null

	for node in selected_nodes:
		if node is Sprite2D:
			detected_sprite = node as Sprite2D
			break
		elif node is StaticBody2D:
			# If user selected a StaticBody2D containing a Sprite2D, target that sprite
			for child in node.get_children():
				if child is Sprite2D:
					detected_sprite = child as Sprite2D
					break
			if detected_sprite != null:
				break

	var detected_texture_path: String = ""
	if detected_sprite == null:
		# Check FileSystem selection for texture files
		var selected_paths: PackedStringArray = EditorInterface.get_selected_paths()
		for path in selected_paths:
			var ext: String = path.get_extension().to_lower()
			if ext in ["png", "svg", "webp", "jpg", "jpeg"]:
				detected_texture_path = path
				break

	_current_sprite = detected_sprite
	_current_texture_path = detected_texture_path

	if dock_instance != null:
		dock_instance.update_selection(_current_sprite, _current_texture_path)

	# Update preview if active
	if preview_helper != null and preview_helper.is_active:
		_refresh_preview()
	else:
		update_overlays()

func _on_settings_changed(options: Dictionary) -> void:
	if preview_helper != null and preview_helper.is_active:
		_refresh_preview(options)

func _on_preview_toggled(enabled: bool, options: Dictionary) -> void:
	if preview_helper == null:
		return
	preview_helper.is_active = enabled
	if enabled:
		_refresh_preview(options)
	else:
		preview_helper.clear()
		update_overlays()
		if dock_instance != null:
			dock_instance.set_status("Preview disabled.", Color(0.7, 0.7, 0.7))

func _refresh_preview(options: Dictionary = {}) -> void:
	if _current_sprite == null or not is_instance_valid(_current_sprite):
		preview_helper.clear()
		update_overlays()
		return

	if options.is_empty() and dock_instance != null:
		options = dock_instance.get_current_options()

	var result: Dictionary = CollisionGenerator.generate_from_sprite(_current_sprite, options)
	if result.success:
		preview_helper.update_data(_current_sprite, result.polygons)
		update_overlays()
		if dock_instance != null:
			dock_instance.set_status("Preview: %d polygon(s), %d total points." % [result.polygon_count, result.total_points], Color(0.3, 0.95, 0.5))
	else:
		preview_helper.clear()
		update_overlays()
		if dock_instance != null:
			dock_instance.set_status("Preview error: " + result.error_message, Color(1.0, 0.4, 0.4))

# --- Action Executions (Create / Regenerate / Remove) ---

func _on_create_requested(options: Dictionary) -> void:
	var edited_scene_root: Node = EditorInterface.get_edited_scene_root()
	if edited_scene_root == null:
		dock_instance.set_status("Error: No open scene in editor.", Color(1.0, 0.3, 0.3))
		return

	if _current_sprite != null and is_instance_valid(_current_sprite):
		_create_from_existing_sprite(_current_sprite, options, edited_scene_root)
	elif not _current_texture_path.is_empty():
		_create_from_texture_path(_current_texture_path, options, edited_scene_root)
	else:
		dock_instance.set_status("Error: No valid Sprite2D or texture selected.", Color(1.0, 0.3, 0.3))

func _create_from_existing_sprite(sprite: Sprite2D, options: Dictionary, scene_root: Node) -> void:
	var parent: Node = sprite.get_parent()
	var is_already_under_static_body: bool = (parent is StaticBody2D)

	if is_already_under_static_body:
		# Just regenerate collision under current StaticBody2D
		_regenerate_collision_under_body(parent as StaticBody2D, sprite, options, scene_root)
		return

	# Generate collision data
	var gen_result: Dictionary = CollisionGenerator.generate_from_sprite(sprite, options)
	if not gen_result.success:
		dock_instance.set_status("Failed to generate collision: " + gen_result.error_message, Color(1.0, 0.3, 0.3))
		return

	var body_name: String = sprite.name + "Body"
	var body: StaticBody2D = StaticBody2D.new()
	body.name = body_name

	# Inherit transform from the sprite
	body.transform = sprite.transform
	var old_sprite_xform: Transform2D = sprite.transform

	# Create collision polygon nodes
	var col_nodes: Array[CollisionPolygon2D] = []
	var polygons: Array[PackedVector2Array] = gen_result.polygons
	for i in range(polygons.size()):
		var col := CollisionPolygon2D.new()
		col.polygon = polygons[i]
		if polygons.size() == 1:
			col.name = "CollisionPolygon2D"
		else:
			col.name = "CollisionPolygon2D_%d" % (i + 1)
		col_nodes.append(col)

	# Execute via UndoRedo
	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Create StaticBody from Sprite")

	# DO action
	ur.add_do_method(self, &"_do_wrap_sprite", body, sprite, parent, col_nodes, scene_root)
	# UNDO action
	ur.add_undo_method(self, &"_undo_wrap_sprite", body, sprite, parent, old_sprite_xform, col_nodes)

	ur.commit_action()

	dock_instance.set_status("Created %s with %d polygon(s) (%d points)." % [body.name, gen_result.polygon_count, gen_result.total_points], Color(0.3, 0.95, 0.5))
	_on_selection_changed()

func _create_from_texture_path(texture_path: String, options: Dictionary, scene_root: Node) -> void:
	var texture: Texture2D = load(texture_path)
	if texture == null:
		dock_instance.set_status("Error: Could not load texture from " + texture_path, Color(1.0, 0.3, 0.3))
		return

	var base_name: String = texture_path.get_file().get_basename().capitalize().replace(" ", "")
	var body := StaticBody2D.new()
	body.name = base_name + "Body"

	var sprite := Sprite2D.new()
	sprite.name = base_name
	sprite.texture = texture

	var gen_result: Dictionary = CollisionGenerator.generate_from_sprite(sprite, options)
	if not gen_result.success:
		dock_instance.set_status("Failed to generate collision: " + gen_result.error_message, Color(1.0, 0.3, 0.3))
		return

	var col_nodes: Array[CollisionPolygon2D] = []
	for i in range(gen_result.polygons.size()):
		var col := CollisionPolygon2D.new()
		col.polygon = gen_result.polygons[i]
		col.name = "CollisionPolygon2D" if gen_result.polygons.size() == 1 else "CollisionPolygon2D_%d" % (i + 1)
		col_nodes.append(col)

	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Create StaticBody from Texture")

	ur.add_do_method(self, &"_do_create_body_from_scratch", body, sprite, col_nodes, scene_root)
	ur.add_undo_method(self, &"_undo_create_body_from_scratch", body)

	ur.commit_action()
	dock_instance.set_status("Created %s with %d polygon(s)." % [body.name, gen_result.polygon_count], Color(0.3, 0.95, 0.5))
	_on_selection_changed()

func _on_regenerate_requested(options: Dictionary) -> void:
	if _current_sprite == null or not is_instance_valid(_current_sprite):
		dock_instance.set_status("No Sprite2D selected to regenerate.", Color(1.0, 0.3, 0.3))
		return

	var parent: Node = _current_sprite.get_parent()
	if parent is StaticBody2D:
		_regenerate_collision_under_body(parent as StaticBody2D, _current_sprite, options, EditorInterface.get_edited_scene_root())
	else:
		# If sprite itself has child collision polygons
		_regenerate_collision_on_sprite(_current_sprite, options, EditorInterface.get_edited_scene_root())

func _regenerate_collision_under_body(body: StaticBody2D, sprite: Sprite2D, options: Dictionary, scene_root: Node) -> void:
	var gen_result: Dictionary = CollisionGenerator.generate_from_sprite(sprite, options)
	if not gen_result.success:
		dock_instance.set_status("Failed to regenerate collision: " + gen_result.error_message, Color(1.0, 0.3, 0.3))
		return

	var old_col_nodes: Array[Node] = []
	for child in body.get_children():
		if child is CollisionPolygon2D:
			old_col_nodes.append(child)

	var new_col_nodes: Array[CollisionPolygon2D] = []
	for i in range(gen_result.polygons.size()):
		var col := CollisionPolygon2D.new()
		col.polygon = gen_result.polygons[i]
		col.name = "CollisionPolygon2D" if gen_result.polygons.size() == 1 else "CollisionPolygon2D_%d" % (i + 1)
		new_col_nodes.append(col)

	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Regenerate Collision")
	ur.add_do_method(self, &"_do_swap_collision_nodes", body, old_col_nodes, new_col_nodes, scene_root)
	ur.add_undo_method(self, &"_undo_swap_collision_nodes", body, old_col_nodes, new_col_nodes, scene_root)
	ur.commit_action()

	dock_instance.set_status("Collision regenerated: %d polygon(s) (%d points)." % [gen_result.polygon_count, gen_result.total_points], Color(0.3, 0.95, 0.5))
	_on_selection_changed()

func _regenerate_collision_on_sprite(sprite: Sprite2D, options: Dictionary, scene_root: Node) -> void:
	var gen_result: Dictionary = CollisionGenerator.generate_from_sprite(sprite, options)
	if not gen_result.success:
		dock_instance.set_status("Failed to regenerate: " + gen_result.error_message, Color(1.0, 0.3, 0.3))
		return

	var old_col_nodes: Array[Node] = []
	for child in sprite.get_children():
		if child is CollisionPolygon2D:
			old_col_nodes.append(child)

	var new_col_nodes: Array[CollisionPolygon2D] = []
	for i in range(gen_result.polygons.size()):
		var col := CollisionPolygon2D.new()
		col.polygon = gen_result.polygons[i]
		col.name = "CollisionPolygon2D" if gen_result.polygons.size() == 1 else "CollisionPolygon2D_%d" % (i + 1)
		new_col_nodes.append(col)

	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Regenerate Collision")
	ur.add_do_method(self, &"_do_swap_collision_nodes", sprite, old_col_nodes, new_col_nodes, scene_root)
	ur.add_undo_method(self, &"_undo_swap_collision_nodes", sprite, old_col_nodes, new_col_nodes, scene_root)
	ur.commit_action()

	dock_instance.set_status("Collision regenerated on sprite.", Color(0.3, 0.95, 0.5))
	_on_selection_changed()

func _on_remove_requested() -> void:
	if _current_sprite == null or not is_instance_valid(_current_sprite):
		return

	var parent: Node = _current_sprite.get_parent()
	var target_parent: Node = parent if (parent is StaticBody2D) else _current_sprite
	var col_nodes: Array[Node] = []
	for child in target_parent.get_children():
		if child is CollisionPolygon2D:
			col_nodes.append(child)

	if col_nodes.is_empty():
		dock_instance.set_status("No CollisionPolygon2D found to remove.", Color(0.8, 0.8, 0.8))
		return

	var ur: EditorUndoRedoManager = get_undo_redo()
	ur.create_action("Remove Collision")
	ur.add_do_method(self, &"_do_remove_collision_nodes", target_parent, col_nodes)
	ur.add_undo_method(self, &"_undo_restore_collision_nodes", target_parent, col_nodes, EditorInterface.get_edited_scene_root())
	ur.commit_action()

	dock_instance.set_status("Removed %d collision polygon(s)." % col_nodes.size(), Color(1.0, 0.8, 0.3))
	_on_selection_changed()

# --- Undo / Redo Helper Methods ---

func _do_wrap_sprite(body: StaticBody2D, sprite: Sprite2D, original_parent: Node, col_nodes: Array[CollisionPolygon2D], scene_root: Node) -> void:
	original_parent.add_child(body)
	body.owner = scene_root

	# Reparent sprite under body
	sprite.reparent(body)
	sprite.owner = scene_root
	sprite.position = Vector2.ZERO
	sprite.rotation = 0.0
	sprite.scale = Vector2.ONE

	for col in col_nodes:
		body.add_child(col)
		col.owner = scene_root

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(body)

func _undo_wrap_sprite(body: StaticBody2D, sprite: Sprite2D, original_parent: Node, old_sprite_xform: Transform2D, col_nodes: Array[CollisionPolygon2D]) -> void:
	for col in col_nodes:
		if col.is_inside_tree():
			body.remove_child(col)

	sprite.reparent(original_parent)
	sprite.owner = EditorInterface.get_edited_scene_root()
	sprite.transform = old_sprite_xform

	if body.is_inside_tree():
		original_parent.remove_child(body)

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(sprite)

func _do_create_body_from_scratch(body: StaticBody2D, sprite: Sprite2D, col_nodes: Array[CollisionPolygon2D], scene_root: Node) -> void:
	scene_root.add_child(body)
	body.owner = scene_root
	body.position = Vector2(400, 300) # Centered default placement

	body.add_child(sprite)
	sprite.owner = scene_root

	for col in col_nodes:
		body.add_child(col)
		col.owner = scene_root

	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(body)

func _undo_create_body_from_scratch(body: StaticBody2D) -> void:
	if body.is_inside_tree():
		var parent: Node = body.get_parent()
		if parent != null:
			parent.remove_child(body)

func _do_swap_collision_nodes(parent_node: Node, old_nodes: Array[Node], new_nodes: Array[CollisionPolygon2D], scene_root: Node) -> void:
	for old_n in old_nodes:
		if old_n.is_inside_tree():
			parent_node.remove_child(old_n)
	for new_n in new_nodes:
		parent_node.add_child(new_n)
		new_n.owner = scene_root

func _undo_swap_collision_nodes(parent_node: Node, old_nodes: Array[Node], new_nodes: Array[CollisionPolygon2D], scene_root: Node) -> void:
	for new_n in new_nodes:
		if new_n.is_inside_tree():
			parent_node.remove_child(new_n)
	for old_n in old_nodes:
		parent_node.add_child(old_n)
		old_n.owner = scene_root

func _do_remove_collision_nodes(parent_node: Node, nodes_to_remove: Array[Node]) -> void:
	for n in nodes_to_remove:
		if n.is_inside_tree():
			parent_node.remove_child(n)

func _undo_restore_collision_nodes(parent_node: Node, nodes_to_restore: Array[Node], scene_root: Node) -> void:
	for n in nodes_to_restore:
		parent_node.add_child(n)
		n.owner = scene_root
