extends Node
## Development harness, not part of the game. Plays each level with a simple
## bot, logs how the dog copes, and saves screenshots.
##   godot --path . -- --autotest=/some/output/folder

const LEVEL_SECONDS := 24.0

var main: Node
var out_dir := ""

var _player: Player
var _dog: Dog
var _level_t := 0.0
var _level_seen := -1
var _levels_done := 0
var _log_t := 0.0
var _shot_t := 0.0
var _shots := 0
var _jump_hold := 0.0
var _was_rescue := false
var _acts := {}
var _swing := 0.0
var _phase := 0
var _phase_t := 0.0
var _solving := ""


func _ready() -> void:
	process_physics_priority = -100
	# Only the bot drives: drop the real bindings so stray keystrokes cannot
	# steer, and keep the window from taking keyboard focus.
	for action in InputMap.get_actions():
		if not String(action).begins_with("ui_"):
			InputMap.action_erase_events(action)
	get_window().set_flag(Window.FLAG_NO_FOCUS, true)
	_player = main.get("player")
	_dog = main.get("dog")


func _physics_process(delta: float) -> void:
	var index: int = main.get("level_index")
	if index != _level_seen:
		if _level_seen >= 0:
			_finish_level()
		_level_seen = index
		_level_t = 0.0
		_acts = {}
	_level_t += delta
	_acts[Dog.Act.keys()[_dog.act]] = true

	var rescue := _dog.act == Dog.Act.RESCUE
	if rescue and not _was_rescue:
		print("[autotest] RESCUE  level=%d t=%.1f dog=%s player=%s" % [index, _level_t, _dog.global_position.round(), _player.global_position.round()])
	_was_rescue = rescue

	_drive_bot(delta)

	_log_t -= delta
	if _log_t <= 0.0:
		_log_t = 1.0
		print("[autotest] level=%d t=%4.1f player=%s dog=%s act=%s mood=%s links=%d hp=%d" % [
			index, _level_t, _player.global_position.round(), _dog.global_position.round(),
			Dog.Act.keys()[_dog.act], Dog.Mood.keys()[_dog.mood], _dog.link_count(), _player.health])
	_shot_t -= delta
	if _shot_t <= 0.0 and out_dir != "":
		_shot_t = 1.7
		_screenshot()

	if _level_t > LEVEL_SECONDS:
		main.call("go_to_level", index + 1)


func _finish_level() -> void:
	print("[autotest] level %d done: rescues so far=%d acts seen=%s" % [_level_seen, _dog.rescue_count, ", ".join(_acts.keys())])
	_levels_done += 1
	if _levels_done >= LevelMaps.LEVELS.size():
		Input.action_release("move_right")
		Input.action_release("jump")
		get_tree().quit()


## Stands still at the start (to show idle behaviour), then runs right,
## jumping at gaps and walls, with a short breather every so often.
func _drive_bot(delta: float) -> void:
	var level_now: Level = main.get("level")
	if level_now.rewind:
		_solve(delta, level_now)
		return
	var resting := _level_t < 5.0 or fmod(_level_t, 11.0) > 8.5
	if (_level_t > 1.5 and _level_t < 1.6) or (_level_t > 3.2 and _level_t < 3.3):
		Input.action_press("pet_dog")
	else:
		Input.action_release("pet_dog")
	if _jump_hold > 0.0:
		_jump_hold -= delta
		if _jump_hold <= 0.0:
			Input.action_release("jump")
	# Dawdle just short of the flag, to let the dog tow us over the line.
	var level: Level = main.get("level")
	for goal in level.goals:
		var gap := goal.x - _player.global_position.x
		if gap > 60.0 and gap < 180.0 and absf(goal.y - _player.global_position.y) < 8.0:
			resting = true
	if resting and _player.is_on_floor():
		Input.action_release("move_right")
		return
	# Stand and swing at any enemy just ahead.
	_swing -= delta
	Input.action_release("attack")
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		var d := enemy.global_position - _player.global_position
		if not enemy.is_dead() and d.x > -20.0 and d.x < 60.0 and absf(d.y) < 40.0:
			Input.action_release("move_right")
			if _swing <= 0.0 and d.x < 40.0:
				_swing = 0.36
				Input.action_press("attack")
			return
	Input.action_press("move_right")
	if not _player.is_on_floor() or _jump_hold > 0.0:
		return

	var pos := _player.global_position
	var wall := _ray(pos + Vector2(0.0, -8.0), pos + Vector2(30.0, -8.0))
	var gap := not _ray(pos + Vector2(24.0, -4.0), pos + Vector2(24.0, 40.0))
	if wall:
		_jump(0.5)
	elif gap:
		# Measure the gap, and only tap jump for a short one.
		var width := 0.0
		while width < 260.0 and not _ray(pos + Vector2(24.0 + width, -60.0), pos + Vector2(24.0 + width, 80.0)):
			width += 8.0
		if width >= 260.0:
			return  # a drop: just run off it
		_jump(0.04 if width <= 72.0 else 0.5)


