@tool
class_name CollisionPreview
extends RefCounted

## Handles real-time preview rendering of generated collision geometry in the Godot 2D editor viewport.

var is_active: bool = false
var cached_polygons: Array[PackedVector2Array] = []
var target_sprite: Sprite2D = null

# Visual style configuration
var fill_color: Color = Color(0.18, 0.88, 0.48, 0.28)
var line_color: Color = Color(0.25, 1.0, 0.55, 0.95)
var vertex_color: Color = Color(1.0, 1.0, 1.0, 0.9)
var line_width: float = 2.0
var vertex_radius: float = 2.5

## Updates cached preview polygons for a specific Sprite2D
func update_data(sprite: Sprite2D, polygons: Array[PackedVector2Array]) -> void:
	target_sprite = sprite
	cached_polygons = polygons

## Clears preview data
func clear() -> void:
	target_sprite = null
	cached_polygons.clear()

## Renders preview geometry onto the editor viewport overlay
func draw_on_overlay(overlay: Control) -> void:
	if not is_active:
		return
	if target_sprite == null or not is_instance_valid(target_sprite):
		return
	if not target_sprite.is_inside_tree() or not target_sprite.visible:
		return
	if cached_polygons.is_empty():
		return

	# Transform from Sprite2D local coordinate space to editor viewport overlay space
	var sprite_canvas_xform: Transform2D = target_sprite.get_global_transform_with_canvas()
	var viewport_xform: Transform2D = overlay.get_viewport().get_final_transform()
	var screen_xform: Transform2D = viewport_xform * sprite_canvas_xform

	for poly in cached_polygons:
		var n: int = poly.size()
		if n < 3:
			continue

		var screen_poly := PackedVector2Array()
		screen_poly.resize(n)
		for i in range(n):
			screen_poly[i] = screen_xform * poly[i]

		# Draw translucent filled area
		overlay.draw_colored_polygon(screen_poly, fill_color)

		# Draw border outline (closed)
		var closed_line := PackedVector2Array(screen_poly)
		closed_line.append(screen_poly[0])
		overlay.draw_polyline(closed_line, line_color, line_width, true)

		# Draw vertex dots
		for pt in screen_poly:
			overlay.draw_circle(pt, vertex_radius, vertex_color)
