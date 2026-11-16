extends Node2D
## Loads the levels, wires player, dog and camera together, turns key presses
## into dog commands, and draws the on-screen status.

const HELP := "Move  A/D     Jump  Space     Dog:  stay  S    fetch  G    call  E    pet  F    biscuit  T    sandwich  hold H\nRestart  R     Rooms  [ ]     Debug  Tab"
const THROW_SPEED := Vector2(300.0, -300.0)

@onready var view: SubViewportContainer = $View
@onready var world: SubViewport = $View/World
@onready var player: Player = $View/World/Player
@onready var dog: Dog = $View/World/Dog
@onready var camera: CameraRig = $Camera

var level: Level
var backdrop: Backdrop
var level_index := 0
## How many rooms have been finished this session.
var completed := 0

var _title: Label
var _help: Label
var _debug: Label
var _status: Label
var _pips: Pips
var _status_row: HBoxContainer
var _hearts: Hearts
var _prompt: Label
var _vignette: TextureRect
var _aim: Aim
var _show_debug := false
var _switching := false
var _dawdle := 0.0


func _ready() -> void:
	# The world is drawn into its own viewport at full detail (see camera.gd).
	view.stretch = false
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	dog.player = player
	player.tie_holder = dog
	player.died.connect(_on_player_died)
	player.hurt.connect(_on_player_hurt)
	camera.target = player
	camera.dog = dog
	camera.world = world
	camera.view = view

	backdrop = Backdrop.new()
	backdrop.camera = camera
	world.add_child(backdrop)
	world.move_child(backdrop, 0)
	var motes := Backdrop.Motes.new()
	motes.camera = camera
	world.add_child(motes)
	_aim = Aim.new()
	world.add_child(_aim)

	_build_hud()
	_load_level(0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			_load_level(int(arg.get_slice("=", 1)))
		if arg.begins_with("--autotest"):
			var bot: Node = load("res://scripts/dev/autotest.gd").new()
			bot.set("main", self)
			bot.set("out_dir", arg.get_slice("=", 1))
			add_child(bot)


func _physics_process(delta: float) -> void:
	if level == null:
		return
	_prompt.visible = false

	# Dog commands.
	if Input.is_action_just_pressed("call_dog"):
		dog.call_dog()
	if Input.is_action_just_pressed("stay"):
		dog.toggle_stay()
	if Input.is_action_just_pressed("fetch"):
		dog.fetch()
	var near_dog := player.global_position.distance_to(dog.global_position) < 80.0
	if Input.is_action_just_pressed("feed") and player.biscuits > 0 and near_dog:
		player.biscuits -= 1
		player.petting = 1.2
		player.facing = 1 if dog.global_position.x >= player.global_position.x else -1
		dog.feed()
	if Input.is_action_just_pressed("pet_dog") and player.is_on_floor() and dog.pet():
		player.petting = 1.8
		player.facing = 1 if dog.global_position.x >= player.global_position.x else -1
	_update_throw()

	if Input.is_action_just_pressed("restart"):
		go_to_level(level_index)
	if Input.is_action_just_pressed("next_level"):
		go_to_level(level_index + 1)
	if Input.is_action_just_pressed("prev_level"):
		go_to_level(level_index - 1)
	if Input.is_action_just_pressed("toggle_debug"):
		_show_debug = not _show_debug
		_debug.visible = _show_debug

	if level.puzzle:
		_check_exit()
		if player.global_position.y > level.bounds.end.y + 60.0:
			# Puzzle rooms are short: a fall just starts the room again.
			go_to_level(level_index)
	else:
		_check_dawdling(delta)
		if player.global_position.y > level.kill_y:
			# Fell out of the level: back to the last solid ground.
			player.teleport(player.last_safe_position)
			dog.forget_trail()
			camera.snap()

	_hearts.show_health(player.health, player.max_health)
	_pips.show_pips(dog.pips, Dog.MAX_PIPS)
	var hold := Dog.STAY_SECONDS[dog.skill_level("stay") - 1]
	_status.text = "Biscuits %d     Sandwiches %d     Stay Lv %d (%s)     Fetch Lv %d     Hunger" % [
		player.biscuits, player.sandwiches, dog.skill_level("stay"),
		"holds" if hold > 1000.0 else "%d s" % int(hold), dog.skill_level("fetch")]
	if _show_debug:
		_debug.text = "dog: %s   mood: %s   pips: %d   staying: %s   jumps queued: %d\nplayer at %s   on floor: %s" % [
			Dog.Act.keys()[dog.act], Dog.Mood.keys()[dog.mood], dog.pips, dog.staying,
			dog.link_count(), player.global_position.round(), player.is_on_floor()]


## Hold the throw key to see where a sandwich will land; let go to throw it.
func _update_throw() -> void:
	_aim.points = PackedVector2Array()
	if player.sandwiches <= 0:
		return
	var from := player.global_position + Vector2(player.facing * 8.0, -30.0)
	var velocity := Vector2(player.facing * THROW_SPEED.x, THROW_SPEED.y)
	if Input.is_action_pressed("throw"):
		_aim.points = ThrownBait.preview(player.get_world_2d().direct_space_state, from, velocity)
	elif Input.is_action_just_released("throw"):
		player.sandwiches -= 1
		var bait := ThrownBait.new()
		bait.position = from
		bait.velocity = velocity
		level.add_child(bait)


## In a puzzle room the flag only counts if the dog is there too.
func _check_exit() -> void:
	var here := player.global_position
	for goal in level.goals:
		if absf(here.x - goal.x) > 22.0 or absf(here.y - goal.y) > 40.0:
			continue
		if dog.global_position.distance_to(here) < 200.0 and not dog.staying:
			completed += 1
			go_to_level(level_index + 1)
		else:
			_prompt.text = "Not without the dog"
			_prompt.visible = true


## Standing about just short of the flag? The dog comes back, takes the tie,
## and tows the player over the line.
func _check_dawdling(delta: float) -> void:
	if player.dragged or not dog.can_drag():
		_dawdle = 0.0
		return
	var here := player.global_position
	var idle := player.is_on_floor() and absf(player.input_x) < 0.1 and absf(player.velocity.x) < 5.0 \
			and player.petting <= 0.0
	var goal_x := INF
	for goal in level.goals:
		var gap := absf(goal.x - here.x)
		if gap > 34.0 and gap < 280.0 and absf(goal.y - here.y) < 8.0 and dog.is_walkable(here, goal):
			goal_x = goal.x
	if not idle or goal_x == INF:
		_dawdle = 0.0
		return
	_dawdle += delta
	if _dawdle > dog.drag_after:
		_dawdle = 0.0
		dog.start_drag(goal_x)


func _on_player_died() -> void:
	go_to_level(level_index)


## In a puzzle room a single touch from a bramble starts the room again.
func _on_player_hurt() -> void:
	if level != null and level.puzzle:
		go_to_level(level_index)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_0:
			dog.forced_mood = -1
		KEY_1:
			dog.forced_mood = Dog.Mood.CALM
		KEY_2:
			dog.forced_mood = Dog.Mood.CURIOUS
		KEY_3:
			dog.forced_mood = Dog.Mood.EXCITED
		KEY_4:
			dog.forced_mood = Dog.Mood.WARY


func go_to_level(index: int) -> void:
	if _switching:
		return
	_switching = true
	_load_level.call_deferred(index)


func _load_level(index: int) -> void:
	_switching = false
	level_index = wrapi(index, 0, LevelMaps.LEVELS.size())
	if level != null:
		level.queue_free()
	level = Level.new()
	world.add_child(level)
	world.move_child(level, 1)
	level.build(LevelMaps.LEVELS[level_index])
	level.goal_reached.connect(_on_goal_reached)

	player.teleport(level.player_spawn)
	player.health = player.max_health
	player.invulnerable = 0.0
	player.biscuits = 0
	player.sandwiches = 0
	dog.reset(level.dog_spawn)
	dog.kill_y = level.kill_y
	# Puzzle rooms play by stricter rules, and each states what the dog knows
	# and how hungry it is, so no room depends on an earlier one.
	dog.rescue_enabled = not level.puzzle
	dog.auto_distract = not level.puzzle
	dog.wander_enabled = not level.puzzle
	dog.hunger_enabled = level.puzzle
	dog.pips = level.start_pips if level.puzzle else 0
	for skill: String in dog.skills:
		dog.skills[skill] = int(level.skills.get(skill, 1)) if level.puzzle else 3

	backdrop.set_level(level.player_spawn, level.theme)
	camera.bounds = level.bounds
	camera.snap()

	# Light text over the dark themes, dark text otherwise.
	var dark := level.theme == "night" or level.theme == "gloam"
	var ink := Color(0.94, 0.95, 1.0) if dark else Color(0.17, 0.15, 0.13)
	_vignette.visible = level.theme == "gloam"
	_title.add_theme_color_override("font_color", Color(ink, 0.9))
	_help.add_theme_color_override("font_color", Color(ink, 0.6))
	_status.add_theme_color_override("font_color", Color(ink, 0.9))
	_debug.add_theme_color_override("font_color", Color(ink, 0.85))
	_hearts.visible = not level.puzzle
	_status_row.visible = level.puzzle
	_title.text = "%d / %d   %s" % [level_index + 1, LevelMaps.LEVELS.size(), level.title]


func _on_goal_reached() -> void:
	if not level.puzzle:
		completed += 1
		go_to_level(level_index + 1)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# A soft dark edge around the screen.
	var falloff := Gradient.new()
	falloff.set_color(0, Color(0.02, 0.04, 0.07, 0.0))
	falloff.set_color(1, Color(0.02, 0.04, 0.07, 0.7))
	falloff.set_offset(0, 0.55)
	var shade := GradientTexture2D.new()
	shade.gradient = falloff
	shade.fill = GradientTexture2D.FILL_RADIAL
	shade.fill_from = Vector2(0.5, 0.5)
	shade.fill_to = Vector2(1.05, 0.5)
	_vignette = TextureRect.new()
	_vignette.texture = shade
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_vignette)

	var box := VBoxContainer.new()
	box.position = Vector2(16.0, 12.0)
	box.add_theme_constant_override("separation", 2)
	layer.add_child(box)
	_title = _hud_label(box, 18, 0.85)
	_hearts = Hearts.new()
	_hearts.custom_minimum_size = Vector2(160.0, 22.0)
	box.add_child(_hearts)
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 8)
	box.add_child(_status_row)
	_status = _hud_label(_status_row, 14, 0.9)
	_pips = Pips.new()
	_pips.custom_minimum_size = Vector2(100.0, 18.0)
	_status_row.add_child(_pips)
	_help = _hud_label(box, 13, 0.55)
	_help.text = HELP
	_debug = _hud_label(box, 13, 0.8)
	_debug.visible = false

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 24)
	_prompt.add_theme_color_override("font_color", Color("fff8e6"))
	_prompt.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.14))
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y = 150.0
	_prompt.visible = false
	layer.add_child(_prompt)


