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
## react to it (inertia wobble) - it never moves the body itself.

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

@export_group("Look")
@export var skin_color: Color = Color(0.45, 0.85, 0.55, 1.0)
@export var skin_texture: Texture2D

var _points: PackedVector2Array
var _velocities: PackedVector2Array
var _rest_points: PackedVector2Array
var _polygon: Polygon2D
var _last_body_velocity: Vector2 = Vector2.ZERO
var _body: CharacterBody2D


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

	_setup_idle_breathing()


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
	_rest_points.resize(point_count)
	_points.resize(point_count)
	_velocities.resize(point_count)
	for i in point_count:
		var angle := TAU * float(i) / float(point_count)
		var p := Vector2(cos(angle), sin(angle)) * radius
		_rest_points[i] = p
		_points[i] = p
		_velocities[i] = Vector2.ZERO


func _physics_process(delta: float) -> void:
	_apply_inertia(delta)
	_simulate_springs(delta)
	_update_polygon()


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
	for i in point_count:
		var force := (_rest_points[i] - _points[i]) * spring_stiffness

		var prev_i := (i - 1 + point_count) % point_count
		var next_i := (i + 1) % point_count
		force += ((_points[prev_i] - _points[i]) - (_rest_points[prev_i] - _rest_points[i])) * edge_stiffness
		force += ((_points[next_i] - _points[i]) - (_rest_points[next_i] - _rest_points[i])) * edge_stiffness

		force -= _velocities[i] * damping

		_velocities[i] += force * delta
		_points[i] += _velocities[i] * delta


func _update_polygon() -> void:
	_polygon.polygon = _points
	if skin_texture:
		var uvs := PackedVector2Array()
		for p in _rest_points:
			uvs.append((p / (radius * 2.0)) + Vector2(0.5, 0.5))
		_polygon.uv = uvs


## A subtle, permanent idle "breathing" loop driven by a real AnimationPlayer,
## layered on top of the spring simulation above so the slime never looks
## perfectly frozen even when it's standing still.
func _setup_idle_breathing() -> void:
	var anim_player := AnimationPlayer.new()
	anim_player.name = "IdleAnimationPlayer"
	add_child(anim_player)

	var animation := Animation.new()
	animation.length = 1.6
	animation.loop_mode = Animation.LOOP_LINEAR

	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, ".:scale")
	animation.value_track_set_update_mode(track, Animation.UPDATE_CONTINUOUS)
	animation.track_insert_key(track, 0.0, Vector2(1.0, 1.0))
	animation.track_insert_key(track, 0.8, Vector2(1.04, 0.94))
	animation.track_insert_key(track, 1.6, Vector2(1.0, 1.0))

	var library := AnimationLibrary.new()
	library.add_animation("idle_breathe", animation)
	anim_player.add_animation_library("", library)
	anim_player.play("idle_breathe")


## Instantly nudges every point outward from the center. Good generic impulse
## for hits, bumps, or anything that isn't a clean squash/stretch.
func apply_impulse(impulse: Vector2) -> void:
	for i in point_count:
		_velocities[i] += impulse


## Flattens the body against a surface - call when landing hard.
## `surface_normal` is the direction the surface faces (Vector2.UP = normal floor).
## Points are pushed in along the normal and out along the surface, so the
## squash follows the tilted platform instead of always squashing "downward".
func squash(strength: float, surface_normal: Vector2 = Vector2.UP) -> void:
	var tangent := surface_normal.orthogonal()
	for i in point_count:
		var dir := _rest_points[i].normalized()
		var along_normal := dir.dot(surface_normal)
		var along_tangent := dir.dot(tangent)
		_velocities[i] += (tangent * along_tangent - surface_normal * along_normal) * strength


## Elongates the body away from a surface - call on jump takeoff.
func stretch(strength: float, surface_normal: Vector2 = Vector2.UP) -> void:
	var tangent := surface_normal.orthogonal()
	for i in point_count:
		var dir := _rest_points[i].normalized()
		var along_normal := dir.dot(surface_normal)
		var along_tangent := dir.dot(tangent)
		_velocities[i] += (surface_normal * along_normal - tangent * along_tangent) * strength


## A poke from a specific direction - use for getting hit or bumping a wall.
func poke(direction: Vector2, strength: float) -> void:
	apply_impulse(direction.normalized() * strength)


## No-op here - the physics body has no discrete "poses" to switch between,
## it's just continuously simulated. Exists only so SlimeController.gd can
## call body.play_state(...) the same way regardless of which body script
## (this one or SlimeBodySprite.gd) is attached to the Body node.
func play_state(_state_name: String) -> void:
	pass