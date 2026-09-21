extends Node2D
class_name SoftBodySlime
## Procedural 2D "soft body" for the slime's visual mesh.
##
## The blob is a ring of point-masses connected by springs: each point is
## pulled back toward its resting position on a circle, and pulled toward its
## two neighbors so the outline stays smooth. Nothing here is a rigid image -
## every frame the points are re-simulated and fed into a Polygon2D, which is
## what actually gives the jelly / squash-and-stretch look.
##
## This node expects to be a direct child of a CharacterBody2D (the thing
## that owns movement + collision). It reads that body's velocity purely to
## react to it (inertia wobble, motion stretch) - it never moves the body.

@export_group("Shape")
@export var point_count: int = 14
## SLIME SIZE LIVES HERE. Radius in pixels (diameter = radius * 2).
## Smaller number = smaller slime. Try 20-26 if 38 feels too big.
@export var radius: float = 12.0
## If the parent has a CollisionShape2D with a CircleShape2D, resize it to match
## `radius` so the visible blob and the collision are always the same size.
@export var sync_collision_radius: bool = true

@export_group("Softness")
## How strongly each point is pulled back to its resting spot. Higher = stiffer jelly.
@export var spring_stiffness: float = 260.0
## How strongly neighboring points pull on each other. Higher = smoother outline.
@export var edge_stiffness: float = 90.0
## Velocity damping so the wobble settles instead of oscillating forever.
@export var damping: float = 6.0
## How much of the parent body's own acceleration turns into squash/stretch.
@export var inertia_influence: float = 0.012
## While the slime touches a floor/wall, stiffness and damping are multiplied by
## these. Higher = firmer and less wobbly on the ground, still soft in the air.
@export var grounded_stiffness_multiplier: float = 2.0
@export var grounded_damping_multiplier: float = 2.5

@export_group("Motion Juice")
## Max extra length along the direction of travel (0.35 = 35% longer at top speed).
@export var motion_stretch_amount: float = 0.35
## Speed (px/s) at which the stretch reaches its maximum.
@export var motion_stretch_speed: float = 900.0
## Pulls the back of the blob into a teardrop tail. 0 = plain oval.
@export var tail_amount: float = 0.35
## While sliding on a surface the belly flattens against it (0 = off).
@export var slide_flatten: float = 0.25
## How fast the shape follows the motion. Higher = snappier.
@export var motion_smoothing: float = 10.0

@export_group("Idle Breathing")
## 1 = default breathing, 0.3 = very subtle, 0 = no breathing at all.
## Breathing automatically fades out while the slime is moving.
@export_range(0.0, 2.0, 0.05) var idle_breathing_strength: float = 1.0

@export_group("Look")
@export var skin_color: Color = Color(0.45, 0.85, 0.55, 1.0)
@export var skin_texture: Texture2D

## Set every frame by SlimeController.
var is_grounded: bool = false
var surface_normal: Vector2 = Vector2.UP

var _points: PackedVector2Array
var _velocities: PackedVector2Array
var _base_rest_points: PackedVector2Array   # perfect circle
var _rest_points: PackedVector2Array        # circle deformed by motion
var _polygon: Polygon2D
var _last_body_velocity: Vector2 = Vector2.ZERO
var _body: CharacterBody2D

var _motion_amount: float = 0.0     # 0..1, how fast we're moving
var _ground_amount: float = 0.0     # 0..1, smoothed "touching a surface"
var _motion_angle: float = 0.0
var _breath_time: float = 0.0


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	_build_rest_shape()
	if sync_collision_radius:
		_sync_collision_radius()

	_polygon = Polygon2D.new()
	_polygon.name = "Skin"
	_polygon.color = skin_color
	if skin_texture:
		_polygon.texture = skin_texture
	add_child(_polygon)
	_update_polygon()


func _sync_collision_radius() -> void:
	if _body == null:
		return
	for child in _body.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			# duplicate so we never edit a shared resource
			var circle := (child.shape as CircleShape2D).duplicate() as CircleShape2D
			circle.radius = radius
			child.shape = circle
			return


func _build_rest_shape() -> void:
	_base_rest_points.resize(point_count)
	_rest_points.resize(point_count)
	_points.resize(point_count)
	_velocities.resize(point_count)
	for i in point_count:
		var angle := TAU * float(i) / float(point_count)
		var p := Vector2(cos(angle), sin(angle)) * radius
		_base_rest_points[i] = p
		_rest_points[i] = p
		_points[i] = p
		_velocities[i] = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_update_motion_shape(delta)
	_apply_inertia(delta)
	_simulate_springs(delta)
	_update_polygon()
	_update_breathing(delta)