func _hud_label(parent: Node, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.17, 0.15, 0.13, alpha))
	parent.add_child(label)
	return label


## The player's health, drawn as a row of hearts.
class Hearts extends Control:
	var _health := -1
	var _max := 0

	func show_health(health: int, max_health: int) -> void:
		if health != _health or max_health != _max:
			_health = health
			_max = max_health
			queue_redraw()

	func _draw() -> void:
		for i in _max:
			var c := Vector2(10.0 + i * 24.0, 9.0)
			var color := Color("e2574c") if i < _health else Color(0.17, 0.15, 0.13, 0.25)
			draw_circle(c + Vector2(-4.2, -2.0), 5.2, color)
			draw_circle(c + Vector2(4.2, -2.0), 5.2, color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-9.0, 0.6), c + Vector2(9.0, 0.6), c + Vector2(0.0, 10.5)]), color)


## The dog's hunger, as pips that fill up.
class Pips extends Control:
	var _pips := -1
	var _max := 0

	func show_pips(pips: int, max_pips: int) -> void:
		if pips != _pips or max_pips != _max:
			_pips = pips
			_max = max_pips
			queue_redraw()

	func _draw() -> void:
		for i in _max:
			var c := Vector2(8.0 + i * 17.0, 10.0)
			var full := i < _pips
			var warm := Color("ffb347") if _pips < _max else Color("ff6a5e")
			draw_circle(c, 6.5, Color(0.05, 0.06, 0.09, 0.6))
			draw_circle(c, 5.0, warm if full else Color(1.0, 1.0, 1.0, 0.18))


## The dotted arc shown while aiming a throw.
class Aim extends Node2D:
	var points := PackedVector2Array():
		set(value):
			points = value
			queue_redraw()

	func _draw() -> void:
		if points.size() < 2:
			return
		for i in range(0, points.size() - 1, 3):
			draw_circle(points[i], 1.6, Color(1.0, 0.95, 0.75, 0.8), true, -1.0, true)
		var landing := points[points.size() - 1]
		draw_arc(landing, 7.0, 0.0, TAU, 20, Color(1.0, 0.95, 0.75, 0.9), 1.6, true)
		draw_circle(landing, 2.2, Color(1.0, 0.95, 0.75, 0.9), true, -1.0, true)
