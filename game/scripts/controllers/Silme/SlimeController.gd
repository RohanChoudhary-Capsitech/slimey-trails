extends CharacterBody2D
class_name SlimeController
## Tilt-the-level slime.
##
## The player does NOT move the slime directly. Dragging rotates the STAGE
## (see StageRotator.gd). Gravity always points straight down in world space,
## so when the stage tilts the slime slides/rolls downhill by itself.
## This script handles gravity, sliding, impact squash, particles and the
## face expression. The soft-body shape lives in SoftBodySlime.gd.

@export_group("Gravity & Sliding")
## Ignore the parent's rotation/movement. Leave ON while the slime is a child
## of a rotating stage node; it has no effect if the parent never moves.
@export var detach_from_parent_transform: bool = true
@export var gravity: float = 2000.0
## Extra pull DOWNHILL while touching a tilted surface. 1 = normal physics,
## 2.5 = slides 2.5x faster. THIS is the main "make it faster" knob.
@export var slide_boost: float = 2.5
## Surface friction. Lower = slippery and fast. Higher = sticky and slow.
## Top slide speed is roughly (gravity * slide_boost * sin(tilt)) / surface_drag.
@export var surface_drag: float = 1.0
@export var max_speed: float = 2500.0

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

@export_group("Juice")
## Slime droplets kicked up behind the slime while it slides.
@export var trail_enabled: bool = true
@export var trail_min_speed: float = 250.0
## Droplet burst when hitting a surface hard.
@export var splat_enabled: bool = true
## The face slides toward the direction of travel (fraction of radius, 0 = off).
@export var face_lead: float = 0.18

@export_group("Expression")
@export var move_face_min_speed: float = 30.0

@onready var body: SoftBodySlime = $Body
@onready var face: SlimeFace = $Face
@onready var _face_base_position: Vector2 = $Face.position

var _touching_surface: bool = false
var _surface_normal: Vector2 = Vector2.UP
var _cooldown_left: float = 0.0
var _trail: CPUParticles2D
var _splat: CPUParticles2D


func _ready() -> void:
	# Keep the slime in WORLD space even if it sits under a rotating stage
	# node (e.g. StageRotator). Otherwise the stage drags the slime around
	# with it and gravity has no visible effect.
	if detach_from_parent_transform:
		var start_position := global_position
		top_level = true
		global_position = start_position

	# Default behaviour glues the body to slopes so it never slides.
	# We WANT it to slide, so turn that off.
	floor_stop_on_slope = false
	floor_max_angle = deg_to_rad(70.0)

	_setup_particles()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	# 1) Gravity is ALWAYS applied (even on the floor). move_and_slide()
	#    projects it along the surface, which is what makes the slime slide
	#    down a tilted platform.
	velocity += Vector2.DOWN * gravity * delta

	# 2) Extra downhill pull so tilts feel fast and responsive.
	if _touching_surface and slide_boost > 1.0:
		var downhill := Vector2.DOWN.slide(_surface_normal)   # length = sin(tilt)
		velocity += downhill * gravity * (slide_boost - 1.0) * delta

	# 3) Surface friction so it doesn't accelerate forever on a slope.
	if _touching_surface:
		var surface_velocity := velocity.slide(_surface_normal)

		surface_velocity = surface_velocity.move_toward(
		Vector2.ZERO,
		surface_drag * delta
	)

		var normal_velocity := velocity.project(_surface_normal)

		velocity = normal_velocity + surface_velocity
	velocity = velocity.limit_length(max_speed)

	# 4) Optional jump, pushed away from whatever surface we're on.
	if can_jump and _touching_surface and Input.is_action_just_pressed("ui_accept"):
		velocity += _surface_normal * jump_speed
		body.stretch(jump_stretch_strength, _surface_normal)
		face.play_expression("surprised")

	var velocity_before := velocity
	move_and_slide()
	_read_collisions(velocity_before)
	_update_expression()
	_update_juice(delta)


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
	body.is_grounded = _touching_surface
	body.surface_normal = _surface_normal

	if hardest_impact > squash_min_speed and _cooldown_left <= 0.0:
		_cooldown_left = squash_cooldown
		var strength := clampf(hardest_impact * squash_strength_per_speed,
				squash_min_strength, squash_max_strength)
		body.squash(strength, impact_normal)
		_burst_splat(hardest_impact, impact_normal)


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


## Continuous "juice" while moving: the face leads the motion and droplets
## fly off the back of the slime.
func _update_juice(delta: float) -> void:
	var speed := velocity.length()

	if face_lead > 0.0:
		var lead := velocity.limit_length(700.0) / 700.0 * body.radius * face_lead
		face.position = face.position.lerp(_face_base_position + lead, 1.0 - exp(-12.0 * delta))

	if _trail != null:
		var sliding := trail_enabled and _touching_surface and speed > trail_min_speed
		_trail.emitting = sliding
		if sliding:
			_trail.position = -_surface_normal * body.radius * 0.85
			_trail.direction = -velocity.normalized() + _surface_normal * 0.6
			_trail.initial_velocity_min = speed * 0.05
			_trail.initial_velocity_max = speed * 0.18


func _burst_splat(impact_speed: float, normal: Vector2) -> void:
	if not splat_enabled or _splat == null:
		return
	_splat.position = -normal * body.radius * 0.9
	_splat.direction = normal
	_splat.amount = int(clampf(impact_speed / 40.0, 6.0, 24.0))
	_splat.restart()
	_splat.emitting = true


# ---------------------------------------------------------------- particles

func _setup_particles() -> void:
	var texture := _make_droplet_texture()
	_trail = _make_particles(texture, false)
	_trail.amount = 18
	_trail.lifetime = 0.45
	_trail.spread = 30.0
	_trail.gravity = Vector2(0.0, 700.0)

	_splat = _make_particles(texture, true)
	_splat.amount = 12
	_splat.lifetime = 0.5
	_splat.spread = 70.0
	_splat.initial_velocity_min = 120.0
	_splat.initial_velocity_max = 320.0
	_splat.gravity = Vector2(0.0, 900.0)


func _make_particles(texture: Texture2D, one_shot: bool) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.texture = texture
	particles.local_coords = false            # droplets stay behind in the world
	particles.show_behind_parent = true       # draw under the slime body
	particles.emitting = false
	particles.one_shot = one_shot
	particles.explosiveness = 0.9 if one_shot else 0.0
	particles.scale_amount_min = body.radius * 0.004
	particles.scale_amount_max = body.radius * 0.009
	particles.color = body.skin_color

	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	particles.color_ramp = fade

	add_child(particles)
	return particles


## Soft round dot generated in code so no extra image file is needed.
func _make_droplet_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 32
	texture.height = 32
	return texture


## Call from an enemy/hazard script to make the slime react physically and
## show a hurt expression, e.g.:  slime.take_hit(spike.global_position)
func take_hit(from_position: Vector2, strength: float = 200.0) -> void:
	var away_direction := (global_position - from_position).normalized()
	body.poke(away_direction, strength)
	face.play_expression("hurt")