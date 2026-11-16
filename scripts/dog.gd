class_name Dog
extends CharacterBody2D
## Companion dog. It has its own physics body and decides what to do on
## every physics tick:
##   1. If it can simply walk to the player, it is "free": it follows, leads,
##      idles, wanders, investigates or cowers depending on mood.
##   2. If it cannot, it replays the jumps and drops the player made ("links")
##      with leaps of its own.
##   3. If that fails, it bounds straight to the player in a blur ("rescue").

signal hopped
signal landed(impact: float)
signal perked

enum Mood { CALM, CURIOUS, EXCITED, WARY }
enum Act { STAND, FOLLOW, LEAD, SIT, LIE, WANDER, SNIFF, INVESTIGATE, COWER, COME, WAIT, LEAP, RESCUE, DISTRACT, PETTED, DRAG, FETCH, EAT, CHASE }
## How long a stay holds at each skill level, in seconds.
const STAY_SECONDS: Array[float] = [3.0, 8.0, INF]
## How far away a plate or mat can be for the dog to settle on it, per level.
const STAY_SEEK: Array[float] = [110.0, 220.0, 360.0]
## How far away a key can be, measured from the dog, per fetch level.
const FETCH_REACH: Array[float] = [320.0, 640.0, 1200.0]
const MAX_PIPS := 5
## A bramble this close to a sitting dog is drawn to it.
const BRAMBLE_PULL := 240.0
## The ways it can react to being petted.
enum { PET_LEAN, PET_ROLL, PET_SPIN, PET_LICK }

## One airborne stretch of the player's path: where they left the ground,
## where they landed, and how high they got in between.
class Link:
	var from: Vector2
	var to: Vector2
	var apex: float

const WORLD_MASK := 1
const HALF_WIDTH := 10.5

@export_group("Movement")
@export var max_speed := 350.0
@export var walk_speed := 95.0
@export var accel := 2600.0
@export var decel := 3200.0
@export var gravity := 1900.0
@export var max_fall_speed := 900.0
## Extra height the dog clears above the player's own jump arc.
@export var leap_clearance := 14.0
@export var leap_max_speed := 460.0

@export_group("Following")
## The dog stops approaching once it is this close.
@export var follow_near := 44.0
## The dog starts following once the player is this far away.
@export var follow_far := 80.0
## How eagerly it closes the gap. Higher keeps it tighter to the player.
@export var follow_gain := 5.0
## How far ahead it runs when it decides to lead.
@export var lead_distance := 84.0
## Seconds of steady running before it may decide to lead.
@export var lead_after := 1.4
## Beyond this distance it gives up on walking and bounds straight to the player.
@export var rescue_distance := 720.0

@export_group("Distraction")
## The dog decides for itself when to distract an enemy. After each attempt it
## waits a random time between these two values, in seconds, before the next.
@export var distract_wait_min := 6.0
@export var distract_wait_max := 11.0
## How long an enemy stays distracted, in seconds (also randomised a little).
@export var distract_seconds := 3.2
## Seconds the player must dawdle near the flag before being towed to it.
@export var drag_after := 3.0

@export_group("Personality")
## Seconds the player must stand still before the dog sits.
@export var sit_after := 0.9
## How far from the player it will wander to sniff around.
@export var wander_radius := 150.0
## Seconds of stillness before a calm dog lies down.
@export var lie_after := 14.0

var player: Player
var facing := 1
var act: Act = Act.STAND
var mood: Mood = Mood.CALM
## Set to a Mood value to override the automatic mood, or -1 for automatic.
var forced_mood := -1
## 0..1, rises while the player runs and jumps, falls while they stand still.
var energy := 0.2
## World-space point the dog is looking at. The visual turns head and eyes to it.
var look_point := Vector2.ZERO
## Current thought bubble: "", "!", "?", "...", "z" or "heart".
var emote := ""
var kill_y := 1.0e9
var rescue_count := 0
## True while it waits at a ledge for the player to land, ready to jump after them.
var braced := false
## Hunger, from 0 (full) to MAX_PIPS (too hungry to take orders). Stay and
## fetch each cost one pip; eating takes three off.
var pips := 1
## Level of each trick, 1 to 3. A biscuit given just after a trick raises it.
var skills := {"stay": 1, "fetch": 1}
## Whether orders make it hungry. On in puzzle rooms only.
var hunger_enabled := false
## Whether it wanders off to sniff about when left idle.
var wander_enabled := true

var _last_skill := ""
var _last_skill_age := 99.0
var _fetching: Item = null
var _fetch_home := false
var _lure: Lure = null
var _chasing: Squirrel = null
var _chase_x := 0.0
var _chase_over := false
## Seconds of the current stay left, and how long it started with.
var stay_left := 0.0
var stay_total := 0.0
var _eat_time := 0.0
## True while it has been told to stay put. Calling it releases it.
var staying := false
## Whether it may bound straight to the player when it cannot find a way.
var rescue_enabled := true
## Whether it may run off to distract a bramble on its own initiative.
var auto_distract := true
var _stay_x := 0.0
## Counts down while a bark is showing.
var bark_time := 0.0
## Which petting reaction is playing (PET_LEAN, PET_ROLL, PET_SPIN, PET_LICK).
var pet_style := PET_LEAN

var _enemy: Enemy = null
var _barked := false
var _bark_timer := 0.0
var _distract_cd := 3.0
var _dragging := false
var _grabbed := false
var _drag_goal_x := 0.0
var _drag_dir := 1.0
var _drag_block := 0.0
var _spin_timer := 0.0

var _act_time := 0.0
var _act_len := 0.0
var _emote_time := 0.0

# Player tracking.
var _links: Array[Link] = []
var _pending: Link = null
var _player_on_floor := true
var _player_floor_pos := Vector2.ZERO
var _direct := true
var _direct_timer := 0.0
var _still_time := 0.0
var _run_dir := 0.0
var _run_time := 0.0
var _lead := false
var _lead_rolled := false

