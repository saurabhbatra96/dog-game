class_name Player
extends CharacterBody2D
## Platformer controller tuned for feel. Every number that shapes the movement
## is exported, so it can be changed in the Inspector while the game runs
## (Remote tab in the Scene dock, then select Player).

signal jumped
signal landed(impact: float)
signal respawned

@export_group("Run")
## Top running speed, pixels per second.
@export var max_speed := 260.0
@export var ground_accel := 2600.0
@export var ground_decel := 3200.0
## Extra-strong acceleration used while reversing direction on the ground.
@export var turn_accel := 4400.0
@export var air_accel := 1900.0
@export var air_decel := 700.0

@export_group("Jump")
## Height of a full jump, in pixels (one tile is 32).
@export var jump_height := 112.0
## Seconds from take-off to the top of a full jump.
@export var time_to_apex := 0.36
## Gravity multiplier while falling. Above 1 makes the fall snappier than the rise.
@export var fall_gravity_mult := 1.7
## Upward speed is multiplied by this when jump is released early.
@export var jump_cut_mult := 0.45
## Near the top of a jump (vertical speed below this) gravity is eased...
@export var apex_hang_speed := 60.0
## ...by this multiplier, while jump is held. Gives a little float at the peak.
@export var apex_hang_mult := 0.55
@export var max_fall_speed := 900.0

@export_group("Forgiveness")
## Seconds after walking off a ledge during which a jump still works.
@export var coyote_time := 0.1
## Seconds before landing during which a jump press is remembered.
@export var jump_buffer_time := 0.12
## Pixels the player is nudged sideways to slip past a ceiling corner.
@export var corner_correction := 6

var facing := 1
var input_x := 0.0
var control_enabled := true
## Last spot the player stood on solid ground; used for respawning.
var last_safe_position := Vector2.ZERO

var _coyote := 0.0
var _buffer := 0.0
var _rising_from_jump := false
var _was_on_floor := true
var _floor_time := 0.0


func gravity() -> float:
	return 2.0 * jump_height / (time_to_apex * time_to_apex)


func jump_speed() -> float:
	return 2.0 * jump_height / time_to_apex


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	input_x = Input.get_axis("move_left", "move_right") if control_enabled else 0.0
	if absf(input_x) > 0.2:
		facing = 1 if input_x > 0.0 else -1

	# Forgiveness timers.
	_coyote = coyote_time if on_floor else _coyote - delta
	if control_enabled and Input.is_action_just_pressed("jump"):
		_buffer = jump_buffer_time
	else:
		_buffer -= delta
	var jump_held := control_enabled and Input.is_action_pressed("jump")

	# Horizontal movement.
	var target := input_x * max_speed
	var rate := 0.0
	if on_floor:
		if absf(input_x) < 0.01:
			rate = ground_decel
		elif signf(target) != signf(velocity.x) and absf(velocity.x) > 10.0:
			rate = turn_accel
		else:
			rate = ground_accel
	else:
		rate = air_accel if absf(input_x) > 0.01 else air_decel
	velocity.x = move_toward(velocity.x, target, rate * delta)

	# Gravity, shaped by where we are in the jump.
	if not on_floor:
		var g := gravity()
		if velocity.y > 0.0:
			g *= fall_gravity_mult
		if jump_held and absf(velocity.y) < apex_hang_speed:
			g *= apex_hang_mult
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)

	# Jump.
	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = -jump_speed()
		_buffer = 0.0
		_coyote = 0.0
		_rising_from_jump = true
		jumped.emit()
	elif _rising_from_jump:
		if velocity.y >= 0.0:
			_rising_from_jump = false
		elif not jump_held:
			velocity.y *= jump_cut_mult
			_rising_from_jump = false

	_correct_corner(delta)
	var impact := velocity.y
	move_and_slide()

	on_floor = is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(impact)
	_floor_time = _floor_time + delta if on_floor else 0.0
	if _floor_time > 0.15:
		last_safe_position = global_position
	_was_on_floor = on_floor


## If the head is about to clip the corner of a block, slide sideways past it
## instead of losing the jump.
func _correct_corner(delta: float) -> void:
	if velocity.y >= 0.0 or corner_correction <= 0:
		return
	var motion := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, motion):
		return
	for i in range(1, corner_correction + 1):
		for dir: float in [-1.0, 1.0]:
			var offset := Vector2(i * dir, 0.0)
			if not test_move(global_transform, offset) and not test_move(global_transform.translated(offset), motion):
				global_position += offset
				return


func teleport(to: Vector2) -> void:
	global_position = to
	velocity = Vector2.ZERO
	last_safe_position = to
	_rising_from_jump = false
	_was_on_floor = true
	_floor_time = 0.0
	reset_physics_interpolation()
	respawned.emit()
