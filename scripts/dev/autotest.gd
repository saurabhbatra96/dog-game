extends Node
## Development harness, not part of the game. Plays each level with a simple
## bot, logs how the dog copes, and saves screenshots.
##   godot --path . -- --autotest=/some/output/folder

const LEVEL_SECONDS := 34.0

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
		print("[autotest] level=%d t=%4.1f player=%s dog=%s act=%s mood=%s links=%d" % [
			index, _level_t, _player.global_position.round(), _dog.global_position.round(),
			Dog.Act.keys()[_dog.act], Dog.Mood.keys()[_dog.mood], _dog.link_count()])
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
	var resting := _level_t < 7.0 or fmod(_level_t, 11.0) > 8.5
	if _level_t > 3.0 and _level_t < 3.1:
		Input.action_press("pet_dog")
	else:
		Input.action_release("pet_dog")
	if _jump_hold > 0.0:
		_jump_hold -= delta
		if _jump_hold <= 0.0:
			Input.action_release("jump")
	if resting and _player.is_on_floor():
		Input.action_release("move_right")
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