# Trail and leap.
var _trail_time := 0.0
var _trail_last_dx := 0.0
var _leap_time := 0.0
var _leap_duration := 0.0
var _leap_to := Vector2.ZERO

# Rescue.
var _wait_time := 0.0
var _far_time := 0.0
var _rescue_t := 0.0
var _rescue_len := 0.5
var _rescue_from := Vector2.ZERO

# Idle and interest.
var _called := 0.0
var _wander_x := 0.0
var _wander_home := false
var _sniffs := 0
var _next_z := 0.0
var _poi: Poi = null
var _poi_phase := 0
var _poi_phase_time := 0.0
var _poi_cooldown := 0.0
var _scary: Poi = null
var _scan_timer := 0.0
var _glance := 0.0
var _glance_point := Vector2.ZERO
var _next_glance := 2.0


func _ready() -> void:
	add_to_group("dog")
	look_point = global_position + Vector2(40.0, -20.0)


# --- public -----------------------------------------------------------------

func reset(to: Vector2) -> void:
	global_position = to
	velocity = Vector2.ZERO
	collision_mask = WORLD_MASK
	_links.clear()
	_pending = null
	_player_on_floor = true
	_direct = true
	_direct_timer = 0.0
	_trail_time = 0.0
	_wait_time = 0.0
	_far_time = 0.0
	_called = 0.0
	staying = false
	_fetching = null
	_lure = null
	_chasing = null
	_enemy = null
	_barked = false
	_distract_cd = randf_range(2.0, 4.0)
	_dragging = false
	_drag_block = 0.0
	player.dragged = false
	_poi = null
	_scary = null
	_poi_cooldown = 1.0
	_lead = false
	_run_time = 0.0
	energy = 0.2
	emote = ""
	_set_act(Act.STAND)
	reset_physics_interpolation()


## Call when the player is moved by something other than their own feet.
func forget_trail() -> void:
	_links.clear()
	_pending = null
	_player_on_floor = true
	_direct_timer = 0.0


func call_dog() -> void:
	if act == Act.RESCUE or _lure != null:
		return
	staying = false
	if _fetching != null and not _fetch_home:
		_fetching = null
	_called = 3.0
	_drop_poi(3.0)
	say("!", 0.7)
	perked.emit()


## Returns true if the dog was close enough to be petted. Each time it picks
## a different reaction: leaning in, rolling over, spinning, or jumping up.
func pet() -> bool:
	if act == Act.RESCUE or act == Act.LEAP or not is_on_floor() or _dragging or _enemy != null:
		return false
	if global_position.distance_to(player.global_position) > 64.0:
		return false
	pet_style = (pet_style + 1 + randi() % 3) % 4
	say("heart", 1.8)
	energy = minf(energy + 0.25, 1.0)
	_drop_poi(3.0)
	_set_act(Act.PETTED)
	_act_time = 0.0
	_act_len = 2.2
	return true


func can_drag() -> bool:
	return not staying and _drag_block <= 0.0 and not _dragging and _enemy == null and _links.is_empty() and _direct \
			and is_on_floor() and act != Act.LEAP and act != Act.RESCUE and act != Act.PETTED


## Fetch the player and tow them to goal_x by the tie.
func start_drag(goal_x: float) -> void:
	_dragging = true
	_grabbed = false
	_drag_goal_x = goal_x
	_drag_dir = 1.0 if goal_x >= player.global_position.x else -1.0
	_drop_poi(4.0)
	_set_act(Act.DRAG)
	_act_time = 0.0
	say("!", 0.7)
	perked.emit()


## Tell the dog to stay, or release it. Told to stay near a plate or a mat,
## it settles there. Each stay costs a pip of hunger.
func toggle_stay() -> void:
	if staying:
		staying = false
		say("!", 0.6)
		perked.emit()
		return
	if act == Act.RESCUE or act == Act.LEAP or _dragging or not is_on_floor() or _lure != null or _chasing != null:
		return
	if _refuses():
		return
	if _fetching != null:
		_fetching.carried_by = null
		_fetching = null
	staying = true
	_chase_over = false
	_used_skill("stay")
	var level := skill_level("stay")
	var seek := STAY_SEEK[level - 1]
	stay_total = STAY_SECONDS[level - 1]
	stay_left = stay_total
	_stay_x = global_position.x
	# Settle on the nearest seat within range that it can walk to.
	for node in get_tree().get_nodes_in_group("seats"):
		var seat := node as Node2D
		if seat is Plate and (seat as Plate).heavy:
			continue
		var d := seat.global_position - global_position
		if absf(d.x) < seek and absf(d.y) < 10.0 and _walkable(global_position, seat.global_position):
			_stay_x = seat.global_position.x
			seek = absf(d.x)
	_enemy = null
	_drop_poi(3.0)
	_set_act(Act.FOLLOW)
	_act_time = 0.0
	say("...", 0.9)


func skill_level(skill: String) -> int:
	return clampi(int(skills.get(skill, 1)), 1, 3)


## How much of a smell's reach still gets through: a dog under orders
## resists twice as well as a dog at a loose end.
func lure_resistance() -> float:
	return 0.5 if staying else 1.0


## Too hungry to listen?
func _refuses() -> bool:
	if hunger_enabled and pips >= MAX_PIPS:
		say("...", 1.2)
		bark_time = 0.3
		return true
	return false


func _used_skill(skill: String) -> void:
	_last_skill = skill
	_last_skill_age = 0.0
	if hunger_enabled:
		pips = mini(pips + 1, MAX_PIPS)