## Reshapes the RESTING outline based on speed: an oval stretched along the
## direction of travel, a tail trailing behind, and a belly flattened against
## the surface. The springs then pull the jelly toward this shape smoothly,
## so movement looks fluid instead of just pulsing.
func _update_motion_shape(delta: float) -> void:
	if _body == null:
		return
	var follow := 1.0 - exp(-motion_smoothing * delta)
	var velocity := _body.velocity
	var speed := velocity.length()

	_motion_amount = lerpf(_motion_amount, clampf(speed / motion_stretch_speed, 0.0, 1.0), follow)
	_ground_amount = lerpf(_ground_amount, 1.0 if is_grounded else 0.0, follow)
	if speed > 5.0:
		_motion_angle = lerp_angle(_motion_angle, velocity.angle(), follow)

	var dir := Vector2.RIGHT.rotated(_motion_angle)
	var perp := dir.orthogonal()
	var stretch_amount := motion_stretch_amount * _motion_amount
	var flatten := slide_flatten * _motion_amount * _ground_amount

	for i in point_count:
		var base := _base_rest_points[i]
		var along := base.dot(dir)
		var across := base.dot(perp)

		# oval: longer along travel, slightly thinner across (keeps volume)
		var p := dir * along * (1.0 + stretch_amount) + perp * across * (1.0 - stretch_amount * 0.45)
		# shift backward so the FRONT stays near the collision edge and the
		# extra length trails behind (no visible sinking into walls/floor)
		p -= dir * radius * stretch_amount * 0.5

		# tail: points behind the travel direction are dragged further back
		var behind := maxf(-base.normalized().dot(dir), 0.0)
		p += dir * along * tail_amount * _motion_amount * behind

		# belly flattens against the surface while sliding
		if flatten > 0.0:
			p -= surface_normal * p.dot(surface_normal) * flatten * 0.5
			# keep the belly touching the surface instead of hovering above it
			p -= surface_normal * radius * flatten * 0.5

		_rest_points[i] = p


func _apply_inertia(delta: float) -> void:
	if _body == null:
		return
	var current_velocity := _body.velocity
	var safe_delta := maxf(delta, 0.0001)
	var acceleration := (current_velocity - _last_body_velocity) / safe_delta
	_last_body_velocity = current_velocity
	# Points "lag behind" sudden changes in speed - accelerate right and the
	# body leans/squishes left for a frame, exactly like real jelly.
	var inertia_force := -acceleration * inertia_influence
	for i in point_count:
		_velocities[i] += inertia_force * delta


func _simulate_springs(delta: float) -> void:
	var k := spring_stiffness
	var edge_k := edge_stiffness
	var c := damping
	if is_grounded:
		k *= grounded_stiffness_multiplier
		edge_k *= grounded_stiffness_multiplier
		c *= grounded_damping_multiplier

	for i in point_count:
		var force := (_rest_points[i] - _points[i]) * k

		var prev_i := (i - 1 + point_count) % point_count
		var next_i := (i + 1) % point_count
		force += ((_points[prev_i] - _points[i]) - (_rest_points[prev_i] - _rest_points[i])) * edge_k
		force += ((_points[next_i] - _points[i]) - (_rest_points[next_i] - _rest_points[i])) * edge_k

		force -= _velocities[i] * c

		_velocities[i] += force * delta
		_points[i] += _velocities[i] * delta


func _update_polygon() -> void:
	_polygon.polygon = _points
	if skin_texture:
		var uvs := PackedVector2Array()
		for p in _base_rest_points:
			uvs.append((p / (radius * 2.0)) + Vector2(0.5, 0.5))
		_polygon.uv = uvs


## Gentle idle "breathing", done in code so it can fade out while the slime
## moves (the old looping animation kept pulsing even during a slide).
func _update_breathing(delta: float) -> void:
	_breath_time += delta
	var breath := (1.0 - cos(_breath_time * TAU / 1.6)) * 0.5   # 0..1..0 every 1.6s
	var k := idle_breathing_strength * (1.0 - _motion_amount)
	scale = Vector2(1.0 + 0.04 * k * breath, 1.0 - 0.06 * k * breath)


## Instantly nudges every point outward from the center. Good generic impulse
## for hits, bumps, or anything that isn't a clean squash/stretch.
func apply_impulse(impulse: Vector2) -> void:
	for i in point_count:
		_velocities[i] += impulse


## Flattens the body against a surface - call when landing hard.
## `normal` is the direction the surface faces (Vector2.UP = normal floor).
## Points are pushed in along the normal and out along the surface, so the
## squash follows the tilted platform instead of always squashing "downward".
func squash(strength: float, normal: Vector2 = Vector2.UP) -> void:
	var tangent := normal.orthogonal()
	for i in point_count:
		var dir := _base_rest_points[i].normalized()
		var along_normal := dir.dot(normal)
		var along_tangent := dir.dot(tangent)
		_velocities[i] += (tangent * along_tangent - normal * along_normal) * strength


## Elongates the body away from a surface - call on jump takeoff.
func stretch(strength: float, normal: Vector2 = Vector2.UP) -> void:
	var tangent := normal.orthogonal()
	for i in point_count:
		var dir := _base_rest_points[i].normalized()
		var along_normal := dir.dot(normal)
		var along_tangent := dir.dot(tangent)
		_velocities[i] += (normal * along_normal - tangent * along_tangent) * strength


## A poke from a specific direction - use for getting hit or bumping a wall.
func poke(direction: Vector2, strength: float) -> void:
	apply_impulse(direction.normalized() * strength)


## No-op here - the physics body has no discrete "poses" to switch between,
## it's just continuously simulated. Exists only so SlimeController.gd can
## call body.play_state(...) the same way regardless of which body script
## (this one or SlimeBodySprite.gd) is attached to the Body node.
func play_state(_state_name: String) -> void:
	pass