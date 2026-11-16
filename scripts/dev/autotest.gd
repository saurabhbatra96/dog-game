extends Node
## Development harness, not part of the game.
##   godot --path . -- --autotest=/some/output/folder
##
## Runs every case in PuzzleCases: a scripted bot plays a puzzle room, either
## to prove it can be finished or to prove that a tempting mistake fails.
## Then it runs through the scenery levels to check nothing errors.
## Results are printed as PASS or FAIL lines, and screenshots are saved.

const SCENERY_SECONDS := 6.0

var main: Node
var out_dir := ""

var _player: Player
var _dog: Dog
var _case := -1
var _steps: Array = []
var _step := 0
var _step_t := 0.0
var _case_t := 0.0
var _ready_t := 0.0
var _done_at := -1
var _start_y := 0.0
var _jump_hold := 0.0
var _shot_t := 0.0
var _shots := 0
var _passed := 0
var _failed := 0
var _scenery := -1
var _scenery_t := 0.0
var _only := ""


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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.get_slice("=", 1)
	_next_case()


func _level() -> Level:
	return main.get("level")


func _index_of(room: String) -> int:
	for i in LevelMaps.LEVELS.size():
		if LevelMaps.LEVELS[i]["name"] == room:
			return i
	return -1


func _next_case() -> void:
	_release_all()
	_case += 1
	# --only=text runs just the rooms whose name contains the text.
	while _only != "" and _case < PuzzleCases.CASES.size() and not String(PuzzleCases.CASES[_case]["room"]).contains(_only):
		_case += 1
	if _case >= PuzzleCases.CASES.size() and _only != "":
		_report("DONE  %d passed, %d failed" % [_passed, _failed])
		get_tree().quit()
		return
	if _case >= PuzzleCases.CASES.size():
		_scenery = PuzzleCases.CASES.size()  # scenery levels follow the puzzle rooms
		_scenery_t = 0.0
		main.call("go_to_level", _first_scenery())
		return
	var case: Dictionary = PuzzleCases.CASES[_case]
	_steps = case["steps"]
	_step = 0
	_step_t = 0.0
	_case_t = 0.0
	_ready_t = 0.0
	_done_at = int(main.get("completed"))
	main.call("go_to_level", _index_of(case["room"]))


func _first_scenery() -> int:
	for i in LevelMaps.LEVELS.size():
		if not LevelMaps.LEVELS[i].get("puzzle", false):
			return i
	return 0


func _release_all() -> void:
	for action: String in ["move_right", "move_left", "jump", "stay", "fetch", "feed", "throw", "call_dog", "pet_dog"]:
		_release(action)
	_jump_hold = 0.0


func _finish(passed: bool, note: String) -> void:
	var case: Dictionary = PuzzleCases.CASES[_case]
	_report("%s  %s: %s (%s) %s" % ["PASS" if passed else "FAIL", case["room"], case["what"], case["expect"], note])
	if passed:
		_passed += 1
	else:
		_failed += 1
	_next_case()


func _physics_process(delta: float) -> void:
	_shot_t -= delta
	if _shot_t <= 0.0 and out_dir != "":
		_shot_t = 1.5
		_screenshot()
	if _case >= PuzzleCases.CASES.size():
		_run_scenery(delta)
		return

	var case: Dictionary = PuzzleCases.CASES[_case]
	var level := _level()
	var expect: String = case["expect"]
	# Finishing a room loads the next one, so check for that before anything
	# that depends on still being in the room.
	var finished := _ready_t >= 0.4 and int(main.get("completed")) > _done_at
	if finished:
		_release_all()
		if expect == "finish":
			_finish(true, "in %.1f s" % _case_t)
		else:
			_finish(false, "the mistake finished the room")
		return
	# Wait for the room to load and settle.
	if level == null or level.title != case["room"] or main.get("_switching"):
		return
	_ready_t += delta
	if _ready_t < 0.4:
		_start_y = _player.global_position.y
		_done_at = int(main.get("completed"))
		return
	_case_t += delta
	var trapped := _dog.global_position.y > _start_y + 60.0 and _dog.is_on_floor()
	if expect == "dog_trapped" and trapped:
		_finish(true, "dog ended up in the pit")
		return

	_release_all_but_jump()
	if _jump_hold > 0.0:
		_jump_hold -= delta
		if _jump_hold <= 0.0:
			Input.action_release("jump")

	if _step >= _steps.size():
		# Out of steps: give the room a moment to register the result.
		if _step_t > 2.5:
			if expect == "stuck":
				_finish(true, "no way through")
			else:
				_finish(false, "ran out of steps; dog %s at %s, player at %s" % [
					Dog.Act.keys()[_dog.act], _dog.global_position.round(), _player.global_position.round()])
		_step_t += delta
		return

	_step_t += delta
	var limit := 14.0 if expect == "finish" else 6.0
	if _step_t > limit:
		if expect == "stuck":
			_finish(true, "blocked at step %d %s" % [_step, str(_steps[_step])])
		else:
			_finish(false, "step %d %s timed out; dog %s at %s pips %d, player at %s" % [
				_step, str(_steps[_step]), Dog.Act.keys()[_dog.act], _dog.global_position.round(), _dog.pips,
				_player.global_position.round()])
		return
	_do_step(_steps[_step], level)