## Give the dog a biscuit. Within a few seconds of a trick, it teaches that
## trick: one biscuit, one level.
func feed() -> void:
	if _last_skill != "" and _last_skill_age < 5.0 and skill_level(_last_skill) < 3:
		skills[_last_skill] = skill_level(_last_skill) + 1
		if _last_skill == "stay" and staying:
			stay_total = STAY_SECONDS[skill_level("stay") - 1]
			stay_left = stay_total
		_last_skill = ""
		say("!", 1.4)
	else:
		say("heart", 1.2)
	hopped.emit()


## Send the dog for the nearest key it can walk to. The range is measured
## from the dog, not from the player. Each fetch costs a pip of hunger.
func fetch() -> void:
	if act == Act.RESCUE or act == Act.LEAP or _dragging or _lure != null or _chasing != null or not is_on_floor():
		return
	var reach := FETCH_REACH[skill_level("fetch") - 1]
	var best: Item = null
	for node in get_tree().get_nodes_in_group("items"):
		var item := node as Item
		var d := item.global_position.distance_to(global_position)
		if item.carried_by == null and d < reach and _walkable(global_position, Vector2(item.global_position.x, global_position.y)) \
				and absf(item.global_position.y - global_position.y) < 10.0:
			best = item
			reach = d
	if best == null:
		say("?", 0.9)
		return
	if _refuses():
		return
	staying = false
	_chase_over = false
	_used_skill("fetch")
	_fetching = best
	_fetch_home = false
	_drop_poi(4.0)
	_set_act(Act.FETCH)
	_act_time = 0.0
	say("!", 0.5)


func is_walkable(from: Vector2, to: Vector2) -> bool:
	return _walkable(from, to)


func say(text: String, seconds: float) -> void:
	emote = text
	_emote_time = seconds


func is_sniffing() -> bool:
	return act == Act.SNIFF or (act == Act.INVESTIGATE and _poi_phase == 2)


func link_count() -> int:
	return _links.size()


func rescue_progress() -> float:
	return _rescue_t


# --- main loop --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if player == null:
		return
	_act_time += delta
	_called = maxf(_called - delta, 0.0)
	_distract_cd = maxf(_distract_cd - delta, 0.0)
	_drag_block = maxf(_drag_block - delta, 0.0)
	bark_time = maxf(bark_time - delta, 0.0)
	_last_skill_age += delta
	_poi_cooldown = maxf(_poi_cooldown - delta, 0.0)
	if _emote_time > 0.0:
		_emote_time -= delta
		if _emote_time <= 0.0:
			emote = ""

	_track_player(delta)
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.2
		_scan_pois()
	_check_food()
	_update_mood(delta)

	if act == Act.RESCUE:
		_rescue_step(delta)
	elif act == Act.LEAP:
		_leap_step(delta)
	elif _should_rescue(delta):
		_start_rescue()
	else:
		var was_on_floor := is_on_floor()
		if not _links.is_empty():
			_trail_step(delta)
		else:
			_free_step(delta)
		if not is_on_floor():
			velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		var impact := velocity.y
		move_and_slide()
		if is_on_floor() and not was_on_floor:
			landed.emit(impact)

	_update_facing()
	_update_look(delta)


# --- watching the player ----------------------------------------------------

func _track_player(delta: float) -> void:
	var on_floor := player.is_on_floor()
	if on_floor:
		if not _player_on_floor and _pending != null:
			_pending.to = player.global_position
			# A hop that lands on the same stretch of floor is not worth replaying.
			if not _walkable(_pending.from, _pending.to) \
					and (not _links.is_empty() or act == Act.LEAP or _walkable(global_position, _pending.from)):
				_links.append(_pending)
			_pending = null
			_direct_timer = 0.0
		_player_floor_pos = player.global_position
	else:
		if _player_on_floor:
			_pending = Link.new()
			_pending.from = _player_floor_pos
			_pending.apex = _player_floor_pos.y
		if _pending != null:
			_pending.apex = minf(_pending.apex, player.global_position.y)
	_player_on_floor = on_floor

	# While it has something of its own to do, it is not following anyone.
	if staying or _lure != null or _chasing != null or _fetching != null or _chase_over:
		_links.clear()
		_pending = null

	# Can the dog simply walk to the player? If so, recorded links are moot.
	_direct_timer -= delta
	if _direct_timer <= 0.0 and is_on_floor() and act != Act.LEAP and act != Act.RESCUE:
		if on_floor:
			_direct_timer = 0.1
			_direct = _walkable(global_position, player.global_position)
			if _direct:
				_links.clear()
		elif _pending != null and _links.is_empty():
			# Player is mid-jump: if the dog can reach where they took off, it
			# should run there and get ready rather than stand and wait.
			_direct_timer = 0.1
			_direct = _walkable(global_position, _pending.from)

	# How the player has been moving lately.
	var moving := absf(player.velocity.x) > 40.0 or not on_floor
	_still_time = 0.0 if moving else _still_time + delta
	var dir := 0.0
	if absf(player.velocity.x) > player.max_speed * 0.6:
		dir = signf(player.velocity.x)
	if dir != 0.0 and dir == _run_dir:
		_run_time += delta
		if _run_time > lead_after and not _lead_rolled:
			_lead_rolled = true
			_lead = randf() < _lead_chance()
	else:
		_run_dir = dir
		_run_time = 0.0
		_lead = false
		_lead_rolled = false


