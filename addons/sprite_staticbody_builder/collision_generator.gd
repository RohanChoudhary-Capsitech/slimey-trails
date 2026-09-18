@tool
class_name CollisionGenerator
extends RefCounted

## Generates 2D collision polygon geometry from a Sprite2D's texture alpha channel.

enum CollisionMode {
	SINGLE_POLYGON = 0,
	CONVEX_DECOMPOSITION = 1,
}

## Options dictionary structure:
## {
##   "alpha_threshold": 0.5,
##   "simplification": PolygonSimplifier.SimplificationLevel.MEDIUM,
##   "custom_epsilon": 2.5,
##   "max_points": 64,
##   "collision_mode": CollisionMode.SINGLE_POLYGON
## }

## Result dictionary structure:
## {
##   "success": bool,
##   "error_message": String,
##   "polygons": Array[PackedVector2Array], # in Sprite2D local coordinate space
##   "total_points": int,
##   "polygon_count": int,
##   "tex_size": Vector2
## }

## Generates collision polygons in Sprite2D local space from the given Sprite2D
static func generate_from_sprite(sprite: Sprite2D, options: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"error_message": "",
		"polygons": [] as Array[PackedVector2Array],
		"total_points": 0,
		"polygon_count": 0,
		"tex_size": Vector2.ZERO
	}

	if sprite == null:
		result.error_message = "No Sprite2D provided."
		return result

	var texture: Texture2D = sprite.texture
	if texture == null:
		result.error_message = "Sprite2D does not have a valid texture."
		return result

	# Extract image
	var image: Image = _extract_image(texture)
	if image == null:
		result.error_message = "Failed to extract Image data from texture."
		return result

	# Handle Sprite2D region if enabled
	var tex_size := Vector2(image.get_width(), image.get_height())
	if sprite.region_enabled and sprite.region_rect.has_area():
		var reg: Rect2 = sprite.region_rect
		var clip_rect := Rect2i(Vector2i(int(reg.position.x), int(reg.position.y)), Vector2i(int(reg.size.x), int(reg.size.y)))
		var img_rect := Rect2i(Vector2i.ZERO, image.get_size())
		clip_rect = clip_rect.intersection(img_rect)
		if clip_rect.has_area():
			image = image.get_region(clip_rect)
			tex_size = Vector2(image.get_width(), image.get_height())
		else:
			result.error_message = "Sprite2D region rect is outside texture bounds."
			return result

	result.tex_size = tex_size

	# Settings
	var alpha_thresh: float = clampf(float(options.get("alpha_threshold", 0.5)), 0.0, 1.0)
	var simplif_preset: int = int(options.get("simplification", PolygonSimplifier.SimplificationLevel.MEDIUM))
	var custom_eps: float = float(options.get("custom_epsilon", 2.5))
	var max_points: int = clampi(int(options.get("max_points", 64)), 3, 2048)
	var mode: int = int(options.get("collision_mode", CollisionMode.SINGLE_POLYGON))

	var epsilon: float = PolygonSimplifier.get_epsilon_for_preset(simplif_preset as PolygonSimplifier.SimplificationLevel, custom_eps)

	# Build BitMap from alpha channel
	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image, alpha_thresh)

	# Check if bitmap has any opaque pixels
	var img_size := image.get_size()
	var search_rect := Rect2i(Vector2i.ZERO, img_size)
	var raw_polygons: Array[PackedVector2Array] = bitmap.opaque_to_polygons(search_rect, epsilon)

	if raw_polygons.is_empty():
		result.error_message = "No opaque pixels found with alpha >= " + str(snappedf(alpha_thresh, 0.01))
		return result

	# Process holes and nested contours using polygon clipping
	var resolved_polygons: Array[PackedVector2Array] = _resolve_holes_and_islands(raw_polygons)
	if resolved_polygons.is_empty():
		resolved_polygons = raw_polygons

	var output_polygons: Array[PackedVector2Array] = []

	# Process each polygon
	for poly in resolved_polygons:
		var cleaned: PackedVector2Array = PolygonSimplifier.clean_polygon(poly)
		if cleaned.size() < 3:
			continue

		# Discard microscopic noise (e.g. 1-2 pixel isolated specs)
		if PolygonSimplifier.get_polygon_area(cleaned) < 4.0:
			continue

		# Decimate vertices if exceeding max points
		var simplified: PackedVector2Array = PolygonSimplifier.decimate_to_max_points(cleaned, max_points, epsilon)
		if simplified.size() < 3:
			continue

		# Handle Convex Decomposition if requested
		if mode == CollisionMode.CONVEX_DECOMPOSITION:
			var convex_pieces: Array[PackedVector2Array] = PolygonSimplifier.decompose_to_convex(simplified)
			for piece in convex_pieces:
				var transformed_piece: PackedVector2Array = _map_pixels_to_sprite_local(piece, sprite, tex_size)
				if transformed_piece.size() >= 3:
					output_polygons.append(transformed_piece)
		else:
			var transformed_poly: PackedVector2Array = _map_pixels_to_sprite_local(simplified, sprite, tex_size)
			if transformed_poly.size() >= 3:
				output_polygons.append(transformed_poly)

	if output_polygons.is_empty():
		result.error_message = "Generated polygons were too small or degraded during simplification."
		return result

	result.success = true
	result.polygons = output_polygons
	result.polygon_count = output_polygons.size()
	var total_pts: int = 0
	for p in output_polygons:
		total_pts += p.size()
	result.total_points = total_pts

	return result

