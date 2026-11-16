extends Node2D
## Loads the grey-box levels, wires player, dog and camera together, and draws
## the on-screen help and debug readout.

const HELP := "Move  A/D or arrows     Jump  Space     Call dog  E     Pet dog  F\nRestart  R     Levels  [ ]     Dog mood  1-4 (0 auto)     Debug  Tab"

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


func _ready() -> void:
	# The world is drawn small and scaled up with hard pixels (see camera.gd).
	view.stretch = false
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.snap_2d_transforms_to_pixel = true
	world.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	world.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	dog.player = player
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
	if Input.is_action_just_pressed("pet_dog"):
		dog.pet()
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
	dog.reset(level.dog_spawn)
	dog.kill_y = level.kill_y
	backdrop.set_level(level.player_spawn)
	camera.bounds = level.bounds
	camera.snap()
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


func _hud_label(parent: Node, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.17, 0.15, 0.13, alpha))
	parent.add_child(label)
	return label
