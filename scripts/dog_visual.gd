extends OutlinedArt
## Placeholder art for the dog: a fluffy white spitz with pointed ears and a
## plume tail, drawn from shapes. Nothing here is keyframed. Ears, tail, head
## and body are driven by springs and by what the dog is doing, which is what
## makes it read as alive before any real art exists.

const LEG := 9.0
const C_FUR := Color("fdfaf3")
const C_FUR_SHADE := Color("e0d6c6")
const C_EAR_INNER := Color("f2a79e")
const C_DARK := Color("2b2522")
const C_TONGUE := Color("ee7f86")
const C_HEART := Color("e2574c")
const C_BUBBLE := Color("fffdf8")
const TAIL_RADII: Array[float] = [4.0, 5.0, 5.8, 5.0]

@onready var dog := get_parent() as Dog

var _t := 0.0
var _face := 1.0
var _head_face := 1.0
var _sit := 0.0
var _lie := 0.0
var _crouch := 0.0
var _sniff := 0.0
var _tilt := 0.0
var _happy := 0.0
# Springs: x = value, y = velocity.
var _ear := Vector2(0.3, 0.0)
var _tail := Vector2(0.5, 0.0)
var _squash := Vector2(1.0, 0.0)
var _run_phase := 0.0
var _wag_phase := 0.0
var _wag_amp := 0.0
var _blink := 0.0
var _next_blink := 2.0
var _look := Vector2.RIGHT
var _emote_shown := ""
var _emote_pop := 0.0


func _ready() -> void:
	dog.hopped.connect(_on_hopped)
	dog.landed.connect(_on_landed)
	dog.perked.connect(_on_perked)


func _on_hopped() -> void:
	_squash.y += 5.0


func _on_landed(impact: float) -> void:
	_squash.y -= clampf(impact / 110.0, 1.5, 7.0)


func _on_perked() -> void:
	_ear.y -= 10.0
	_squash.y += 2.5


func _spring(s: Vector2, target: float, stiffness: float, damping: float, delta: float) -> Vector2:
	s.y += (target - s.x) * stiffness * delta
	s.y *= exp(-damping * delta)
	s.x += s.y * delta
	return s


func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	_t += delta
	var k := 1.0 - exp(-10.0 * delta)
	_face = move_toward(_face, float(dog.facing), 12.0 * delta)
	var face_sign := 1.0 if _face >= 0.0 else -1.0
	var forward := dog.velocity.x * face_sign

	# Poses blend in and out rather than snapping.
	_sit = lerpf(_sit, 1.0 if dog.act == Dog.Act.SIT else 0.0, k)
	_lie = lerpf(_lie, 1.0 if dog.act == Dog.Act.LIE else 0.0, k * 0.6)
	var crouch_target := 0.0
	if dog.mood == Dog.Mood.WARY:
		crouch_target = 1.0
	elif dog.braced:
		crouch_target = 0.8
	_crouch = lerpf(_crouch, crouch_target, k)
	var sniff_target := 0.0
	if dog.is_sniffing():
		sniff_target = 1.0
	elif dog.act == Dog.Act.WANDER:
		sniff_target = 0.45
	_sniff = lerpf(_sniff, sniff_target, k * 0.8)
	_tilt = lerpf(_tilt, 0.3 if dog.mood == Dog.Mood.CURIOUS else 0.0, k * 0.7)
	_happy = lerpf(_happy, 1.0 if dog.emote == "heart" else 0.0, k)

	if dog.is_on_floor():
		_run_phase += absf(dog.velocity.x) * delta * 0.09

	# Ears and tail: a resting pose per mood, pushed around by motion.
	var ear_target := 0.3
	var tail_target := 0.5
	var wag_amp := 0.18
	var wag_speed := 7.0
	match dog.mood:
		Dog.Mood.EXCITED:
			ear_target = 0.0
			tail_target = 0.3
			wag_amp = 0.5
			wag_speed = 15.0
		Dog.Mood.CURIOUS:
			ear_target = -0.15
			tail_target = 0.2
			wag_amp = 0.05
			wag_speed = 5.0
		Dog.Mood.WARY:
			ear_target = 1.25
			tail_target = 2.3
			wag_amp = 0.0
	if dog.act == Dog.Act.LIE:
		ear_target = 0.7
		tail_target = 1.5
		wag_amp = 0.04
	if dog.emote == "heart":
		wag_amp = 0.65
		wag_speed = 18.0
	ear_target += clampf(forward * 0.0016, -0.3, 0.6) - clampf(dog.velocity.y * 0.0012, -0.5, 0.5)
	tail_target += clampf(forward * 0.0018, -0.2, 0.7) - clampf(dog.velocity.y * 0.001, -0.4, 0.4)
	_ear = _spring(_ear, ear_target, 180.0, 9.0, delta)
	_tail = _spring(_tail, tail_target, 120.0, 7.0, delta)
	_wag_amp = lerpf(_wag_amp, wag_amp, k * 0.5)
	_wag_phase += wag_speed * delta

	_squash = _spring(_squash, 1.0, 320.0, 13.0, delta)
	_squash.x = clampf(_squash.x, 0.55, 1.5)

	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.14
		_next_blink = randf_range(1.6, 4.5)
	_blink = maxf(_blink - delta, 0.0)

	# Head and eyes turn toward whatever the dog is looking at.
	var to_look := dog.look_point - (dog.global_position + Vector2(0.0, -22.0))
	to_look.x *= face_sign
	var head_want := _head_face
	if to_look.x < -14.0:
		head_want = -1.0
	elif to_look.x > 6.0:
		head_want = 1.0
	_head_face = move_toward(_head_face, head_want, 10.0 * delta)
	if to_look.length() > 1.0:
		_look = _look.lerp(to_look.normalized(), k)

	if dog.emote != _emote_shown:
		_emote_shown = dog.emote
		_emote_pop = 0.0
	_emote_pop = minf(_emote_pop + delta * 7.0, 1.0)
	queue_redraw()


