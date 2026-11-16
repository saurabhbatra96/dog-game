extends OutlinedArt
## Placeholder art for the player, drawn from shapes and animated in code:
## dark hair, beard, glasses, white tank top, navy shorts, and a red tie.
## A little expression goes a long way at this size: brows and mouth change
## when he is hurt, towed, swinging, or fussing over the dog.
## Swap this node for a sprite or skeleton once real art exists.

enum Mood { NEUTRAL, HAPPY, HURT, SURPRISED, FIERCE }

const C_SKIN := Color("c48d66")
const C_SKIN_FAR := Color("a9744f")
const C_HAIR := Color("231d1b")
const C_TANK := Color("f6f3ec")
const C_SHORTS := Color("303b57")
const C_SHORTS_FAR := Color("242d45")
const C_SHOE := Color("3b3836")
const C_LENS := Color("d5e6ea")
const C_TIE := Color("d8433f")
const C_TIE_DARK := Color("a82f33")
const C_TEETH := Color("fffaf0")
const C_MOUTH := Color("c9605f")

@onready var player := get_parent() as Player

var _squash := Vector2(1.0, 0.0)  # x = vertical scale, y = its velocity
var _phase := 0.0
var _t := 0.0
var _kneel := 0.0
var _joy := 0.0


func _ready() -> void:
	grow = 1.6
	player.jumped.connect(_on_jumped)
	player.landed.connect(_on_landed)
	player.hurt.connect(_on_hurt)


func _on_jumped() -> void:
	_squash.y += 5.5


func _on_landed(impact: float) -> void:
	_squash.y -= clampf(impact / 120.0, 1.5, 7.0)


func _on_hurt() -> void:
	_squash.y -= 4.0


func mood() -> Mood:
	if player.invulnerable > player.hurt_safety - 0.55:
		return Mood.HURT
	if player.dragged:
		return Mood.SURPRISED
	if player.attack_time > 0.0:
		return Mood.FIERCE
	if _joy > 0.0:
		return Mood.HAPPY
	return Mood.NEUTRAL


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	_t += delta
	if player.is_on_floor():
		_phase += absf(player.velocity.x) * delta * 0.075
	_squash.y += (1.0 - _squash.x) * 320.0 * delta
	_squash.y *= exp(-13.0 * delta)
	_squash.x = clampf(_squash.x + _squash.y * delta, 0.6, 1.45)
	_kneel = lerpf(_kneel, 1.0 if player.petting > 0.0 else 0.0, 1.0 - exp(-12.0 * delta))
	# A smile lingers a moment after the petting stops.
	_joy = 1.2 if player.petting > 0.0 else maxf(_joy - delta, 0.0)
	# Flicker while safe from further hits.
	visible = player.invulnerable <= 0.0 or fmod(_t, 0.12) < 0.07
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
	if player.dragged:
		lean += 0.22
	if player.dashing > 0.0:
		lean += 0.3
	var xf := Transform2D.IDENTITY.scaled(Vector2(f * sx, sy)) * Transform2D(lean, Vector2.ZERO)
	draw_set_transform_matrix(xf)
	var bob := sin(_phase * 2.0) * 1.2 * run + _kneel * 7.0
	var air := clampf(player.velocity.y / 400.0, -1.0, 1.0) * 0.5 + 0.5
	for pass_index in 2:
		outline = pass_index == 0
		_figure(on_floor, run, bob, air, xf)
	outline = false

	if player.dashing > 0.0:
		for k in 3:
			draw_rect(Rect2(-18.0 - k * 9.0, -34.0 + k * 9.0, 12.0, 2.7), Color(1.0, 1.0, 1.0, 0.7 - k * 0.2))
	if player.attack_time > 0.0:
		_swing(player.attack_time / 0.16, player.attack_dir.y * PI * 0.5)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Where a world-space point lands in the flipped, leaning figure space.
func _to_figure(xf: Transform2D, world: Vector2) -> Vector2:
	return xf.affine_inverse() * to_local(world)


