extends AnimatedSprite2D
class_name SlimeFace
## Drives the slime's expression using a sprite-sheet-backed SpriteFrames
## resource. Assign a SpriteFrames resource on this node in the editor with
## animations named exactly:
##
##   idle       - default resting face
##   move       - eyes/mouth while walking or rolling
##   surprised  - played on jump takeoff
##   hurt       - played when take_hit() is called
##   blink      - a short 1-2 frame blink, looped back to whatever was playing
##
## Each animation can be 1 frame (a static expression) or several (its own
## mini sprite-sheet animation, e.g. a looping "move" wobble) - SpriteFrames
## handles both the same way.

@export var blink_interval_min: float = 2.0
@export var blink_interval_max: float = 5.0

var _current_expression: String = "idle"
var _blink_timer: Timer


func _ready() -> void:
	_blink_timer = Timer.new()
	_blink_timer.one_shot = true
	add_child(_blink_timer)
	_blink_timer.timeout.connect(_on_blink_timer_timeout)
	_queue_next_blink()

	if sprite_frames and sprite_frames.has_animation("idle"):
		play("idle")


## Switches expression if it isn't already playing. Safe to call every frame.
func play_expression(expression_name: String) -> void:
	if _current_expression == expression_name:
		return
	if sprite_frames and sprite_frames.has_animation(expression_name):
		_current_expression = expression_name
		play(expression_name)


## Plays a quick blink then returns to whatever expression was showing.
func blink_now() -> void:
	if sprite_frames == null or not sprite_frames.has_animation("blink"):
		return
	var previous := _current_expression
	play("blink")
	await get_tree().create_timer(0.15).timeout
	_current_expression = "idle" # force play_expression() to actually restore it
	play_expression(previous)


func flip(should_flip: bool) -> void:
	flip_h = should_flip


func _queue_next_blink() -> void:
	_blink_timer.start(randf_range(blink_interval_min, blink_interval_max))


func _on_blink_timer_timeout() -> void:
	blink_now()
	_queue_next_blink()