func _pivot(angle: float, point: Vector2) -> Transform2D:
	return Transform2D(angle, point) * Transform2D(0.0, -point)


func _draw() -> void:
	if dog.act == Dog.Act.RESCUE:
		for pass_index in 2:
			outline = pass_index == 0
			_draw_rescue()
		outline = false
		return

	var on_floor := dog.is_on_floor()
	var run := clampf(absf(dog.velocity.x) / 220.0, 0.0, 1.0) if on_floor else 0.0
	var leg := LEG * (1.0 - 0.8 * _lie) - 2.5 * _crouch
	var flip := _face
	if absf(flip) < 0.15:
		flip = 0.15 if flip >= 0.0 else -0.15
	var face_sign := 1.0 if flip >= 0.0 else -1.0
	var forward := dog.velocity.x * face_sign
	var sy := _squash.x
	var sx := 1.0 + (1.0 - sy) * 0.7

	if on_floor:
		Shapes.ellipse(self, Vector2(0.0, 0.5), 15.0 * sx, 2.6, Color(0, 0, 0, 0.22))

	# root: flip and squash about the feet. rel: body pose on top of that.
	var root := Transform2D.IDENTITY.scaled(Vector2(flip * sx, sy))
	var pitch := 0.12 * _sniff
	if on_floor:
		pitch += clampf(forward * 0.00022, -0.08, 0.08)
	else:
		pitch += clampf(dog.velocity.y * 0.0007, -0.35, 0.35)
	var bob := sin(_run_phase * 2.0) * 1.4 * run
	var rel := _pivot(pitch, Vector2(0.0, -leg - 6.0)) \
			* Transform2D(0.0, Vector2(0.0, bob)) \
			* _pivot(-0.4 * _sit, Vector2(8.0, -leg))

	# Head placement.
	var hf := _head_face
	if absf(hf) < 0.2:
		hf = 0.2 if hf >= 0.0 else -0.2
	var hf_sign := 1.0 if hf >= 0.0 else -1.0
	var look := Vector2(_look.x * hf_sign, _look.y)
	var head := rel * Vector2(10.0, -leg - 9.0) + Vector2(5.0, -6.5)
	head += Vector2(5.0, 15.0 + sin(_t * 22.0) * 0.8) * _sniff
	head += Vector2(2.0, 7.0) * _lie * (1.0 - _sniff)
	head += Vector2(-1.5, 2.5) * _crouch
	head += look * 1.6
	var head_rot := (clampf(look.y, -1.0, 1.0) * 0.35 - _tilt + 0.5 * _sniff) * hf_sign
	var head_xf := root * Transform2D(head_rot, head) * Transform2D.IDENTITY.scaled(Vector2(hf, 1.0))

	for pass_index in 2:
		outline = pass_index == 0
		_draw_dog(root, rel, head_xf, look, leg, run)
	outline = false

	# Thought bubble, unflipped.
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if _emote_shown != "":
		_draw_emote(root * head + Vector2(5.0 * face_sign, -21.0))
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_dog(root: Transform2D, rel: Transform2D, head_xf: Transform2D, look: Vector2, leg: float, run: float) -> void:
	var rear_hip := Vector2(-9.5, -leg - 1.5)
	var front_hip := Vector2(8.5, -leg - 1.5)

	# Far legs.
	_leg(root, rel, rear_hip + Vector2(2.5, 0.0), PI, false, C_FUR_SHADE, leg, run)
	_leg(root, rel, front_hip + Vector2(2.5, 0.0), 0.0, true, C_FUR_SHADE, leg, run)

	# Tail: a plume that curls forward over the back, and straightens out
	# when it streams behind a run or tucks down in fear.
	draw_set_transform_matrix(root * rel)
	var wag := sin(_wag_phase) * _wag_amp
	var curl := lerpf(0.55, 0.06, clampf((_tail.x - 0.4) / 1.4, 0.0, 1.0))
	var p := Vector2(-11.5, -leg - 8.5)
	for i in 4:
		var angle := _tail.x + wag * (1.0 + 0.4 * i) - curl * i
		p += Vector2(-sin(angle), -cos(angle)) * 4.6
		blob(p, TAIL_RADII[i], C_FUR_SHADE if i == 0 else C_FUR)

	# Body, with a fluffy rump and chest.
	box(Rect2(-14.0, -leg - 12.0, 27.0, 12.5), 5.5, C_FUR)
	blob(Vector2(-10.5, -leg - 6.5), 6.3, C_FUR)
	blob(Vector2(8.5, -leg - 6.0), 7.2, C_FUR)
	blob(Vector2(10.5, -leg - 1.0), 4.0, C_FUR)
	blob(Vector2(-4.0, -leg + 0.3), 2.6, C_FUR_SHADE)
	blob(Vector2(2.0, -leg + 0.5), 2.8, C_FUR_SHADE)
	if not outline:
		box(Rect2(-9.0, -leg - 2.8, 15.0, 3.0), 1.5, C_FUR_SHADE)

	# Near legs.
	_leg(root, rel, rear_hip, 0.0, false, C_FUR, leg, run)
	_leg(root, rel, front_hip, PI, true, C_FUR, leg, run)

	# Head.
	draw_set_transform_matrix(head_xf)
	_ear_shape(Vector2(1.8, -5.5), -_ear.x * 0.85 + 0.12, C_FUR_SHADE, false)
	blob(Vector2(-3.5, 3.0), 6.2, C_FUR)
	box(Rect2(-7.5, -6.5, 15.0, 13.0), 5.0, C_FUR)
	_ear_shape(Vector2(-3.4, -5.5), -_ear.x, C_FUR, true)
	box(Rect2(5.0, 0.0, 6.8, 5.2), 2.4, C_FUR)
	if outline:
		return

	draw_circle(Vector2(11.4, 1.6), 1.6, C_DARK, true, -1.0, Shapes.AA)
	var panting := _happy > 0.5 or (dog.mood == Dog.Mood.EXCITED and absf(dog.velocity.x) > 60.0)
	if panting:
		draw_rect(Rect2(6.6, 4.4, 4.4, 1.4), C_DARK)
		draw_rect(Rect2(7.6, 5.2, 2.8, 3.0 + sin(_t * 14.0) * 0.7), C_TONGUE)

	var eye_r := 1.6
	match dog.mood:
		Dog.Mood.CURIOUS:
			eye_r = 1.9
		Dog.Mood.WARY:
			eye_r = 1.3
	var closed := _blink > 0.0 or dog.act == Dog.Act.LIE
	for ex: float in [0.4, 4.4]:
		var eye := Vector2(ex, -1.4) + look * 0.9
		if _happy > 0.5:
			draw_arc(eye + Vector2(0.0, 1.0), 1.5, PI, TAU, 8, C_DARK, 1.3, Shapes.AA)
		elif closed:
			draw_rect(Rect2(eye.x - 1.5, eye.y, 3.0, 1.3), C_DARK)
		else:
			draw_circle(eye, eye_r, C_DARK, true, -1.0, Shapes.AA)