## True if a ground-bound dog could walk from a to b: same height, floor all
## the way, no wall in between. Both points are feet positions.
func _walkable(a: Vector2, b: Vector2) -> bool:
	if absf(a.y - b.y) > 6.0 or absf(a.x - b.x) > 2400.0:
		return false
	var space := get_world_2d().direct_space_state
	var wall := PhysicsRayQueryParameters2D.create(a + Vector2(0.0, -10.0), b + Vector2(0.0, -10.0), WORLD_MASK)
	if not space.intersect_ray(wall).is_empty():
		return false
	# Skip a margin at both ends: a body may overhang a ledge by a few pixels.
	var left := minf(a.x, b.x) + 12.0
	var right := maxf(a.x, b.x) - 12.0
	var x := left
	while x <= right:
		var down := PhysicsRayQueryParameters2D.create(Vector2(x, a.y - 6.0), Vector2(x, a.y + 10.0), WORLD_MASK)
		if space.intersect_ray(down).is_empty():
			return false
		x += 14.0
	return true


func _floor_ahead(dir: float) -> bool:
	var reach := HALF_WIDTH + 6.0 + absf(velocity.x) * 0.08
	var from := global_position + Vector2(dir * reach, -4.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 18.0), WORLD_MASK)
	return not get_world_2d().direct_space_state.intersect_ray(query).is_empty()


# --- mood and interest ------------------------------------------------------

func _scan_pois() -> void:
	_scary = null
	var scary_dist := INF
	var best: Poi = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("poi"):
		var poi := node as Poi
		if poi == null or poi.is_queued_for_deletion():
			continue
		var d := poi.global_position.distance_to(global_position)
		if d > poi.radius:
			continue
		if poi.kind == Poi.Kind.SCARY:
			if d < scary_dist:
				_scary = poi
				scary_dist = d
		elif not poi.seen and d < best_dist:
			best = poi
			best_dist = d
	# A bolting squirrel beats any order short of a perfect stay.
	if _chasing == null and is_on_floor() and act != Act.LEAP and act != Act.RESCUE \
			and not (staying and skill_level("stay") >= 3):
		for node in get_tree().get_nodes_in_group("squirrels"):
			var squirrel := node as Squirrel
			if squirrel.running and not squirrel.gone and squirrel.global_position.distance_to(global_position) < 420.0:
				_chasing = squirrel
				_chase_x = squirrel.global_position.x
				_chase_over = false
				staying = false
				_enemy = null
				if _fetching != null:
					_fetching.carried_by = null
					_fetching = null
				_set_act(Act.CHASE)
				say("!", 0.6)
				break
	var busy := act == Act.LEAP or act == Act.RESCUE or not _links.is_empty() or _called > 0.0 or _lure != null or _fetching != null or _chasing != null \
			or _enemy != null or _dragging or act == Act.PETTED or staying

	# Pick a fight to meddle in. The timing is the dog's own: a random wait
	# after each attempt, which the player cannot hurry.
	if auto_distract and _distract_cd <= 0.0 and not busy and is_on_floor():
		var nearest := 300.0
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy := node as Enemy
			if enemy == null or not enemy.is_hunting():
				continue
			var d := enemy.global_position.distance_to(global_position)
			if d < nearest and absf(enemy.global_position.y - global_position.y) < 70.0:
				nearest = d
				_enemy = enemy
		if _enemy != null:
			_barked = false
			_drop_poi(3.0)
			_set_act(Act.DISTRACT)
			_act_time = 0.0
			busy = true
	if best != null and _poi == null and _poi_cooldown <= 0.0 and not busy and _scary == null:
		_poi = best
		_poi_phase = 0
		_set_act(Act.INVESTIGATE)
		_act_time = 0.0
		say("?", 1.0)
		perked.emit()


## A smell within reach beats any order.
func _check_food() -> void:
	if _lure != null or not is_on_floor() or act == Act.LEAP or act == Act.RESCUE:
		return
	for node in get_tree().get_nodes_in_group("lures"):
		var lure := node as Lure
		if absf(lure.global_position.x - global_position.x) < lure.reach_for(self) and _can_reach_food(lure):
			_lure = lure
			staying = false
			_enemy = null
			_chase_over = false
			if _fetching != null:
				_fetching.carried_by = null
				_fetching = null
			_set_act(Act.EAT)
			_act_time = 0.0
			say("!", 0.6)
			return


## Food counts only if the dog could get to it: nothing solid between them
## at its own height, and if the food is lower, a clear drop down to it.
func _can_reach_food(lure: Lure) -> bool:
	var here := global_position
	var there := lure.global_position
	if there.y < here.y - 12.0:
		return false
	var space := get_world_2d().direct_space_state
	var across := PhysicsRayQueryParameters2D.create(here + Vector2(0.0, -8.0), Vector2(there.x, here.y - 8.0), WORLD_MASK)
	if not space.intersect_ray(across).is_empty():
		return false
	if there.y > here.y + 12.0:
		var down := PhysicsRayQueryParameters2D.create(Vector2(there.x, here.y - 8.0), there + Vector2(0.0, -8.0), WORLD_MASK)
		if not space.intersect_ray(down).is_empty():
			return false
	return true


func _drop_poi(cooldown: float) -> void:
	_poi = null
	_poi_phase = 0
	_poi_cooldown = maxf(_poi_cooldown, cooldown)


func _update_mood(delta: float) -> void:
	if absf(player.velocity.x) > player.max_speed * 0.6:
		energy = minf(energy + 0.13 * delta, 1.0)
	elif player.is_on_floor():
		energy = maxf(energy - 0.07 * delta, 0.0)

	if _poi != null and not is_instance_valid(_poi):
		_poi = null
	if _scary != null and not is_instance_valid(_scary):
		_scary = null

	var next := Mood.CALM
	if _scary != null:
		next = Mood.WARY
	elif _poi != null:
		next = Mood.CURIOUS
	elif energy > 0.55 or (mood == Mood.EXCITED and energy > 0.4):
		next = Mood.EXCITED
	if forced_mood >= 0:
		next = forced_mood as Mood
	if next != mood:
		mood = next
		if mood == Mood.WARY:
			say("...", 1.4)
			_drop_poi(2.0)