func _figure(on_floor: bool, run: float, bob: float, air: float, xf: Transform2D) -> void:
	_arm(on_floor, run, bob, air, false, xf)

	# Legs: far one first. Shorts cover the thigh, the shin is bare.
	for i in 2:
		var near := i == 1
		var hip := Vector2(-2.5 + 4.0 * i, -15.0 + bob)
		var foot: Vector2
		if on_floor:
			var p := _phase + PI * i
			foot = Vector2(hip.x + sin(p) * 8.0 * run, -maxf(cos(p), 0.0) * 5.0 * run - 2.0)
			foot.x += (4.0 if near else -5.0) * _kneel
		else:
			var tucked := Vector2(hip.x - 3.0 + (i * 2 - 1) * 2.0, -7.0)
			var reaching := Vector2(hip.x + (i * 2 - 1) * 2.5, -1.0)
			foot = tucked.lerp(reaching, air)
		var knee := hip.lerp(foot, 0.5) + Vector2(4.0, 0.0) * _kneel
		limb(knee, foot, 4.2, C_SKIN if near else C_SKIN_FAR)
		limb(hip, knee, 5.8, C_SHORTS if near else C_SHORTS_FAR)
		blob(foot + Vector2(1.2, 0.0), 2.6, C_SHOE)

	# Tank top and the top of the shorts.
	box(Rect2(-7.5, -34.0 + bob, 15.0, 15.0), 4.5, C_TANK)
	box(Rect2(-7.5, -21.5 + bob, 15.0, 7.5), 3.0, C_SHORTS)

	# The tie: hanging loose, or pulled taut toward whoever has hold of it.
	var knot := Vector2(3.5, -32.0 + bob)
	if player.dragged and is_instance_valid(player.tie_holder):
		var grip := _to_figure(xf, player.tie_holder.global_position + Vector2(0.0, -12.0))
		limb(knot, grip, 2.6, C_TIE)
	elif not outline:
		var swing := clampf(-player.velocity.x * player.facing * 0.012, -3.0, 2.0)
		draw_colored_polygon(PackedVector2Array([
			knot + Vector2(-1.4, 0.0), knot + Vector2(1.6, 0.0),
			knot + Vector2(3.0 + swing, 9.0), knot + Vector2(1.0 + swing, 12.0), knot + Vector2(-1.2 + swing, 9.0),
		]), C_TIE)
	if not outline:
		draw_rect(Rect2(knot + Vector2(-1.6, -1.4), Vector2(3.4, 2.8)), C_TIE_DARK)

	_arm(on_floor, run, bob, air, true, xf)

	# Head: hair behind, face in front, then beard, glasses and expression.
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

	var brow := head + Vector2(2.6, -5.6)
	var lips := head + Vector2(3.4, 3.6)
	match mood():
		Mood.HAPPY:
			# Eyes creased shut behind the glasses, and a grin.
			draw_rect(Rect2(head + Vector2(3.8, -1.4), Vector2(3.0, 1.3)), C_HAIR)
			draw_rect(Rect2(lips, Vector2(4.2, 1.5)), C_TEETH)
			draw_rect(Rect2(head + Vector2(0.4, 1.0), Vector2(2.7, 1.4)), Color("e89a86"))
		Mood.HURT:
			draw_line(brow + Vector2(0.0, 1.6), brow + Vector2(5.6, -1.4), C_HAIR, 1.5, Shapes.AA)
			draw_rect(Rect2(lips + Vector2(0.4, -0.6), Vector2(2.8, 3.0)), C_MOUTH)
		Mood.SURPRISED:
			draw_rect(Rect2(brow + Vector2(0.0, -1.8), Vector2(5.6, 1.4)), C_HAIR)
			draw_rect(Rect2(lips + Vector2(0.8, -0.4), Vector2(2.4, 2.6)), C_MOUTH)
		Mood.FIERCE:
			draw_line(brow + Vector2(0.0, -1.4), brow + Vector2(5.8, 1.6), C_HAIR, 1.6, Shapes.AA)
			draw_rect(Rect2(lips, Vector2(3.8, 1.4)), C_TEETH)


func _arm(on_floor: bool, run: float, bob: float, air: float, near: bool, xf: Transform2D) -> void:
	var shoulder := Vector2(-0.5 if near else 1.5, -30.5 + bob)
	var hand: Vector2
	if near and player.attack_time > 0.0:
		# Thrown forward through the swing.
		var through := 1.0 - player.attack_time / 0.16
		hand = shoulder + Vector2(9.0, -7.0).lerp(Vector2(11.0, 6.0), through)
	elif near and _kneel > 0.2 and is_instance_valid(player.tie_holder):
		# Reaching out to ruffle the dog, wherever it is.
		var reach := _to_figure(xf, player.tie_holder.global_position + Vector2(0.0, -15.0)) - shoulder
		hand = shoulder + reach.limit_length(13.0) + Vector2(sin(_t * 14.0) * 1.6, 0.0)
	elif on_floor:
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


## A crescent of motion in front of the swing.
func _swing(life: float, turn: float) -> void:
	var center := Vector2(2.0, -25.0) + Vector2(cos(turn), sin(turn)) * 2.0
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for k in 9:
		var angle := turn - 1.25 + 2.5 * k / 8.0 + (1.0 - life) * 0.5
		var dir := Vector2(cos(angle), sin(angle))
		var thick := 0.15 + 0.85 * sin(PI * k / 8.0)
		outer.append(center + dir * 30.0)
		inner.append(center + dir * (30.0 - 9.0 * thick))
	inner.reverse()
	draw_colored_polygon(outer + inner, Color(1.0, 1.0, 1.0, 0.85 * life))
