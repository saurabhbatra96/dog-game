class_name CameraRig
extends Node
## Camera for the low-resolution world view.
##
## The world is drawn into a small SubViewport and scaled up with hard pixels.
## Scrolling a small picture one whole pixel at a time looks jerky, so the rig
## moves the picture in whole pixels and slides the enlarged result by the
## left-over fraction. The art stays chunky and the scrolling stays smooth.

@export_group("Look")
## World pixels visible from top to bottom.
@export var view_height := 480.0
## World pixels per drawn pixel. 1 is fine-grained, 2 is very chunky.
@export var pixel_size := 4.0 / 3.0

@export_group("Follow")
## How far the view shifts in the direction the player is running.
@export var look_ahead := 70.0
@export var look_ahead_speed := 2.2
@export var smooth_x := 9.0
@export var smooth_y := 6.0
## 0 ignores the dog, 0.5 centres the view between player and dog.
@export var dog_pull := 0.18
@export var vertical_offset := -44.0
## A jump has to rise this far above the last ground before the view follows it up.
@export var jump_window := 130.0

var target: Player
var dog: Dog
var bounds := Rect2()
var world: SubViewport
var view: SubViewportContainer

## Where the view is centred this frame, in world pixels.
var view_center := Vector2.ZERO
## How much of the world is visible, in world pixels.
var view_size := Vector2(854.0, 480.0)

var _pos := Vector2.ZERO
var _prev := Vector2.ZERO
var _ahead := 0.0
var _ground_y := 0.0


func _ready() -> void:
	# Run before anything that reads view_center this frame.
	process_priority = -50


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_prev = _pos
	var want := _focus(delta)
	_pos.x = lerpf(_pos.x, want.x, 1.0 - exp(-smooth_x * delta))
	_pos.y = lerpf(_pos.y, want.y, 1.0 - exp(-smooth_y * delta))


func _process(_delta: float) -> void:
	_apply()


func snap() -> void:
	if target == null:
		return
	_ahead = 0.0
	_ground_y = target.global_position.y
	_pos = _focus(0.0)
	_prev = _pos
	_apply()


func _focus(delta: float) -> Vector2:
	var pos := target.global_position
	if absf(target.velocity.x) > 60.0:
		_ahead = lerpf(_ahead, target.facing * look_ahead, 1.0 - exp(-look_ahead_speed * delta))

	if target.is_on_floor():
		_ground_y = pos.y
	var y := _ground_y
	if pos.y > y:
		y = pos.y
	elif pos.y < y - jump_window:
		y = pos.y + jump_window

	var focus := Vector2(pos.x + _ahead, y + vertical_offset)
	if dog != null and dog.act != Dog.Act.RESCUE:
		var to_dog := dog.global_position + Vector2(0.0, vertical_offset) - focus
		if to_dog.length() < 420.0:
			focus += to_dog * dog_pull

	if bounds.size.x > 0.0:
		var half := view_size * 0.5
		if bounds.size.x > view_size.x:
			focus.x = clampf(focus.x, bounds.position.x + half.x, bounds.end.x - half.x)
		focus.y = minf(focus.y, bounds.end.y - half.y)
	return focus


func _apply() -> void:
	if world == null or view == null:
		return
	var screen := get_viewport().get_visible_rect().size
	var rows := maxi(roundi(view_height / pixel_size), 2)
	var upscale := screen.y / float(rows)
	var cols := ceili(screen.x / upscale)
	cols += cols % 2
	# One spare pixel on every side leaves room for the sub-pixel slide.
	var size := Vector2i(cols + 2, rows + 2)
	if world.size != size:
		world.size = size
	view_size = Vector2(cols, rows) * pixel_size
	view_center = _prev.lerp(_pos, Engine.get_physics_interpolation_fraction())

	var zoom := 1.0 / pixel_size
	var exact := view_center * zoom
	var whole := exact.round()
	world.canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, Vector2(size) * 0.5 - whole)
	view.scale = Vector2(upscale, upscale)
	view.position = (Vector2(-1.0, -1.0) - (exact - whole)) * upscale \
			+ Vector2((screen.x - cols * upscale) * 0.5, 0.0)