func _lead_chance() -> float:
	match mood:
		Mood.EXCITED:
			return 0.9
		Mood.CURIOUS:
			return 0.6
		Mood.WARY:
			return 0.0
	return 0.4


func _mood_gain() -> float:
	return follow_gain * (1.6 if mood == Mood.EXCITED else 1.0)


# --- following the player's jumps -------------------------------------------

func _trail_step(delta: float) -> void:
	_trail_time += delta
	_wait_time = 0.0
	braced = false
	_set_act(Act.FOLLOW)
	var link := _links[0]
	var dx := link.from.x - global_position.x
	if is_on_floor() and absf(link.from.y - global_position.y) < 40.0:
		var close := absf(dx) < 10.0 or (is_on_wall() and absf(dx) < 34.0)
		var crossed := _trail_last_dx != 0.0 and signf(dx) != signf(_trail_last_dx) and absf(dx) < 48.0
		if close or crossed:
			_start_leap(link)
			return
	_trail_last_dx = dx
	velocity.x = move_toward(velocity.x, signf(dx) * max_speed * _catch_up(), accel * delta)


## Speed boost for when the dog has fallen behind.
func _catch_up() -> float:
	var behind := global_position.distance_to(player.global_position)
	return 1.0 + clampf((behind - 130.0) / 260.0, 0.0, 0.5)


## True if the dog's body can fly the arc from p to `to` peaking at apex_y
## without touching anything, at a speed it can manage.
func _arc_is_clear(p: Vector2, to: Vector2, apex_y: float) -> bool:
	var rise := p.y - apex_y
	var fall := to.y - apex_y
	var duration := sqrt(2.0 * rise / gravity) + sqrt(2.0 * fall / gravity)
	var vx := (to.x - p.x) / duration
	if absf(vx) > leap_max_speed:
		return false
	var vy := -sqrt(2.0 * gravity * rise)
	const STEPS := 10
	var prev := p + Vector2(0.0, -2.0)
	for i in range(1, STEPS + 1):
		var t := duration * float(i) / float(STEPS)
		var next := p + Vector2(vx * t, vy * t + 0.5 * gravity * t * t - 2.0)
		if test_move(Transform2D(0.0, prev), next - prev):
			return false
		prev = next
	return true


func _start_leap(link: Link) -> void:
	var p := global_position
	var top := minf(p.y, link.to.y)
	# The arc the player needed is known to work. Prefer the flattest arc that
	# is clear, though: a quick low bound reads as a dog, and it keeps up.
	var safest := minf(link.apex, top) - leap_clearance
	var apex_y := top - 16.0
	while apex_y > safest and not _arc_is_clear(p, link.to, apex_y):
		apex_y -= 22.0
	apex_y = maxf(apex_y, safest)
	var rise := p.y - apex_y
	var fall := link.to.y - apex_y
	_leap_duration = sqrt(2.0 * rise / gravity) + sqrt(2.0 * fall / gravity)
	_leap_time = 0.0
	_leap_to = link.to
	velocity.y = -sqrt(2.0 * gravity * rise)
	velocity.x = clampf((link.to.x - p.x) / _leap_duration, -leap_max_speed, leap_max_speed)
	_links.pop_front()
	_trail_time = 0.0
	_trail_last_dx = 0.0
	_set_act(Act.LEAP)
	hopped.emit()


func _leap_step(delta: float) -> void:
	_leap_time += delta
	# Steer toward the landing spot, so a wall in the way only delays the dog.
	var remaining := maxf(_leap_duration - _leap_time, 0.1)
	var want := clampf((_leap_to.x - global_position.x) / remaining, -leap_max_speed, leap_max_speed)
	velocity.x = move_toward(velocity.x, want, 5000.0 * delta)
	velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
	var impact := velocity.y
	move_and_slide()
	if is_on_floor() and _leap_time > 0.06:
		_set_act(Act.FOLLOW)
		_direct_timer = 0.0
		landed.emit(impact)
	elif _leap_time > _leap_duration + 1.0:
		_set_act(Act.WAIT)


# --- free behaviour ---------------------------------------------------------

func _free_step(delta: float) -> void:
	_trail_time = 0.0
	braced = false
	if not is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		return
	if _chasing != null:
		_chase_step(delta)
		return
	if _chase_over and not staying and _called <= 0.0:
		# Still staring up the tree until told otherwise.
		_set_act(Act.WAIT)
		_brake(delta)
		if _act_time > 5.0:
			_chase_over = false
		return
	_chase_over = false
	if _lure != null:
		_eat_step(delta)
		return
	if _fetching != null:
		_fetch_step(delta)
		return
	if staying:
		_stay_step(delta)
		return
	if _enemy != null:
		_distract_step(delta)
		return
	if _dragging:
		_drag_step(delta)
		return
	if act == Act.PETTED and _petted_step(delta):
		return
	if not _direct:
		# Cannot walk to the player and has no jumps to replay: it is lost.
		_set_act(Act.WAIT)
		_brake(delta)
		if _called > 0.0 and _called < 2.2 and emote == "":
			say("?", 0.9)  # called, but there is no way to come
		if player.is_on_floor():
			_wait_time += delta
		return
	_wait_time = 0.0

	var pp := player.global_position
	var dist := absf(pp.x - global_position.x)
	var player_moving := absf(player.velocity.x) > 40.0 or not player.is_on_floor()

	if _called > 0.0:
		_come_step(delta, dist)
		return
	if mood == Mood.WARY:
		_cower_step(delta)
		return
	if _poi != null:
		_investigate_step(delta)
		return

	var idling := act == Act.SIT or act == Act.LIE or act == Act.WANDER or act == Act.SNIFF
	if idling and player_moving:
		_set_act(Act.STAND)
		perked.emit()
	var roaming := (act == Act.WANDER or act == Act.SNIFF) and dist < wander_radius + 70.0
	var following := act == Act.FOLLOW or act == Act.LEAD

	if _lead and player_moving:
		_set_act(Act.LEAD)
		_drive(pp.x + _run_dir * lead_distance, max_speed * maxf(1.15, _catch_up()), delta, 0.0, 7.0, player.velocity.x)
	elif not roaming and (dist > follow_far or (following and (dist > follow_near + 4.0 or player_moving))):
		_set_act(Act.FOLLOW)
		var clear := _drive(pp.x, max_speed * _catch_up(), delta, follow_near, _mood_gain())
		# Stopped at an edge while the player is mid-jump: get ready to spring.
		braced = not clear and not player.is_on_floor()
	else:
		_idle_step(delta)


