class_name Enemy
extends CharacterBody2D
## A bramble: a thorny forest creature. It paces near home, chases the
## player on sight, then winds up and charges. It is harmless while it
## catches its breath after a charge and while the dog has its attention.
## Nothing can hurt it: the only way past is to have the dog hold its eye.

signal was_hit(critical: bool)

enum State { PATROL, CHASE, WINDUP, DASH, REST, DISTRACTED, STUN, DEAD }

@export var max_hp := 3
@export var patrol_speed := 40.0
@export var chase_speed := 115.0
@export var dash_speed := 300.0
## How far away it notices the player.
@export var sight := 170.0
## It starts winding up a charge once the player is this close.
@export var charge_range := 92.0
@export var windup_time := 0.42
@export var dash_time := 0.42
@export var rest_time := 0.8
@export var gravity := 1900.0
## It will not chase further than this from where it started.
@export var leash := 440.0
## How far it paces either side of home when it has nothing to chase. 0 stands still.
@export var patrol_range := 96.0
## How fast it shuffles toward a sitting dog, and how close it stops.
@export var creep_speed := 70.0
@export var stare_distance := 96.0

var player: Player
var state: State = State.PATROL
var state_time := 0.0
var facing := -1
var hp := 3
## Seconds of white flash left after being hit.
var flash := 0.0

var _distractor: Node2D
var _distract_len := 0.0
var _immune := 0.0
var _lost := 0.0
var _home_x := 0.0


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1
	hp = max_hp
	_home_x = position.x
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24.0, 18.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0.0, -9.0)
	add_child(collider)
	add_child(EnemyVisual.new())


func is_dead() -> bool:
	return state == State.DEAD


func is_distracted() -> bool:
	return state == State.DISTRACTED


## True while it is actively after the player and can be distracted.
func is_hunting() -> bool:
	return _immune <= 0.0 and (state == State.CHASE or state == State.WINDUP or state == State.DASH or state == State.REST)


func distract(by: Node2D, seconds: float) -> void:
	if state == State.DEAD:
		return
	_distractor = by
	_distract_len = seconds
	_go(State.DISTRACTED)


## Returns true if the hit was critical.
func take_hit(damage: int, dir: int) -> bool:
	if state == State.DEAD:
		return false
	# Looking the other way at the dog: struck from behind.
	var critical := state == State.DISTRACTED and facing == dir
	hp -= damage * (2 if critical else 1)
	flash = 0.16
	velocity = Vector2(dir * (230.0 if critical else 170.0), -160.0)
	if hp <= 0:
		collision_mask = 0
		_go(State.DEAD)
	else:
		_go(State.STUN)
	was_hit.emit(critical)
	return critical


func _go(next: State) -> void:
	state = next
	state_time = 0.0


func _physics_process(delta: float) -> void:
	state_time += delta
	flash = maxf(flash - delta, 0.0)
	_immune = maxf(_immune - delta, 0.0)
	if state == State.DEAD:
		velocity.y += gravity * delta
		global_position += velocity * delta
		if state_time > 0.45:
			visible = false
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
		if player == null:
			return

	var to_player := player.global_position - global_position
	var sees := absf(to_player.x) < sight and absf(to_player.y) < 56.0
	match state:
		State.PATROL:
			var off := global_position.x - _home_x
			if patrol_range <= 0.0:
				# No beat to walk: just go home and doze.
				velocity.x = 0.0 if absf(off) < 3.0 else -signf(off) * patrol_speed
				if absf(off) >= 3.0:
					facing = -1 if off > 0.0 else 1
			else:
				if is_on_wall() or not _floor_ahead(facing) or off * facing > patrol_range:
					facing = -facing
				velocity.x = facing * patrol_speed
			if sees:
				_go(State.CHASE)
		State.CHASE:
			if absf(to_player.x) > 6.0:
				facing = 1 if to_player.x > 0.0 else -1
			var want := facing * chase_speed if _floor_ahead(facing) else 0.0
			velocity.x = move_toward(velocity.x, want, 700.0 * delta)
			if absf(to_player.x) < charge_range and absf(to_player.y) < 40.0:
				_go(State.WINDUP)
			# Once it has your scent it keeps coming from much further away.
			var in_range := absf(to_player.x) < sight * 2.5 and absf(to_player.y) < 56.0
			_lost = 0.0 if in_range else _lost + delta
			if _lost > 1.5:
				_go(State.PATROL)
		State.WINDUP:
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			if state_time > windup_time:
				_go(State.DASH)
		State.DASH:
			velocity.x = facing * dash_speed if _floor_ahead(facing) else 0.0
			if state_time > dash_time or is_on_wall():
				_go(State.REST)
		State.REST:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			if state_time > rest_time:
				_go(State.CHASE)
		State.DISTRACTED:
			# Drawn to the sitting dog: it shuffles up, stops short, and stares.
			var want := 0.0
			if is_instance_valid(_distractor):
				var dx := _distractor.global_position.x - global_position.x
				if absf(dx) > 4.0:
					facing = 1 if dx > 0.0 else -1
				var spot := _distractor.global_position.x - (stare_distance if dx > 0.0 else -stare_distance)
				var to_spot := spot - global_position.x
				if absf(to_spot) > 2.0 and _floor_ahead(1 if to_spot > 0.0 else -1):
					want = clampf(to_spot * 6.0, -creep_speed, creep_speed)
			velocity.x = move_toward(velocity.x, want, 900.0 * delta)
			if state_time > _distract_len:
				_go(State.PATROL)
		State.STUN:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
			if state_time > 0.38:
				_go(State.CHASE)

	# At the end of its leash it will not take another step outward.
	var strayed := global_position.x - _home_x
	if absf(strayed) > leash and signf(velocity.x) == signf(strayed):
		velocity.x = 0.0
		if state == State.CHASE or state == State.DASH:
			_go(State.REST)
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 900.0)
	move_and_slide()

	# Touching it hurts while it is on the attack.
	var dangerous := state == State.CHASE or state == State.WINDUP or state == State.DASH
	to_player = player.global_position - global_position
	if dangerous and absf(to_player.x) < 20.0 and to_player.y > -16.0 and to_player.y < 40.0:
		player.take_hit(1, global_position.x)


func _floor_ahead(dir: int) -> bool:
	var from := global_position + Vector2(dir * (16.0 + absf(velocity.x) * 0.06), -4.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 18.0), 1)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()