## Releasing an action that is not held still counts as a fresh release in
## Godot, which would hide the real one from "just released" checks.
func _release(action: String) -> void:
	if Input.is_action_pressed(action):
		Input.action_release(action)


func _report(line: String) -> void:
	print("[autotest] " + line)
	if out_dir != "":
		var path := out_dir + "/results.txt"
		var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
		file.seek_end()
		file.store_line(line)
		file.close()


func _release_all_but_jump() -> void:
	for action: String in ["move_right", "move_left", "stay", "fetch", "feed", "throw", "call_dog"]:
		_release(action)


func _advance() -> void:
	_step += 1
	_step_t = 0.0
	_has_eaten = false
	_pips_at_step = -1


func _do_step(step: Array, level: Level) -> void:
	var op: String = step[0]
	var p := _player.global_position
	var bramble := get_tree().get_first_node_in_group("enemies") as Enemy
	match op:
		"right", "rightj", "left", "leftj":
			var dir := -1.0 if op.begins_with("left") else 1.0
			Input.action_press("move_right" if dir > 0.0 else "move_left")
			if op.ends_with("j") and _player.is_on_floor() and _jump_hold <= 0.0:
				var gap := not _ray(p + Vector2(dir * 24.0, -4.0), p + Vector2(dir * 24.0, 40.0))
				var wall := _ray(p + Vector2(0.0, -8.0), p + Vector2(dir * 30.0, -8.0)) \
						or _ray(p + Vector2(0.0, -40.0), p + Vector2(dir * 30.0, -40.0))
				if gap or wall:
					Input.action_press("jump")
					_jump_hold = 0.5
			if (p.x - float(step[1])) * dir >= 0.0:
				_advance()
		"press":
			Input.action_press(step[1])
			_advance()
		"wait":
			if _step_t > float(step[1]):
				_advance()
		"until":
			var done := false
			match step[1]:
				"dog_near":
					done = absf(_dog.global_position.x - p.x) < 100.0 and absf(_dog.global_position.y - p.y) < 6.0 \
							and _dog.is_on_floor() and _step_t > 0.5
				"dog_seated":
					done = _dog.staying and _dog.act == Dog.Act.SIT
				"plateA":
					done = _dog.staying and _dog.act == Dog.Act.SIT and _pressed("A")
				"plateB":
					done = _pressed("B")
				"has_key":
					for node in get_tree().get_nodes_in_group("items"):
						if (node as Item).carried_by == _player:
							done = true
				"dog_ate":
					var flying := false
					for node in level.get_children():
						if node is ThrownBait:
							flying = true
					var ate := _eaten_since_start(level)
					_has_eaten = _has_eaten or ate
					done = not flying and _dog.act != Dog.Act.EAT and _step_t > 1.2 and _has_eaten
				"dog_chased":
					done = get_tree().get_nodes_in_group("squirrels").is_empty() and _dog.act != Dog.Act.CHASE and _step_t > 1.0
				"hunting":
					done = bramble != null and (bramble.is_hunting() or bramble.is_distracted())
				"held":
					done = bramble != null and bramble.is_distracted() and absf(bramble.velocity.x) < 2.0 and _step_t > 1.0
			if done:
				_advance()


## True once the dog has eaten something since this step began: its hunger
## dropped, which only eating does.
var _pips_at_step := -1
var _has_eaten := false
func _eaten_since_start(_level_now: Level) -> bool:
	if _pips_at_step < 0:
		_pips_at_step = _dog.pips
		return false
	if _dog.pips > _pips_at_step:
		_pips_at_step = _dog.pips
	return _dog.pips < _pips_at_step


func _pressed(channel: String) -> bool:
	for node in get_tree().get_nodes_in_group("plates"):
		var plate := node as Plate
		if plate.channel == channel and plate.pressed:
			return true
	return false


## A quick run through the scenery levels, to catch errors.
func _run_scenery(delta: float) -> void:
	var level := _level()
	if level == null or level.puzzle or main.get("_switching"):
		return
	_scenery_t += delta
	Input.action_press("move_right")
	var p := _player.global_position
	if _player.is_on_floor() and _jump_hold <= 0.0:
		if _ray(p + Vector2(0.0, -8.0), p + Vector2(30.0, -8.0)) or not _ray(p + Vector2(24.0, -4.0), p + Vector2(24.0, 40.0)):
			Input.action_press("jump")
			_jump_hold = 0.5
	if _jump_hold > 0.0:
		_jump_hold -= delta
		if _jump_hold <= 0.0:
			Input.action_release("jump")
	if _scenery_t > SCENERY_SECONDS:
		_scenery_t = 0.0
		_scenery += 1
		if _scenery >= LevelMaps.LEVELS.size() + PuzzleCases.CASES.size() - _first_scenery():
			_report("DONE  %d passed, %d failed" % [_passed, _failed])
			_release_all()
			get_tree().quit()
		else:
			main.call("go_to_level", int(main.get("level_index")) + 1)


func _ray(from: Vector2, to: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(from, to, 1)
	return not _player.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _screenshot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var tag := "case%02d" % _case if _case < PuzzleCases.CASES.size() else "scenery"
	image.save_png("%s/%s_%03d.png" % [out_dir, tag, _shots])
	_shots += 1
