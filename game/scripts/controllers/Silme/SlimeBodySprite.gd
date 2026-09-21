extends AnimatedSprite2D
class_name SlimeBodySprite
## Drop-in alternative to SoftBodySlime.gd: the slime's whole body is drawn
## from a sprite sheet instead of simulated as a spring-mass mesh.
##
## Assign a SpriteFrames resource on this node with animations named:
##   idle  - resting loop
##   move  - walking/rolling loop
##   jump  - played once on takeoff (a stretched pose, or a few frames)
##   land  - played once on a hard landing (a squashed pose)
##   hurt  - played once on take_hit()
##
## If an animation isn't defined yet, this script fakes the effect with a
## quick scale "punch" instead, so you can add art incrementally.
##
## To use this instead of the physics body: select the Body node in the
## editor, change its type to AnimatedSprite2D, attach this script instead
## of SoftBodySlime.gd, then in SlimeController.gd change
##   @onready var body: SoftBodySlime = $Body
## to
##   @onready var body: SlimeBodySprite = $Body

@export var punch_scale_squash: Vector2 = Vector2(1.25, 0.75)
@export var punch_scale_stretch: Vector2 = Vector2(0.8, 1.3)
@export var punch_recover_time: float = 0.22

var _base_scale: Vector2
var _current_state: String = "idle"
var _tween: Tween


func _ready() -> void:
	_base_scale = scale
	if sprite_frames and sprite_frames.has_animation("idle"):
		play("idle")


## Call with "idle" / "move" from SlimeController to drive looping poses.
func play_state(state_name: String) -> void:
	if _current_state == state_name:
		return
	if sprite_frames and sprite_frames.has_animation(state_name):
		_current_state = state_name
		play(state_name)


## Matches SoftBodySlime.squash(strength) - plays a "land" pose if you have
## one, otherwise fakes it with a quick scale punch.
func squash(strength: float) -> void:
	if sprite_frames and sprite_frames.has_animation("land"):
		play("land")
	else:
		_punch(punch_scale_squash, strength)


## Matches SoftBodySlime.stretch(strength) - plays a "jump" pose if you have
## one, otherwise fakes it with a quick scale punch.
func stretch(strength: float) -> void:
	if sprite_frames and sprite_frames.has_animation("jump"):
		play("jump")
	else:
		_punch(punch_scale_stretch, strength)


## Matches SoftBodySlime.poke(direction, strength) - a generic knock reaction.
func poke(_direction: Vector2, strength: float) -> void:
	if sprite_frames and sprite_frames.has_animation("hurt"):
		play("hurt")
	else:
		_punch(punch_scale_squash, strength)


func flip(should_flip: bool) -> void:
	flip_h = should_flip


func _punch(target_scale: Vector2, strength: float) -> void:
	if _tween:
		_tween.kill()
	var blend_amount := clampf(strength / 10.0, 0.2, 1.0)
	scale = _base_scale.lerp(target_scale, blend_amount)
	_tween = create_tween()
	_tween.tween_property(self, "scale", _base_scale, punch_recover_time) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