## Safely extracts and prepares an Image from any Texture2D
static func _extract_image(texture: Texture2D) -> Image:
	if texture == null:
		return null

	var image: Image = null
	if texture is AtlasTexture:
		var atlas: AtlasTexture = texture as AtlasTexture
		if atlas.atlas != null:
			var base_img: Image = atlas.atlas.get_image()
			if base_img != null:
				image = base_img.get_region(atlas.region)
	else:
		image = texture.get_image()

	if image == null:
		return null

	# Duplicate to prevent altering cached editor texture
	image = image.duplicate()

	# Decompress if compressed texture
	if image.is_compressed():
		var err: Error = image.decompress()
		if err != OK:
			push_warning("SpriteStaticBodyBuilder: Could not decompress texture image: " + error_string(err))

	# Ensure RGBA format with alpha channel
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	return image

## Differentiates external islands from internal holes and handles hole subtraction
static func _resolve_holes_and_islands(polygons: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	if polygons.size() <= 1:
		return polygons

	# Classify each polygon into outer boundaries vs inner holes
	# A polygon whose representative point is inside another polygon is considered a hole of that polygon
	var n: int = polygons.size()
	var is_hole: Array[bool] = []
	is_hole.resize(n)
	is_hole.fill(false)

	var parent_indices: Array[int] = []
	parent_indices.resize(n)
	parent_indices.fill(-1)

	for i in range(n):
		var p_i: PackedVector2Array = polygons[i]
		if p_i.is_empty():
			continue
		var test_point: Vector2 = p_i[0]

		for j in range(n):
			if i == j:
				continue
			var p_j: PackedVector2Array = polygons[j]
			if p_j.is_empty():
				continue
			if Geometry2D.is_point_in_polygon(test_point, p_j):
				# Poly i is inside Poly j
				is_hole[i] = true
				parent_indices[i] = j
				break

	var outer_polys: Array[PackedVector2Array] = []
	var holes_for_parent: Dictionary = {} # int -> Array[PackedVector2Array]

	for i in range(n):
		if is_hole[i]:
			var parent_idx: int = parent_indices[i]
			if not holes_for_parent.has(parent_idx):
				holes_for_parent[parent_idx] = [] as Array[PackedVector2Array]
			holes_for_parent[parent_idx].append(polygons[i])

	# Subtract holes from their parent polygon using Geometry2D.clip_polygons
	var final_list: Array[PackedVector2Array] = []
	for i in range(n):
		if not is_hole[i]:
			var current_poly_set: Array[PackedVector2Array] = [polygons[i]]
			if holes_for_parent.has(i):
				var holes: Array[PackedVector2Array] = holes_for_parent[i]
				for hole in holes:
					var new_poly_set: Array[PackedVector2Array] = []
					for sub_poly in current_poly_set:
						var clipped: Array[PackedVector2Array] = Geometry2D.clip_polygons(sub_poly, hole)
						if not clipped.is_empty():
							new_poly_set.append_array(clipped)
						else:
							new_poly_set.append(sub_poly)
					current_poly_set = new_poly_set

			for p in current_poly_set:
				if p.size() >= 3:
					final_list.append(p)

	return final_list if not final_list.is_empty() else polygons

## Transforms raw image pixel coordinates into the Sprite2D's local coordinate space
static func _map_pixels_to_sprite_local(pixel_polygon: PackedVector2Array, sprite: Sprite2D, tex_size: Vector2) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	var centered: bool = sprite.centered
	var offset: Vector2 = sprite.offset
	var flip_h: bool = sprite.flip_h
	var flip_v: bool = sprite.flip_v
	var half_size: Vector2 = tex_size * 0.5

	for pt in pixel_polygon:
		var x: float = pt.x
		var y: float = pt.y

		if flip_h:
			x = tex_size.x - x
		if flip_v:
			y = tex_size.y - y

		var local_pt: Vector2
		if centered:
			local_pt = Vector2(x, y) - half_size + offset
		else:
			local_pt = Vector2(x, y) + offset

		transformed.append(local_pt)

	return transformed