func _idle_step(delta: float) -> void:
	match act:
		Act.SIT:
			_brake(delta)
			if _act_time > _act_len:
				if mood == Mood.CALM and _still_time > lie_after:
					_set_act(Act.LIE)
					_next_z = 1.5
				elif randf() < 0.6 and _pick_wander():
					_set_act(Act.WANDER)
				else:
					_act_time = 0.0
					_act_len = randf_range(2.0, 4.0)
		Act.LIE:
			_brake(delta)
			if _act_time > _next_z:
				say("z", 1.6)
				_next_z = _act_time + 3.5
		Act.WANDER:
			var clear := _drive(_wander_x, walk_speed, delta, 4.0, 5.0)
			if not clear or absf(_wander_x - global_position.x) < 9.0 or _act_time > 3.5:
				if _wander_home:
					_sit()
				else:
					_set_act(Act.SNIFF)
					_act_len = randf_range(1.2, 2.6)
		Act.SNIFF:
			_brake(delta)
			if _act_time > _act_len:
				_sniffs += 1
				if _sniffs < 2 and randf() < 0.5 and _pick_wander():
					_set_act(Act.WANDER)
				else:
					# Trot back to the player's side.
					var side := signf(global_position.x - player.global_position.x)
					if side == 0.0:
						side = -1.0
					_wander_x = player.global_position.x + side * follow_near
					_wander_home = true
					_set_act(Act.WANDER)
		_:
			_set_act(Act.STAND)
			_brake(delta)
			if _still_time > sit_after and _act_time > 0.4:
				_sit()


func _sit() -> void:
	_set_act(Act.SIT)
	_act_len = randf_range(2.5, 5.0)
	_sniffs = 0


func _pick_wander() -> bool:
	if not wander_enabled:
		return false
	var side := 1.0 if randf() < 0.5 else -1.0
	for i in 2:
		var x := player.global_position.x + side * randf_range(50.0, wander_radius)
		if _walkable(global_position, Vector2(x, global_position.y)):
			_wander_x = x
			_wander_home = false
			return true
		side = -side
	return false


func _come_step(delta: float, dist: float) -> void:
	_set_act(Act.COME)
	_drive(player.global_position.x, max_speed * 1.15, delta, 22.0, 9.0)
	if dist < 36.0:
		_called = 0.0
		say("heart", 1.4)
		velocity.y = -240.0
		hopped.emit()
		energy = minf(energy + 0.3, 1.0)
		_set_act(Act.STAND)


## After the squirrel, until it gets away.
func _chase_step(delta: float) -> void:
	_set_act(Act.CHASE)
	if is_instance_valid(_chasing) and not _chasing.gone:
		_chase_x = _chasing.global_position.x
	# Keep going to where it was last seen, then bark up at nothing.
	var clear := _drive(_chase_x, max_speed * 1.05, delta, 14.0, 10.0)
	var lost := not is_instance_valid(_chasing) or _chasing.gone
	if lost and (absf(_chase_x - global_position.x) < 24.0 or not clear or is_on_wall() or _act_time > 6.0):
		_chasing = null
		_chase_over = true
		bark_time = 0.3
		say("?", 1.0)
		_set_act(Act.STAND)


## Something smells too good. Everything else is forgotten until it is eaten.
func _eat_step(delta: float) -> void:
	if not is_instance_valid(_lure):
		_lure = null
		_set_act(Act.STAND)
		return
	_set_act(Act.EAT)
	var dx := _lure.global_position.x - global_position.x
	if absf(dx) > 8.0 or absf(_lure.global_position.y - global_position.y) > 12.0:
		# Straight at it, ledges and all.
		velocity.x = move_toward(velocity.x, signf(dx) * max_speed * 0.8, accel * delta)
		_eat_time = 0.0
		if _act_time > 6.0:
			_lure = null
		return
	_brake(delta)
	_eat_time += delta
	if _eat_time > 1.6:
		_lure.queue_free()
		_lure = null
		pips = maxi(pips - 3, 0)
		say("heart", 1.2)
		_set_act(Act.STAND)


## Out to the key, pick it up, and back to the player.
func _fetch_step(delta: float) -> void:
	if not is_instance_valid(_fetching):
		_fetching = null
		_set_act(Act.STAND)
		return
	_set_act(Act.FETCH)
	if not _fetch_home:
		var tx := _fetching.global_position.x
		_drive(tx, max_speed, delta, 0.0, 9.0)
		if absf(tx - global_position.x) < 10.0:
			_fetching.carried_by = self
			_fetch_home = true
		elif _act_time > 6.0:
			_fetching = null
	else:
		var px := player.global_position.x
		_drive(px, max_speed, delta, 18.0, 9.0)
		if absf(px - global_position.x) < 30.0 and absf(player.global_position.y - global_position.y) < 30.0:
			_fetching.carried_by = player
			_fetching = null
			_last_skill = "fetch"
			_last_skill_age = 0.0
			say("heart", 1.0)
			_set_act(Act.STAND)


