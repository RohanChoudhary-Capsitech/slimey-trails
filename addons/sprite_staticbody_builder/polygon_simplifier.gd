@tool
class_name PolygonSimplifier
extends RefCounted

## Utility class for cleaning, simplifying, decimating, and decomposing 2D polygons
## for high-performance 2D physics collisions.

## Simplification presets enum
enum SimplificationLevel {
	LOW = 0,
	MEDIUM = 1,
	HIGH = 2,
	CUSTOM = 3,
}

## Returns the epsilon tolerance corresponding to a simplification preset
static func get_epsilon_for_preset(preset: SimplificationLevel, custom_val: float = 2.0) -> float:
	match preset:
		SimplificationLevel.LOW:
			return 1.0
		SimplificationLevel.MEDIUM:
			return 2.5
		SimplificationLevel.HIGH:
			return 5.0
		SimplificationLevel.CUSTOM:
			return maxf(custom_val, 0.05)
		_:
			return 2.5

## Cleans consecutive duplicate points and removes self-closing redundancy
static func clean_polygon(polygon: PackedVector2Array, min_dist_sq: float = 0.25) -> PackedVector2Array:
	var count: int = polygon.size()
	if count < 3:
		return PackedVector2Array()

	var result := PackedVector2Array()
	var prev: Vector2 = polygon[count - 1]

	for i in range(count):
		var curr: Vector2 = polygon[i]
		if curr.distance_squared_to(prev) > min_dist_sq:
			result.append(curr)
			prev = curr

	if result.size() < 3:
		return PackedVector2Array()

	# Ensure first and last are not duplicate
	if result[0].distance_squared_to(result[result.size() - 1]) <= min_dist_sq:
		result.remove_at(result.size() - 1)

	return result if result.size() >= 3 else PackedVector2Array()

## Calculates unsigned area of a polygon using the Shoelace formula
static func get_polygon_area(polygon: PackedVector2Array) -> float:
	var n: int = polygon.size()
	if n < 3:
		return 0.0
	var area: float = 0.0
	for i in range(n):
		var j: int = (i + 1) % n
		area += polygon[i].x * polygon[j].y
		area -= polygon[j].x * polygon[i].y
	return absf(area) * 0.5

## Distance from point P to line segment AB
static func _perpendicular_distance_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var line_vec: Vector2 = b - a
	var len_sq: float = line_vec.length_squared()
	if len_sq <= 0.00001:
		return p.distance_squared_to(a)
	var t: float = clampf((p - a).dot(line_vec) / len_sq, 0.0, 1.0)
	var projection: Vector2 = a + t * line_vec
	return p.distance_squared_to(projection)

## Recursive Ramer-Douglas-Peucker simplification on a slice of vertices
static func _rdp_recursive(points: PackedVector2Array, start_idx: int, end_idx: int, epsilon_sq: float, keep_mask: Array[bool]) -> void:
	var dmax_sq: float = 0.0
	var index: int = start_idx
	var a: Vector2 = points[start_idx]
	var b: Vector2 = points[end_idx]

	for i in range(start_idx + 1, end_idx):
		var d_sq: float = _perpendicular_distance_sq(points[i], a, b)
		if d_sq > dmax_sq:
			index = i
			dmax_sq = d_sq

	if dmax_sq > epsilon_sq:
		keep_mask[index] = true
		_rdp_recursive(points, start_idx, index, epsilon_sq, keep_mask)
		_rdp_recursive(points, index, end_idx, epsilon_sq, keep_mask)

## Simplifies a closed polygon using Ramer-Douglas-Peucker
static func simplify_closed_polygon(polygon: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	var n: int = polygon.size()
	if n <= 3:
		return polygon.duplicate()

	# Find point farthest from point 0 to break the closed loop into two segments
	var p0: Vector2 = polygon[0]
	var max_dist_sq: float = -1.0
	var far_idx: int = 1

	for i in range(1, n):
		var d_sq: float = p0.distance_squared_to(polygon[i])
		if d_sq > max_dist_sq:
			max_dist_sq = d_sq
			far_idx = i

	var keep_mask: Array[bool] = []
	keep_mask.resize(n)
	keep_mask.fill(false)
	keep_mask[0] = true
	keep_mask[far_idx] = true

	var eps_sq: float = epsilon * epsilon
	_rdp_recursive(polygon, 0, far_idx, eps_sq, keep_mask)
	_rdp_recursive(polygon, far_idx, n - 1, eps_sq, keep_mask)

	var simplified := PackedVector2Array()
	for i in range(n):
		if keep_mask[i]:
			simplified.append(polygon[i])

	return clean_polygon(simplified)

## Reduces polygon vertex count to stay strictly within max_points limit
static func decimate_to_max_points(polygon: PackedVector2Array, max_points: int, initial_epsilon: float = 1.0) -> PackedVector2Array:
	var cleaned: PackedVector2Array = clean_polygon(polygon)
	if cleaned.size() <= max_points:
		return cleaned

	var cur_eps: float = maxf(initial_epsilon, 0.5)
	var result: PackedVector2Array = cleaned
	var iterations: int = 0

	# Progressively increase epsilon until point count is <= max_points
	while result.size() > max_points and iterations < 25:
		cur_eps *= 1.35
		result = simplify_closed_polygon(cleaned, cur_eps)
		iterations += 1

	# If still slightly above max_points, pick evenly spaced vertices
	if result.size() > max_points and max_points >= 3:
		var final_pts := PackedVector2Array()
		var step: float = float(result.size()) / float(max_points)
		for i in range(max_points):
			var idx: int = clampi(int(round(i * step)), 0, result.size() - 1)
			final_pts.append(result[idx])
		result = clean_polygon(final_pts)

	return result

## Decomposes a possibly concave polygon into multiple convex polygons
static func decompose_to_convex(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var cleaned: PackedVector2Array = clean_polygon(polygon)
	if cleaned.size() < 3:
		return []

	# Ensure counter-clockwise / positive winding if needed by Godot
	var area: float = get_polygon_area(cleaned)
	if area < 1.0:
		return []

	var convex_pieces: Array[PackedVector2Array] = Geometry2D.decompose_polygon_in_convex(cleaned)
	if not convex_pieces.is_empty():
		var valid_pieces: Array[PackedVector2Array] = []
		for piece in convex_pieces:
			var cl: PackedVector2Array = clean_polygon(piece)
			if cl.size() >= 3 and get_polygon_area(cl) >= 1.0:
				valid_pieces.append(cl)
		if not valid_pieces.is_empty():
			return valid_pieces

	# Fallback: triangulate if decompose failed
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(cleaned)
	if not indices.is_empty():
		var tri_pieces: Array[PackedVector2Array] = []
		for i in range(0, indices.size(), 3):
			var tri := PackedVector2Array([
				cleaned[indices[i]],
				cleaned[indices[i + 1]],
				cleaned[indices[i + 2]]
			])
			tri_pieces.append(tri)
		return tri_pieces

	# If all else fails, return original
	return [cleaned]