func _jump(hold: float) -> void:
	Input.action_press("jump")
	_jump_hold = hold


func _ray(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return not _player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _screenshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/shot_%d_%02d.png" % [out_dir, _level_seen, _shots])
	_shots += 1


func _next_phase(note: String) -> void:
	_phase += 1
	_phase_t = 0.0
	print("[autotest] SOLVE %s: %s (level t=%.1f)" % [_solving, note, _level_t])


## Scripted solutions for the rewind levels, to prove they can be finished.
func _solve(delta: float, level: Level) -> void:
	if _solving != level.title:
		_solving = level.title
		_phase = 0
		_phase_t = 0.0
	_phase_t += delta
	for action: String in ["move_right", "move_left", "rewind", "stay", "attack"]:
		Input.action_release(action)
	if _jump_hold > 0.0:
		_jump_hold -= delta
		if _jump_hold <= 0.0:
			Input.action_release("jump")
	var p := _player.global_position
	var floor_ahead := _ray(p + Vector2(24.0, -4.0), p + Vector2(24.0, 40.0))
	var jump_gaps := _player.is_on_floor() and not floor_ahead and _jump_hold <= 0.0

	match level.title:
		"Second chances":
			# Deliberately walk into the first gap, then undo it and jump.
			if _player.knocked_out or (_phase == 1 and _phase_t < 1.2):
				if _phase == 0:
					_next_phase("fell, rewinding")
				Input.action_press("rewind")
			else:
				Input.action_press("move_right")
				if jump_gaps and _phase > 0:
					_jump(0.5)
		"Stay":
			var plate := get_tree().get_first_node_in_group("plates") as Plate
			match _phase:
				0:
					Input.action_press("move_right")
					if p.y > level.player_spawn.y + 100.0 and _player.is_on_floor():
						_next_phase("dropped into the chamber")
				1:
					if p.x < plate.global_position.x + 30.0:
						Input.action_press("move_right")
					elif _dog.is_on_floor() and absf(_dog.global_position.y - p.y) < 4.0 and _phase_t > 1.5:
						Input.action_press("stay")
						_next_phase("told the dog to stay")
				2:
					if _dog.staying and plate.pressed:
						_next_phase("dog is on the plate")
				3:
					Input.action_press("rewind")
					if p.y <= level.player_spawn.y + 1.0 and p.x < 600.0:
						_next_phase("rewound to the top, dog at %s" % _dog.global_position.round())
				4:
					Input.action_press("move_right")
					if jump_gaps:
						_jump(0.5)
		"Hold its eye":
			var bramble := get_tree().get_first_node_in_group("enemies") as Enemy
			match _phase:
				0:
					if p.x < 560.0:
						Input.action_press("move_right")
					elif absf(_dog.global_position.x - p.x) < 90.0 and _phase_t > 1.0:
						Input.action_press("stay")
						_next_phase("told the dog to stay")
				1:
					Input.action_press("move_right")
					if bramble.is_hunting() or p.x > 860.0:
						_next_phase("bramble has seen us")
				2:
					if p.x > _dog.global_position.x - 50.0:
						Input.action_press("move_left")
					if bramble.is_distracted():
						_next_phase("bramble is staring at the dog")
				3:
					var gap := bramble.global_position.x - p.x
					if bramble.is_dead():
						_next_phase("bramble beaten")
					elif gap > 34.0:
						Input.action_press("move_right")
					else:
						_swing -= delta
						if _swing <= 0.0:
							_swing = 0.36
							Input.action_press("attack")
				4:
					Input.action_press("move_right")
