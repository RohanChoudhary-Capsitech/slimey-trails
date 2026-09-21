extends CharacterBody2D
class_name SlimeController
## Tilt-the-level slime.
##
## The player does NOT move the slime directly any more. Left/right input
## rotates the LEVEL (see LevelTilt.gd). Gravity always points straight down
## in world space, so when the level tilts the slime slides/rolls downhill
## by itself. This script only handles gravity, sliding friction, impact
## squash and the face expression.
##
## IMPORTANT: keep this node as a SIBLING of the Level node (not a child of
## it), otherwise the slime rotates together with the level and nothing slides.

@export_group("Gravity & Sliding")
@export var gravity: float = 1200.0
## How "sticky" the surface is. Higher = slime slides slower down a tilt.
## Terminal slide speed is roughly (gravity * sin(tilt)) / surface_drag.
@export var surface_drag: float = 2.0
@export var max_speed: float = 700.0

@export_group("Jumping (optional)")
@export var can_jump: bool = false
@export var jump_speed: float = 420.0
@export var jump_stretch_strength: float = 260.0

@export_group("Impact Squash")
## Minimum speed INTO a surface (px/s) before the slime squashes.
@export var squash_min_speed: float = 220.0
## squash strength = impact speed * this, then clamped below.
@export var squash_strength_per_speed: float = 0.5
@export var squash_min_strength: float = 80.0
@export var squash_max_strength: float = 320.0
## Stops the squash from re-triggering every frame while sliding.
@export var squash_cooldown: float = 0.12

@export_group("Expression")
@export var move_face_min_speed: float = 30.0

@onready var body: SoftBodySlime = $Body
@onready var face: SlimeFace = $Face

var _touching_surface: bool = false
var _surface_normal: Vector2 = Vector2.UP
var _cooldown_left: float = 0.0


func _ready() -> void:
	# Default behaviour glues the body to slopes so it never slides.
	# We WANT it to slide, so turn that off.
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(70.0)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	# 1) Gravity is ALWAYS applied (even on the floor). move_and_slide()
	#    projects it along the surface, which is what makes the slime slide
	#    down a tilted platform.
	velocity += Vector2.DOWN * gravity * delta

	# 2) Surface friction so it doesn't accelerate forever on a slope.
	if _touching_surface:
		velocity *= 1.0 - clampf(surface_drag * delta, 0.0, 1.0)
	velocity = velocity.limit_length(max_speed)

	# 3) Optional jump, pushed away from whatever surface we're on.
	if can_jump and _touching_surface and Input.is_action_just_pressed("ui_accept"):
		velocity += _surface_normal * jump_speed
		body.stretch(jump_stretch_strength, _surface_normal)
		face.play_expression("surprised")

	var velocity_before := velocity
	move_and_slide()
	_read_collisions(velocity_before)
	_update_expression()


## Looks at what we hit this frame: remembers the surface we're standing on
## and squashes the body if we hit it fast enough.
func _read_collisions(velocity_before: Vector2) -> void:
	var best_normal := Vector2.ZERO
	var hardest_impact := 0.0
	var impact_normal := Vector2.UP

	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()

		# most upward-facing contact = the "ground" for jump direction
		if best_normal == Vector2.ZERO or normal.y < best_normal.y:
			best_normal = normal

		# speed heading INTO this surface (positive = hitting it)
		var impact := -velocity_before.dot(normal)
		if impact > hardest_impact:
			hardest_impact = impact
			impact_normal = normal

	_touching_surface = best_normal != Vector2.ZERO
	if _touching_surface:
		_surface_normal = best_normal

	if hardest_impact > squash_min_speed and _cooldown_left <= 0.0:
		_cooldown_left = squash_cooldown
		var strength := clampf(hardest_impact * squash_strength_per_speed,
				squash_min_strength, squash_max_strength)
		body.squash(strength, impact_normal)


func _update_expression() -> void:
	if not _touching_surface:
		return
	# Face looks the way the slime is sliding.
	if absf(velocity.x) > move_face_min_speed:
		face.flip(velocity.x < 0.0)
		face.play_expression("move")
		body.play_state("move")
	else:
		face.play_expression("idle")
		body.play_state("idle")


## Call from an enemy/hazard script to make the slime react physically and
## show a hurt expression, e.g.:  slime.take_hit(spike.global_position)
func take_hit(from_position: Vector2, strength: float = 200.0) -> void:
	var away_direction := (global_position - from_position).normalized()
	body.poke(away_direction, strength)
	face.play_expression("hurt")
