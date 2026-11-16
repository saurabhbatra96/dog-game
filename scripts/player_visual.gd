extends OutlinedArt
## Placeholder art for the player, drawn from shapes and animated in code:
## dark hair, beard, glasses, white tank top, navy shorts.
## Swap this node for a sprite or skeleton once real art exists.

const C_SKIN := Color("c48d66")
const C_SKIN_FAR := Color("a9744f")
const C_HAIR := Color("231d1b")
const C_TANK := Color("f6f3ec")
const C_SHORTS := Color("303b57")
const C_SHORTS_FAR := Color("242d45")
const C_SHOE := Color("3b3836")
const C_LENS := Color("d5e6ea")

@onready var player := get_parent() as Player

var _squash := Vector2(1.0, 0.0)  # x = vertical scale, y = its velocity
var _phase := 0.0


func _ready() -> void:
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)


func _on_jumped() -> void:
	_squash.y += 5.5


func _on_landed(impact: float) -> void:
	_squash.y -= clampf(impact / 120.0, 1.5, 7.0)


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	if player.is_on_floor():
		_phase += absf(player.velocity.x) * delta * 0.075
	_squash.y += (1.0 - _squash.x) * 320.0 * delta
	_squash.y *= exp(-13.0 * delta)
	_squash.x = clampf(_squash.x + _squash.y * delta, 0.6, 1.45)
	queue_redraw()


func _draw() -> void:
	var on_floor := player.is_on_floor()
	var f := float(player.facing)
	var run := clampf(absf(player.velocity.x) / player.max_speed, 0.0, 1.0) if on_floor else 0.0
	var sy := _squash.x
	var sx := 1.0 + (1.0 - sy) * 0.7

	if on_floor:
		Shapes.ellipse(self, Vector2(0.0, 0.5), 11.0 * sx, 2.4, Color(0, 0, 0, 0.22))

	# Everything below is drawn facing right, then flipped to match facing.
	var lean := clampf(player.velocity.x * f * 0.0004, -0.12, 0.12)
	draw_set_transform_matrix(Transform2D.IDENTITY.scaled(Vector2(f * sx, sy)) * Transform2D(lean, Vector2.ZERO))
	var bob := sin(_phase * 2.0) * 1.2 * run
	var air := clampf(player.velocity.y / 400.0, -1.0, 1.0) * 0.5 + 0.5
	for pass_index in 2:
		outline = pass_index == 0
		_figure(on_floor, run, bob, air)
	outline = false
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _figure(on_floor: bool, run: float, bob: float, air: float) -> void:
	_arm(on_floor, run, bob, air, false)

	# Legs: far one first. Shorts cover the thigh, the shin is bare.
	for i in 2:
		var near := i == 1
		var hip := Vector2(-2.5 + 4.0 * i, -15.0 + bob)
		var foot: Vector2
		if on_floor:
			var p := _phase + PI * i
			foot = Vector2(hip.x + sin(p) * 8.0 * run, -maxf(cos(p), 0.0) * 5.0 * run - 2.0)
		else:
			var tucked := Vector2(hip.x - 3.0 + (i * 2 - 1) * 2.0, -7.0)
			var reaching := Vector2(hip.x + (i * 2 - 1) * 2.5, -1.0)
			foot = tucked.lerp(reaching, air)
		var knee := hip.lerp(foot, 0.5)
		limb(knee, foot, 4.2, C_SKIN if near else C_SKIN_FAR)
		limb(hip, knee, 5.8, C_SHORTS if near else C_SHORTS_FAR)
		blob(foot + Vector2(1.2, 0.0), 2.6, C_SHOE)

	# Tank top and the top of the shorts.
	box(Rect2(-7.5, -34.0 + bob, 15.0, 15.0), 4.5, C_TANK)
	box(Rect2(-7.5, -21.5 + bob, 15.0, 7.5), 3.0, C_SHORTS)

	_arm(on_floor, run, bob, air, true)

	# Head: hair behind, face in front, then beard and glasses.
	var head := Vector2(1.0, -41.5 + bob)
	blob(head + Vector2(-1.2, -1.4), 8.0, C_HAIR)
	blob(head + Vector2(1.0, 1.0), 6.8, C_SKIN)
	if outline:
		return
	draw_circle(head + Vector2(1.8, 4.0), 4.9, C_HAIR, true, -1.0, Shapes.AA)
	draw_circle(head + Vector2(2.0, -0.6), 4.9, C_SKIN, true, -1.0, Shapes.AA)
	draw_circle(head + Vector2(-2.8, 0.8), 1.7, C_SKIN_FAR, true, -1.0, Shapes.AA)
	draw_rect(Rect2(head + Vector2(-2.4, -2.2), Vector2(5.4, 1.4)), C_HAIR)
	draw_rect(Rect2(head + Vector2(2.6, -3.6), Vector2(5.4, 4.8)), C_HAIR)
	draw_rect(Rect2(head + Vector2(3.8, -2.4), Vector2(3.0, 2.6)), C_LENS)


func _arm(on_floor: bool, run: float, bob: float, air: float, near: bool) -> void:
	var shoulder := Vector2(-0.5 if near else 1.5, -30.5 + bob)
	var hand: Vector2
	if on_floor:
		# Each arm swings opposite to the leg on its side.
		var p := _phase + (0.0 if near else PI)
		hand = shoulder + Vector2(sin(p) * 7.0 * run, 10.5 - absf(sin(p)) * 2.0 * run)
	else:
		var up := Vector2(-5.0, -8.0) if near else Vector2(4.0, -7.0)
		var out := Vector2(6.0, 2.0) if near else Vector2(-5.0, 3.0)
		hand = shoulder + up.lerp(out, air)
	var color := C_SKIN if near else C_SKIN_FAR
	limb(shoulder, hand, 4.0, color)
	blob(hand, 2.1, color)
