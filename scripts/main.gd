extends Node2D
## Loads the grey-box levels, wires player, dog and camera together, and draws
## the on-screen help and debug readout.

const HELP := "Move  A/D or arrows     Jump  Space     Attack  J     Call dog  E     Pet dog  F\nRestart  R     Levels  [ ]     Dog mood  1-4 (0 auto)     Debug  Tab"

@onready var view: SubViewportContainer = $View
@onready var world: SubViewport = $View/World
@onready var player: Player = $View/World/Player
@onready var dog: Dog = $View/World/Dog
@onready var camera: CameraRig = $Camera

var level: Level
var backdrop: Backdrop
var level_index := 0

var _title: Label
var _help: Label
var _debug: Label
var _show_debug := false
var _switching := false
var _hearts: Hearts
var _dawdle := 0.0


func _ready() -> void:
	# The world is drawn small and scaled up with hard pixels (see camera.gd).
	view.stretch = false
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.snap_2d_transforms_to_pixel = true
	world.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	dog.player = player
	player.tie_holder = dog
	player.died.connect(_on_player_died)
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

	_build_hud()
	_load_level(0)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--autotest"):
			var bot: Node = load("res://scripts/dev/autotest.gd").new()
			bot.set("main", self)
			bot.set("out_dir", arg.get_slice("=", 1))
			add_child(bot)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("call_dog"):
		dog.call_dog()
	if Input.is_action_just_pressed("pet_dog") and player.is_on_floor() and dog.pet():
		player.petting = 1.8
		player.facing = 1 if dog.global_position.x >= player.global_position.x else -1
	_hearts.show_health(player.health, player.max_health)
	_check_dawdling(_delta)
	if Input.is_action_just_pressed("restart"):
		go_to_level(level_index)
	if Input.is_action_just_pressed("next_level"):
		go_to_level(level_index + 1)
	if Input.is_action_just_pressed("prev_level"):
		go_to_level(level_index - 1)
	if Input.is_action_just_pressed("toggle_debug"):
		_show_debug = not _show_debug
		_debug.visible = _show_debug

	# Fell out of the level: put the player back on the last solid ground.
	if level != null and player.global_position.y > level.kill_y:
		player.teleport(player.last_safe_position)
		dog.forget_trail()
		camera.snap()

	if _show_debug:
		_debug.text = "dog: %s   mood: %s%s   energy: %.2f   jumps queued: %d   rescues: %d\nplayer speed: %4.0f   on floor: %s" % [
			Dog.Act.keys()[dog.act],
			Dog.Mood.keys()[dog.mood],
			" (forced)" if dog.forced_mood >= 0 else "",
			dog.energy,
			dog.link_count(),
			dog.rescue_count,
			player.velocity.length(),
			player.is_on_floor(),
		]


## Standing about just short of the flag? The dog comes back, takes the tie,
## and tows the player over the line.
func _check_dawdling(delta: float) -> void:
	if level == null or player.dragged or not dog.can_drag():
		_dawdle = 0.0
		return
	var here := player.global_position
	var idle := player.is_on_floor() and absf(player.input_x) < 0.1 and absf(player.velocity.x) < 5.0 \
			and player.attack_time <= 0.0 and player.petting <= 0.0
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
	dog.reset(level.dog_spawn)
	dog.kill_y = level.kill_y
	backdrop.set_level(level.player_spawn, level.theme)
	camera.bounds = level.bounds
	camera.snap()
	# Light text over the night sky, dark text otherwise.
	var ink := Color(0.94, 0.95, 1.0) if level.theme == "night" else Color(0.17, 0.15, 0.13)
	_title.add_theme_color_override("font_color", Color(ink, 0.9))
	_help.add_theme_color_override("font_color", Color(ink, 0.6))
	_debug.add_theme_color_override("font_color", Color(ink, 0.85))
	_title.text = "%d / %d   %s" % [level_index + 1, LevelMaps.LEVELS.size(), level.title]


func _on_goal_reached() -> void:
	go_to_level(level_index + 1)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var box := VBoxContainer.new()
	box.position = Vector2(16.0, 12.0)
	box.add_theme_constant_override("separation", 2)
	layer.add_child(box)
	_title = _hud_label(box, 18, 0.85)
	_help = _hud_label(box, 13, 0.55)
	_help.text = HELP
	_debug = _hud_label(box, 13, 0.8)
	_debug.visible = false
	_hearts = Hearts.new()
	_hearts.custom_minimum_size = Vector2(160.0, 22.0)
	box.add_child(_hearts)
	box.move_child(_hearts, 1)


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