## Go to the seat and sit. Once it is sitting, any bramble nearby is drawn
## to it and cannot look away.
func _stay_step(delta: float) -> void:
	if absf(_stay_x - global_position.x) > 3.0:
		_set_act(Act.FOLLOW)
		var clear := _drive(_stay_x, max_speed * 0.6, delta, 1.0, 9.0)
		# Cannot get there after all: sit where it is.
		if not clear or is_on_wall() or _act_time > 4.0:
			_stay_x = global_position.x
		return
	_set_act(Act.SIT)
	_act_len = 999.0
	_brake(delta)
	# A stay only lasts as long as it has been practised.
	stay_left -= delta
	if stay_left <= 0.0:
		staying = false
		say("?", 0.8)
		return
	var close := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var d := enemy.global_position - global_position
		if not enemy.is_dead() and absf(d.x) < BRAMBLE_PULL and absf(d.y) < 40.0:
			enemy.distract(self, 0.4)
			close = close or absf(d.x) < 110.0
	_bark_timer -= delta
	if close and _bark_timer <= 0.0:
		_bark_timer = 0.9
		bark_time = 0.3


## Run at the enemy, bark to turn its head, then dance just out of reach
## until it loses interest.
func _distract_step(delta: float) -> void:
	if not is_instance_valid(_enemy) or _enemy.is_dead():
		_end_distract(true)
		return
	_set_act(Act.DISTRACT)
	var ex := _enemy.global_position.x
	var dx := ex - global_position.x
	if not _barked:
		var can_walk := _walkable(global_position, Vector2(ex, global_position.y))
		if absf(dx) < 84.0 or (not can_walk and absf(dx) < 240.0):
			_barked = true
			_bark_timer = 0.0
			_enemy.distract(self, distract_seconds * randf_range(0.85, 1.2))
			say("!", 0.6)
		elif can_walk and _act_time < 2.5:
			_drive(ex, max_speed * 1.1, delta, 64.0, 8.0)
		else:
			_end_distract(false)
	else:
		var side := 1.0 if global_position.x >= ex else -1.0
		_drive(ex + side * 60.0, max_speed * 0.7, delta, 4.0, 6.0)
		_bark_timer -= delta
		if _bark_timer <= 0.0 and is_on_floor():
			_bark_timer = 0.55
			bark_time = 0.3
			velocity.y = -150.0
			hopped.emit()
		if not _enemy.is_distracted():
			_end_distract(true)
	# The player has moved on: so does the dog.
	if _enemy != null and absf(player.global_position.x - global_position.x) > 280.0:
		_end_distract(true)


func _end_distract(worked: bool) -> void:
	_enemy = null
	_barked = false
	_distract_cd = randf_range(distract_wait_min, distract_wait_max) if worked else 2.0
	_set_act(Act.STAND)


## Returns true while the petting reaction is still playing.
func _petted_step(delta: float) -> bool:
	var player_left := absf(player.velocity.x) > 40.0 and _act_time > 0.3
	if _act_time > _act_len or player_left:
		_set_act(Act.STAND)
		return false
	var beat := fmod(_act_time, 0.55) < delta * 1.5
	match pet_style:
		PET_SPIN:
			_brake(delta)
			_spin_timer -= delta
			if _spin_timer <= 0.0:
				_spin_timer = 0.14
				facing = -facing
			if beat:
				velocity.y = -170.0
				hopped.emit()
		PET_LICK:
			_drive(player.global_position.x, max_speed * 0.6, delta, 10.0, 8.0)
			if beat and absf(player.global_position.x - global_position.x) < 26.0:
				velocity.y = -215.0
				hopped.emit()
		_:
			_brake(delta)
	return true


## Trot up, take the tie, and lead the player to the flag.
func _drag_step(delta: float) -> void:
	_set_act(Act.DRAG)
	if not player.dragged:
		if _grabbed:
			_end_drag()  # the player shook free
			return
		var spot := player.global_position.x + _drag_dir * 18.0
		_drive(spot, max_speed, delta, 0.0, 9.0)
		if absf(spot - global_position.x) < 7.0 and player.is_on_floor():
			_grabbed = true
			player.dragged = true
			player.tie_holder = self
			player.drag_target_x = player.global_position.x
		elif _act_time > 3.0:
			_end_drag()
	else:
		var clear := _drive(_drag_goal_x + _drag_dir * 30.0, 135.0, delta, 0.0, 6.0)
		player.drag_target_x = global_position.x - _drag_dir * 18.0
		if not clear or _act_time > 10.0:
			_end_drag()


func _end_drag() -> void:
	_dragging = false
	_grabbed = false
	player.dragged = false
	_drag_block = 5.0
	_set_act(Act.STAND)


## Wary: keep the player between itself and whatever is frightening.
func _cower_step(delta: float) -> void:
	_set_act(Act.COWER)
	var pp := player.global_position
	var away := -float(player.facing)
	if _scary != null:
		away = signf(pp.x - _scary.global_position.x)
		if away == 0.0:
			away = -1.0
	_drive(pp.x + away * 30.0, max_speed * 0.85, delta, 3.0, 8.0, player.velocity.x * 0.8)


## Curious: notice something, trot over, sniff it, report back.
func _investigate_step(delta: float) -> void:
	_set_act(Act.INVESTIGATE)
	var target := _poi.global_position
	var reachable := absf(target.y - global_position.y) < 40.0 \
			and _walkable(global_position, Vector2(target.x, global_position.y))
	match _poi_phase:
		0:
			_brake(delta)
			if _act_time > 0.8:
				if reachable:
					_poi_phase = 1
				else:
					_drop_poi(8.0)
		1:
			var clear := _drive(target.x, max_speed * 0.8, delta, 14.0, 6.0)
			if absf(target.x - global_position.x) < 22.0:
				_poi_phase = 2
				_poi_phase_time = 0.0
			elif not clear or not reachable or _act_time > 6.0:
				_drop_poi(6.0)
		2:
			_brake(delta)
			_poi_phase_time += delta
			if _poi_phase_time > 1.6:
				_poi.seen = true
				say("!", 1.2)
				velocity.y = -230.0
				hopped.emit()
				energy = minf(energy + 0.35, 1.0)
				_drop_poi(0.5)
	if _poi != null and global_position.distance_to(player.global_position) > 320.0:
		_drop_poi(5.0)