func _leg(root: Transform2D, rel: Transform2D, hip_body: Vector2, phase: float, front: bool, color: Color, leg: float, run: float) -> void:
	var hip := rel * hip_body
	var foot: Vector2
	if dog.is_on_floor():
		var p := _run_phase + phase
		foot = Vector2(hip_body.x + sin(p) * 7.0 * run, -maxf(cos(p), 0.0) * 4.0 * run)
		if not front:
			foot.x += 5.0 * _sit
		foot.x += 6.0 * _lie
	else:
		var v := clampf(dog.velocity.y / 350.0, -1.0, 1.0) * 0.5 + 0.5
		var reach := Vector2(6.0, leg * 0.8) if front else Vector2(-6.0, leg * 0.8)
		var tuck := Vector2(2.0, leg) if front else Vector2(-1.0, leg)
		foot = rel * (hip_body + reach.lerp(tuck, v)) + Vector2(0.0, 2.0)
	var paw := foot + Vector2(0.0, -2.0)
	draw_set_transform_matrix(root)
	limb(hip, paw, 4.2, color)
	blob(paw + Vector2(0.8, 0.0), 2.4, color)


func _ear_shape(base: Vector2, rot: float, color: Color, with_inner: bool) -> void:
	var up := Vector2(sin(rot), -cos(rot))
	var side := Vector2(cos(rot), sin(rot))
	tri(base - side * 3.0, base + side * 3.0, base + up * 9.0, color)
	if with_inner and not outline:
		var inner := base + up * 1.2
		draw_colored_polygon(PackedVector2Array([inner - side * 1.5, inner + side * 1.5, inner + up * 5.6]), C_EAR_INNER)


