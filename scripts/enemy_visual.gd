class_name EnemyVisual
extends OutlinedArt
## Placeholder art for the bramble, drawn from shapes. Its pose tells you
## what it is about to do: it shakes before a charge, stretches during one,
## droops while resting, and stares wide-eyed when the dog distracts it.

const C_BODY := Color("6d4a66")
const C_BELLY := Color("8a6382")
const C_THORN := Color("9a6a48")
const C_EYE := Color("fff6e6")
const C_DARK := Color("2b2522")
const C_PIP := Color("e2574c")

@onready var enemy := get_parent() as Enemy

var _t := 0.0
var _walk := 0.0


func _process(delta: float) -> void:
	_t += delta
	if enemy.is_on_floor():
		_walk += absf(enemy.velocity.x) * delta * 0.12
	queue_redraw()


func _draw() -> void:
	var s := enemy.state
	if s == Enemy.State.DEAD:
		# A puff of leaves.
		var age := clampf(enemy.state_time / 0.45, 0.0, 1.0)
		for k in 7:
			var angle := TAU * k / 7.0 + 0.4
			var at := Vector2(0.0, -10.0) + Vector2(cos(angle), sin(angle)) * (6.0 + age * 20.0)
			draw_rect(Rect2(at, Vector2(4.0, 4.0) * (1.0 - age * 0.6)), Color(C_BELLY if k % 2 == 0 else C_THORN, 1.0 - age))
		return

	var stretch := Vector2.ONE
	var shake := 0.0
	match s:
		Enemy.State.WINDUP:
			shake = sin(_t * 70.0) * 1.3
			stretch = Vector2(1.12, 0.86)
		Enemy.State.DASH:
			stretch = Vector2(1.25, 0.82)
		Enemy.State.REST:
			stretch = Vector2(1.05, 0.92 + sin(_t * 9.0) * 0.04)
		Enemy.State.STUN:
			stretch = Vector2(0.9, 1.1)

	if enemy.is_on_floor():
		Shapes.ellipse(self, Vector2(0.0, 0.5), 13.0, 2.4, Color(0, 0, 0, 0.22))
	draw_set_transform_matrix(Transform2D(0.0, Vector2(shake, 0.0)) * Transform2D.IDENTITY.scaled(Vector2(enemy.facing * stretch.x, stretch.y)))
	for pass_index in 2:
		outline = pass_index == 0
		_body(s)
	outline = false

	# Above its head: a question mark while distracted, hit points once hurt.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if s == Enemy.State.DISTRACTED:
		var font := ThemeDB.fallback_font
		draw_set_transform(Vector2(0.0, -30.0 + sin(_t * 6.0) * 1.5), 0.0, Vector2(0.3, 0.3))
		draw_string(font, Vector2(-11.0, 16.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 46, C_EYE)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	elif enemy.hp < enemy.max_hp:
		for k in enemy.max_hp:
			draw_rect(Rect2(-enemy.max_hp * 2.5 + k * 5.0, -29.0, 4.0, 2.7), C_PIP if k < enemy.hp else Color(C_DARK, 0.5))


func _body(s: Enemy.State) -> void:
	var white := enemy.flash > 0.0
	var body := C_EYE if white else C_BODY
	# Feet.
	for k in 2:
		var step := sin(_walk + PI * k) * 3.0
		blob(Vector2(-5.0 + k * 10.0 + step, -2.0), 2.6, C_DARK if not white else C_EYE)
	# Thorns along the back.
	for k in 5:
		var angle := -PI * 0.95 + k * 0.42
		var root := Vector2(-1.0, -10.0) + Vector2(cos(angle), sin(angle)) * 8.0
		var side := Vector2(-sin(angle), cos(angle)) * 2.6
		tri(root - side, root + side, root + Vector2(cos(angle), sin(angle)) * 7.5, C_THORN if not white else C_EYE)
	blob(Vector2(0.0, -10.0), 10.0, body)
	if outline:
		return
	if not white:
		draw_circle(Vector2(2.0, -7.0), 6.0, C_BELLY, true, -1.0, Shapes.AA)
	# Face.
	var eye := Vector2(5.0, -12.0)
	if s == Enemy.State.DISTRACTED:
		draw_circle(eye, 3.4, C_EYE, true, -1.0, Shapes.AA)
		draw_circle(eye + Vector2(0.6, 0.0), 1.2, C_DARK, true, -1.0, Shapes.AA)
	elif s == Enemy.State.REST or s == Enemy.State.STUN:
		draw_rect(Rect2(eye.x - 2.5, eye.y, 5.0, 1.4), C_DARK)
		draw_rect(Rect2(9.0, -16.0 + fposmod(_t * 14.0, 8.0), 1.6, 2.7), Color("9fd6ea"))
	else:
		draw_circle(eye, 2.8, C_EYE, true, -1.0, Shapes.AA)
		draw_circle(eye + Vector2(1.0, 0.4), 1.4, C_DARK, true, -1.0, Shapes.AA)
		# An angry brow.
		draw_line(eye + Vector2(-3.5, -4.0), eye + Vector2(3.0, -1.6), C_DARK, 1.6, Shapes.AA)
	draw_rect(Rect2(6.0, -6.0, 4.0, 1.4), C_DARK)