## Runs toward target_x, stopping stop_dist short of it. Never runs off a
## ledge. Returns false if a ledge is what stopped it.
func _drive(target_x: float, top_speed: float, delta: float, stop_dist := 0.0, gain := 6.0, feed_forward := 0.0) -> bool:
	var dx := target_x - global_position.x
	var want := signf(dx) * maxf(absf(dx) - stop_dist, 0.0) * gain + feed_forward
	want = clampf(want, -top_speed, top_speed)
	if absf(want) < 14.0:
		want = 0.0
	var clear := true
	if want != 0.0 and not _floor_ahead(signf(want)):
		want = 0.0
		clear = false
	var rate := accel if absf(want) > absf(velocity.x) else decel
	velocity.x = move_toward(velocity.x, want, rate * delta)
	return clear


func _brake(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, decel * delta)


func _set_act(next: Act) -> void:
	if act != next:
		act = next
		_act_time = 0.0


# --- rescue -----------------------------------------------------------------

func _should_rescue(delta: float) -> bool:
	if global_position.y > kill_y:
		return true
	if staying or not rescue_enabled:
		return false
	var far := global_position.distance_to(player.global_position) > rescue_distance
	_far_time = _far_time + delta if far else 0.0
	if _far_time > 0.4:
		return true
	if _trail_time > (0.9 if _called > 0.0 else 3.0):
		return true
	return _wait_time > (0.5 if _called > 0.0 else 1.5)


func _start_rescue() -> void:
	_set_act(Act.RESCUE)
	rescue_count += 1
	_rescue_t = 0.0
	_rescue_from = global_position
	_rescue_len = clampf(0.35 + global_position.distance_to(player.global_position) / 2500.0, 0.35, 0.8)
	collision_mask = 0
	velocity = Vector2.ZERO
	_links.clear()
	_pending = null
	_drop_poi(2.0)
	emote = ""


func _rescue_step(delta: float) -> void:
	_rescue_t = minf(_rescue_t + delta / _rescue_len, 1.0)
	var target := player.global_position if player.is_on_floor() else player.last_safe_position
	var t := smoothstep(0.0, 1.0, _rescue_t)
	global_position = _rescue_from.lerp(target, t) + Vector2(0.0, -sin(t * PI) * 56.0)
	if _rescue_t >= 1.0:
		global_position = target + Vector2(0.0, -1.0)
		collision_mask = WORLD_MASK
		velocity = Vector2.ZERO
		_trail_time = 0.0
		_wait_time = 0.0
		_far_time = 0.0
		_called = 0.0
		_direct = true
		_direct_timer = 0.0
		_set_act(Act.STAND)
		landed.emit(320.0)


# --- where it faces and looks -----------------------------------------------

func _update_facing() -> void:
	if act == Act.RESCUE or (act == Act.PETTED and pet_style == PET_SPIN):
		return
	if absf(velocity.x) > 20.0:
		facing = 1 if velocity.x > 0.0 else -1
	elif act != Act.SNIFF and act != Act.WANDER and act != Act.LEAP:
		var dx := look_point.x - global_position.x
		if absf(dx) > 16.0:
			facing = 1 if dx > 0.0 else -1


func _update_look(delta: float) -> void:
	var here := global_position
	var player_head := player.global_position + Vector2(0.0, -36.0)
	var target := player_head

	_next_glance -= delta
	_glance = maxf(_glance - delta, 0.0)

	match act:
		Act.LEAD:
			# Mostly watch the road, with a glance back at the player.
			target = here + Vector2(facing * 120.0, -18.0)
			if _next_glance <= 0.0:
				_glance = 0.55
				_next_glance = randf_range(1.2, 2.4)
			if _glance > 0.0 or absf(velocity.x) < 20.0:
				target = player_head
		Act.WANDER:
			target = here + Vector2(facing * 40.0, 0.0)
		Act.SNIFF:
			target = here + Vector2(facing * 24.0, 0.0)
		Act.INVESTIGATE:
			if _poi != null:
				target = _poi.global_position + Vector2(0.0, -8.0)
		Act.COWER:
			if _scary != null:
				target = _scary.global_position + Vector2(0.0, -12.0)
			if _next_glance <= 0.0:
				_glance = 0.4
				_next_glance = randf_range(1.0, 2.0)
			if _glance > 0.0:
				target = player_head
		Act.SIT:
			# Now and then something else catches its eye.
			if _next_glance <= 0.0:
				_glance = randf_range(0.6, 1.2)
				_next_glance = randf_range(2.5, 5.0)
				var side := 1.0 if randf() < 0.5 else -1.0
				_glance_point = here + Vector2(side * randf_range(60.0, 160.0), randf_range(-70.0, -5.0))
			if _glance > 0.0:
				target = _glance_point
		Act.LIE:
			target = here + Vector2(facing * 40.0, -6.0)
		Act.FOLLOW:
			if not _links.is_empty():
				target = _links[0].to + Vector2(0.0, -20.0)
		Act.LEAP:
			target = _leap_to + Vector2(0.0, -10.0)
		Act.DISTRACT:
			if is_instance_valid(_enemy):
				target = _enemy.global_position + Vector2(0.0, -10.0)
		Act.DRAG:
			target = here + Vector2(_drag_dir * 80.0, -14.0)

	look_point = look_point.lerp(target, 1.0 - exp(-12.0 * delta))
