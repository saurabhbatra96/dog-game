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
enum Act { STAND, FOLLOW, LEAD, SIT, LIE, WANDER, SNIFF, INVESTIGATE, COWER, COME, WAIT, LEAP, RESCUE }

## One airborne stretch of the player's path: where they left the ground,
## where they landed, and how high they got in between.
class Link:
	var from: Vector2
	var to: Vector2
	var apex: float

const WORLD_MASK := 1
const HALF_WIDTH := 14.0

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
	if act == Act.RESCUE:
		return
	_called = 3.0
	_drop_poi(3.0)
	say("!", 0.7)
	perked.emit()


## Returns true if the dog was close enough to be petted.
func pet() -> bool:
	if act == Act.RESCUE or act == Act.LEAP or not is_on_floor():
		return false
	if global_position.distance_to(player.global_position) > 64.0:
		return false
	say("heart", 1.6)
	energy = minf(energy + 0.25, 1.0)
	_set_act(Act.SIT)
	_act_len = 2.2
	_sniffs = 0
	return true


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
			if not _walkable(_pending.from, _pending.to):
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
	if absf(a.y - b.y) > 6.0 or absf(a.x - b.x) > 900.0:
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
	var busy := act == Act.LEAP or act == Act.RESCUE or not _links.is_empty() or _called > 0.0
	if best != null and _poi == null and _poi_cooldown <= 0.0 and not busy and _scary == null:
		_poi = best
		_poi_phase = 0
		_set_act(Act.INVESTIGATE)
		_act_time = 0.0
		say("?", 1.0)
		perked.emit()


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
	if not _direct:
		# Cannot walk to the player and has no jumps to replay: it is lost.
		_set_act(Act.WAIT)
		_brake(delta)
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
	if act == Act.RESCUE:
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

	look_point = look_point.lerp(target, 1.0 - exp(-12.0 * delta))