func _draw_emote(at: Vector2) -> void:
	var s := lerpf(0.3, 1.0, _emote_pop) + sin(_emote_pop * PI) * 0.22
	draw_set_transform(at, 0.0, Vector2(s, s))
	draw_circle(Vector2.ZERO, 10.4, LINE, true, -1.0, Shapes.AA)
	draw_colored_polygon(PackedVector2Array([Vector2(-3.0, 6.0), Vector2(3.0, 6.0), Vector2(-1.0, 13.0)]), LINE)
	draw_circle(Vector2.ZERO, 9.0, C_BUBBLE, true, -1.0, Shapes.AA)
	match _emote_shown:
		"heart":
			draw_circle(Vector2(-2.3, -1.6), 2.7, C_HEART, true, -1.0, Shapes.AA)
			draw_circle(Vector2(2.3, -1.6), 2.7, C_HEART, true, -1.0, Shapes.AA)
			draw_colored_polygon(PackedVector2Array([Vector2(-4.7, -0.4), Vector2(4.7, -0.4), Vector2(0.0, 5.4)]), C_HEART)
		"...":
			for i in 3:
				draw_rect(Rect2(-5.4 + 4.0 * i, -0.8, 2.7, 2.7), C_DARK)
		_:
			# Draw text large and scale it down, so it stays crisp when zoomed.
			var font := ThemeDB.fallback_font
			var size := 44
			var text_scale := s * 0.3
			var width := font.get_string_size(_emote_shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
			draw_set_transform(at, 0.0, Vector2(text_scale, text_scale))
			draw_string(font, Vector2(-width * 0.5, 16.0), _emote_shown, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, C_DARK)


## When the dog cannot find a way to the player it bounds over as a blur of fur.
func _draw_rescue() -> void:
	var center := Vector2(0.0, -11.0)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	for i in 3:
		var angle := _t * 11.0 + TAU * i / 3.0
		blob(center + Vector2(cos(angle), sin(angle)) * 9.0, 4.2, C_FUR_SHADE)
	blob(center, 8.5, C_FUR)
	if not outline:
		draw_circle(center + Vector2(-2.6, -1.0), 1.4, C_DARK, true, -1.0, Shapes.AA)
		draw_circle(center + Vector2(2.6, -1.0), 1.4, C_DARK, true, -1.0, Shapes.AA)
