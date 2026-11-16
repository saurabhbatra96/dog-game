class_name Player
extends CharacterBody2D
## Platformer controller tuned for feel. Every number that shapes the movement
## is exported, so it can be changed in the Inspector while the game runs
## (Remote tab in the Scene dock, then select Player).

signal jumped
signal landed(impact: float)
signal respawned
signal attacked
signal hurt
signal died

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

@export_group("Combat")
@export var max_health := 5
## Seconds between swings.
@export var attack_cooldown := 0.32
## How far in front a swing reaches, in pixels.
@export var attack_reach := 42.0
## A downward slash that connects bounces you up by this share of a full jump.
@export var pogo_bounce := 0.8
@export var dash_speed := 620.0
@export var dash_time := 0.15
@export var dash_cooldown := 0.55
## Seconds of safety after being hit.
@export var hurt_safety := 1.0

var facing := 1
var input_x := 0.0
var control_enabled := true
## Last spot the player stood on solid ground; used for respawning.
var last_safe_position := Vector2.ZERO

var health := 5
## Counts down while a swing is on screen.
var attack_time := 0.0
## Which way the current swing points: sideways, up, or down.
var attack_dir := Vector2.RIGHT
## Counts down while dashing.
var dashing := 0.0
## Counts down while the player cannot be hurt again.
var invulnerable := 0.0
## Counts down while kneeling to pet the dog.
var petting := 0.0
## Set by the dog while it tows the player along by the tie.
var dragged := false
var drag_target_x := 0.0
## Whoever has the other end of the tie.
var tie_holder: Node2D
## Treats in the pouch, for feeding and training the dog.
var treats := 0

var _coyote := 0.0
var _buffer := 0.0
var _rising_from_jump := false
var _was_on_floor := true
var _floor_time := 0.0
var _attack_cd := 0.0
var _stun := 0.0
var _dash_cd := 0.0
var _air_dash_used := false


func _ready() -> void:
	add_to_group("player")
	health = max_health


func gravity() -> float:
	return 2.0 * jump_height / (time_to_apex * time_to_apex)


func jump_speed() -> float:
	return 2.0 * jump_height / time_to_apex


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	attack_time = maxf(attack_time - delta, 0.0)
	invulnerable = maxf(invulnerable - delta, 0.0)
	petting = maxf(petting - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_stun = maxf(_stun - delta, 0.0)
	_dash_cd = maxf(_dash_cd - delta, 0.0)

	var can_act := control_enabled and _stun <= 0.0
	input_x = Input.get_axis("move_left", "move_right") if can_act else 0.0
	var jump_pressed := can_act and Input.is_action_just_pressed("jump")
	# Any deliberate input shakes the dog off the tie.
	if dragged and (absf(input_x) > 0.2 or jump_pressed or not on_floor):
		dragged = false
	if absf(input_x) > 0.2:
		facing = 1 if input_x > 0.0 else -1
		petting = 0.0

	# Forgiveness timers.
	_coyote = coyote_time if on_floor else _coyote - delta
	if jump_pressed:
		_buffer = jump_buffer_time
	else:
		_buffer -= delta
	var jump_held := can_act and Input.is_action_pressed("jump")

	# Horizontal movement.
	var target := input_x * max_speed
	var rate := 0.0
	if dragged:
		target = clampf((drag_target_x - global_position.x) * 8.0, -max_speed, max_speed)
		if absf(target) > 10.0:
			facing = 1 if target > 0.0 else -1
		rate = ground_accel
	elif on_floor:
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

	# Dash: a short burst straight ahead, once per jump.
	if on_floor:
		_air_dash_used = false
	if can_act and _dash_cd <= 0.0 and not _air_dash_used and Input.is_action_just_pressed("dash"):
		dashing = dash_time
		_dash_cd = dash_cooldown
		_air_dash_used = not on_floor
		_rising_from_jump = false
		dragged = false
		petting = 0.0
	if dashing > 0.0:
		dashing -= delta
		velocity = Vector2(facing * dash_speed, 0.0)

	if can_act and _attack_cd <= 0.0 and Input.is_action_just_pressed("attack"):
		_attack()

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


## Swing sideways, or upward while holding up, or downward in the air while
## holding down. A downward hit bounces you off the enemy.
func _attack() -> void:
	attack_time = 0.16
	_attack_cd = attack_cooldown
	petting = 0.0
	dragged = false
	attack_dir = Vector2(facing, 0.0)
	if Input.is_action_pressed("aim_up"):
		attack_dir = Vector2.UP
	elif Input.is_action_pressed("aim_down") and not is_on_floor():
		attack_dir = Vector2.DOWN
	var connected := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		# Centre of the enemy relative to the centre of the player.
		var d := enemy.global_position + Vector2(0.0, -9.0) - (global_position + Vector2(0.0, -24.0))
		var hit := false
		if attack_dir.x != 0.0:
			hit = d.x * facing > -10.0 and d.x * facing < attack_reach and absf(d.y) < 34.0
		elif attack_dir.y < 0.0:
			hit = absf(d.x) < 24.0 and d.y < 0.0 and d.y > -attack_reach - 30.0
		else:
			hit = absf(d.x) < 26.0 and d.y > 0.0 and d.y < attack_reach + 24.0
		if hit:
			enemy.take_hit(1, facing)
			connected = true
	if connected:
		if attack_dir.y > 0.0:
			velocity.y = -jump_speed() * pogo_bounce
			_rising_from_jump = false
			_air_dash_used = false
		elif attack_dir.x != 0.0:
			velocity.x -= facing * 130.0
		_hit_stop()
	attacked.emit()


## Freeze the world for a few frames so a hit lands with weight.
func _hit_stop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.06, true, false, true).timeout
	Engine.time_scale = 1.0


func take_hit(damage: int, from_x: float) -> void:
	if invulnerable > 0.0 or health <= 0:
		return
	health -= damage
	invulnerable = hurt_safety
	_stun = 0.22
	dragged = false
	petting = 0.0
	var away := 1.0 if global_position.x >= from_x else -1.0
	velocity = Vector2(away * 230.0, -260.0)
	hurt.emit()
	if health <= 0:
		died.emit()


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
	dragged = false
	petting = 0.0
	reset_physics_interpolation()
	respawned.emit()
