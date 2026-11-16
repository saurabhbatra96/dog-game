class_name Backdrop
extends Node2D
## The world behind the level, drawn entirely from shapes and placed by a
## repeatable hash, so it is endless and needs no image files.
##
## Back to front: sky with drifting clouds and birds, snow-capped mountains,
## a far treeline with castles on hills, a middle wood that opens onto lakes,
## ruins and cottages, shafts of sunlight, and a near row of big trees.

const SKY_TOP := Color("b9dbe4")
const SKY_BOTTOM := Color("f6edcf")
const SUN := Color("fff8dc")
## Where the sun sits, as a fraction of the screen.
const SUN_AT := Vector2(0.74, 0.24)

var camera: CameraRig
## Camera height at which every layer sits at its natural height.
var reference_y := 0.0
## World height of the level's main ground.
var ground_y := 0.0

var _sky: SkyBands
var _rays: Rays
var _layers: Array[Layer] = []
var _t := 0.0


func _ready() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky = SkyBands.new()
	sky_layer.add_child(_sky)

	# factor: 0 is pinned to the screen, 1 moves with the level.
	_add(Mountains.new(), 0.04, -58.0)

	var far := Woods.new()
	far.features = Woods.FAR
	far.animated = true
	far.setup(54.0, 120.0, 0.0, Color("b9d3b8"), Color("abc8ad"), Color("abc8ad"), 11)
	_add(far, 0.12, -46.0)

	var mid := Woods.new()
	mid.features = Woods.MID
	mid.animated = true
	mid.setup(96.0, 190.0, 0.25, Color("8cb58f"), Color("79a581"), Color("7f9a80"), 23)
	_add(mid, 0.3, -14.0)

	_rays = Rays.new()
	add_child(_rays)

	var near := Woods.new()
	near.setup(150.0, 290.0, 0.5, Color("568c69"), Color("467a5b"), Color("5a4b3f"), 37)
	_add(near, 0.55, 64.0)


func _add(layer: Layer, factor: float, base_offset: float) -> void:
	layer.factor = factor
	layer.base_offset = base_offset
	layer.mist = Color(SKY_BOTTOM, 0.32 * (1.0 - factor))
	add_child(layer)
	_layers.append(layer)


func set_level(spawn: Vector2) -> void:
	ground_y = spawn.y
	reference_y = spawn.y - 44.0


func _process(delta: float) -> void:
	if camera == null or camera.world == null:
		return
	_t += delta
	var center := camera.view_center
	var half := camera.view_size * 0.5
	_sky.update(Vector2(camera.world.size), center.x, _t)
	_rays.update(camera, _t)
	for layer in _layers:
		layer.position = Vector2(center.x * (1.0 - layer.factor), (center.y - reference_y) * (1.0 - layer.factor))
		layer.base_y = ground_y + layer.base_offset
		layer.t = _t
		var left := center.x * layer.factor - half.x
		layer.sun_x = left + camera.view_size.x * SUN_AT.x
		layer.set_view(left, left + camera.view_size.x)


## Repeatable pseudo-random number in 0..1 for item number i.
static func rand(i: int, salt: int) -> float:
	var h := (i * 73856093) ^ (salt * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


# --- sky ---------------------------------------------------------------------

class SkyBands extends Node2D:
	const CLOUD := Color("f8faf4")
	const CLOUD_SHADE := Color("dfeae6")
	var _size := Vector2(642.0, 362.0)
	var _cam_x := 0.0
	var _t := 0.0

	func update(size: Vector2, cam_x: float, t: float) -> void:
		_size = size
		_cam_x = cam_x
		_t = t
		queue_redraw()

	func _draw() -> void:
		# Stepped bands instead of a smooth gradient, to suit the pixel look.
		const BANDS := 10
		var band := ceilf(_size.y / BANDS)
		for i in BANDS:
			var mix := float(i) / float(BANDS - 1)
			draw_rect(Rect2(0.0, i * band, _size.x, band + 1.0), Backdrop.SKY_TOP.lerp(Backdrop.SKY_BOTTOM, mix))

		var sun := _size * Backdrop.SUN_AT
		draw_circle(sun, _size.y * 0.2, Color(Backdrop.SUN, 0.22))
		draw_circle(sun, _size.y * 0.15, Color(Backdrop.SUN, 0.3))
		draw_circle(sun, _size.y * 0.095, Backdrop.SUN)

		# Clouds drift on the wind and barely react to the camera.
		var span := _size.x + 260.0
		for k in 6:
			var speed := 2.0 + Backdrop.rand(k, 62) * 3.0
			var x := fposmod(Backdrop.rand(k, 61) * span + _t * speed - _cam_x * 0.02, span) - 130.0
			var y := _size.y * (0.05 + 0.3 * Backdrop.rand(k, 63))
			var s := 0.7 + Backdrop.rand(k, 64) * 0.9
			draw_rect(Rect2(x + 4.0 * s, y + 5.0 * s, 50.0 * s, 4.0 * s), CLOUD_SHADE)
			draw_rect(Rect2(x, y, 58.0 * s, 7.0 * s), CLOUD)
			draw_circle(Vector2(x + 14.0 * s, y), 9.0 * s, CLOUD)
			draw_circle(Vector2(x + 30.0 * s, y - 5.0 * s), 13.0 * s, CLOUD)
			draw_circle(Vector2(x + 45.0 * s, y + 1.0 * s), 8.5 * s, CLOUD)

		# Every so often a small flock crosses the sky.
		var crossing := fposmod(_t, 24.0) / 15.0
		if crossing < 1.0:
			var lead := Vector2(lerpf(-50.0, _size.x + 50.0, crossing), _size.y * 0.2 + sin(crossing * 7.0) * 9.0)
			for k in 5:
				var side := -1.0 if k % 2 == 0 else 1.0
				var row := float((k + 1) / 2)
				var bird := lead + Vector2(-row * 10.0, side * row * 5.0)
				var flap := sin(_t * 9.0 + k * 1.3) * 2.5
				var ink := Color(0.2, 0.22, 0.25, 0.7)
				draw_line(bird, bird + Vector2(-4.0, -1.0 - flap), ink, 1.0)
				draw_line(bird, bird + Vector2(4.0, -1.0 - flap), ink, 1.0)


# --- layers ------------------------------------------------------------------

## A strip of scenery that scrolls slower than the level.
class Layer extends Node2D:
	var factor := 0.3
	var base_offset := 0.0
	## Local height of this layer's ground line.
	var base_y := 0.0
	var mist := Color.TRANSPARENT
	var t := 0.0
	## Local x directly below the sun.
	var sun_x := 0.0
	## Animated layers redraw every frame; still ones only as the view moves on.
	var animated := false
	var x0 := 0.0
	var x1 := 0.0
	var _cell := Vector2i(1, 0)
	var _drawn_base := INF

	func set_view(left: float, right: float) -> void:
		x0 = left
		x1 = right
		var cell := Vector2i(floori(left / 64.0), ceili(right / 64.0))
		if animated or cell != _cell or base_y != _drawn_base:
			_cell = cell
			_drawn_base = base_y
			queue_redraw()

	func ground(color: Color) -> void:
		draw_rect(Rect2(x0 - 200.0, base_y, x1 - x0 + 400.0, 4000.0), color)

	func haze() -> void:
		if mist.a > 0.0:
			draw_rect(Rect2(x0 - 200.0, base_y - 70.0, x1 - x0 + 400.0, 4000.0), mist)


class Mountains extends Layer:
	const ROCK := Color("c2d3d6")
	const ROCK_SHADE := Color("b1c5cb")
	const SNOW := Color("f6f8f3")
	const SNOW_SHADE := Color("dde8ea")
	const SPACING := 150.0

	func _draw() -> void:
		for i in range(floori(x0 / SPACING) - 3, ceili(x1 / SPACING) + 4):
			var x := i * SPACING + (Backdrop.rand(i, 3) - 0.5) * 90.0
			var h := 110.0 + 135.0 * Backdrop.rand(i, 4)
			var half := h * (0.75 + 0.5 * Backdrop.rand(i, 5))
			var top := Vector2(x, base_y - h)
			draw_colored_polygon(PackedVector2Array([top, Vector2(x + half, base_y), Vector2(x - half, base_y)]), ROCK)
			draw_colored_polygon(PackedVector2Array([top, Vector2(x + half, base_y), Vector2(x + half * 0.2, base_y)]), ROCK_SHADE)
			# Snow cap with a ragged lower edge.
			var cap := h * (0.2 + 0.1 * Backdrop.rand(i, 6))
			var w := half * cap / h
			draw_colored_polygon(PackedVector2Array([
				top, Vector2(x + w, top.y + cap), Vector2(x + w * 0.45, top.y + cap * 0.8),
				Vector2(x + w * 0.1, top.y + cap * 1.15), Vector2(x - w * 0.4, top.y + cap * 0.85),
				Vector2(x - w, top.y + cap),
			]), SNOW)
			draw_colored_polygon(PackedVector2Array([top, Vector2(x + w, top.y + cap), Vector2(x + w * 0.45, top.y + cap * 0.8)]), SNOW_SHADE)
		ground(ROCK_SHADE)
		haze()


## Trees, plus whatever landmarks this row is given.
class Woods extends Layer:
	enum { PLAIN, FAR, MID }
	enum { FOREST, LAKE, COTTAGE, RUINS }
	## The middle wood repeats this run of scenes, one per ZONE of width.
	const SCENES: Array[int] = [LAKE, RUINS, COTTAGE, FOREST]
	const ZONE := 620.0
	const CASTLE_EVERY := 1100.0
	const CASTLE_AT := 420.0

	var features := PLAIN
	var spacing := 90.0
	var tree_height := 160.0
	## 0 draws flat silhouettes, higher adds shading.
	var detail := 0.0
	var leaf := Color.WHITE
	var shade := Color.WHITE
	var trunk := Color.WHITE
	var salt := 0

	func setup(p_spacing: float, p_height: float, p_detail: float, p_leaf: Color, p_shade: Color, p_trunk: Color, p_salt: int) -> void:
		spacing = p_spacing
		tree_height = p_height
		detail = p_detail
		leaf = p_leaf
		shade = p_shade
		trunk = p_trunk
		salt = p_salt

	func _scene(zone: int) -> int:
		return SCENES[posmod(zone, SCENES.size())]

	## The stretch of a zone its scene occupies; trees keep out of it.
	func _span(zone: int) -> Vector2:
		var start := zone * ZONE
		match _scene(zone):
			LAKE:
				return Vector2(start + 60.0, start + 560.0)
			COTTAGE:
				return Vector2(start + 170.0, start + 450.0)
			RUINS:
				return Vector2(start + 200.0, start + 420.0)
		return Vector2.ZERO

	func _castle_near(x: float) -> float:
		return roundf((x - CASTLE_AT) / CASTLE_EVERY) * CASTLE_EVERY + CASTLE_AT

	func _kept_clear(x: float, margin: float) -> bool:
		if features == MID:
			var span := _span(floori(x / ZONE))
			return span != Vector2.ZERO and x > span.x - margin and x < span.y + margin
		if features == FAR:
			return absf(x - _castle_near(x)) < 78.0 + margin
		return false

	func _draw() -> void:
		var first_zone := floori((x0 - 100.0) / ZONE)
		var last_zone := floori((x1 + 100.0) / ZONE)

		# Landmarks that sit behind the trees.
		if features == MID:
			for zone in range(first_zone, last_zone + 1):
				if _scene(zone) == LAKE:
					_lake_water(_span(zone))
		elif features == FAR:
			var cx := _castle_near(x0 - 300.0)
			while cx < x1 + 300.0:
				_castle(cx)
				cx += CASTLE_EVERY

		var first := floori(x0 / spacing) - 3
		var last := ceili(x1 / spacing) + 3
		for i in range(first, last + 1):
			var x := i * spacing + (Backdrop.rand(i, salt) - 0.5) * spacing * 0.7
			if _kept_clear(x, 16.0):
				continue
			var h := tree_height * (0.7 + 0.6 * Backdrop.rand(i, salt + 1))
			if Backdrop.rand(i, salt + 2) < 0.55:
				_pine(x, h)
			else:
				_round_tree(x, h)

		# The floor of this row, with a bumpy edge of bushes.
		ground(shade)
		if detail > 0.0:
			# Darker with depth, so a pit reads as a drop and not as ground.
			draw_rect(Rect2(x0 - 200.0, base_y + 56.0, x1 - x0 + 400.0, 4000.0), shade.darkened(0.14))
			draw_rect(Rect2(x0 - 200.0, base_y + 128.0, x1 - x0 + 400.0, 4000.0), shade.darkened(0.28))
		for i in range(first * 3, last * 3 + 1):
			var x := i * spacing / 3.0 + Backdrop.rand(i, salt + 5) * spacing * 0.3
			if features == MID and _kept_clear(x, -6.0):
				continue
			var r := 9.0 + 14.0 * Backdrop.rand(i, salt + 6)
			draw_circle(Vector2(x, base_y + r * 0.35), r, shade)
			if detail > 0.0 and Backdrop.rand(i, salt + 7) < 0.5:
				draw_circle(Vector2(x - r * 0.25, base_y + r * 0.2), r * 0.6, leaf)
		haze()

		# Landmarks in front of the haze.
		if features == MID:
			for zone in range(first_zone, last_zone + 1):
				var span := _span(zone)
				match _scene(zone):
					LAKE:
						_lake_life(span, zone)
					COTTAGE:
						_cottage((span.x + span.y) * 0.5, zone)
					RUINS:
						_ruins((span.x + span.y) * 0.5)

	# --- trees ---

	func _pine(x: float, h: float) -> void:
		var w := h * 0.045 + 2.0
		draw_rect(Rect2(x - w * 0.5, base_y - h * 0.4, w, h * 0.4 + 4.0), trunk)
		for k in 3:
			var top := base_y - h * (0.5 + 0.25 * k) - h * 0.25
			var bottom := base_y - h * (0.2 + 0.25 * k)
			var half := h * 0.24 * (1.0 - 0.22 * k)
			draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, bottom), Vector2(x - half, bottom)]), leaf)
			if detail > 0.0:
				draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + half, bottom), Vector2(x + half * 0.15, bottom)]), shade)

	func _round_tree(x: float, h: float) -> void:
		var w := h * 0.05 + 2.0
		draw_rect(Rect2(x - w * 0.5, base_y - h * 0.6, w, h * 0.6 + 4.0), trunk)
		var r := h * 0.27
		var crown := Vector2(x, base_y - h * 0.72)
		draw_circle(crown + Vector2(r * 0.7, r * 0.35), r * 0.72, shade if detail > 0.0 else leaf)
		draw_circle(crown + Vector2(-r * 0.7, r * 0.4), r * 0.75, leaf)
		draw_circle(crown, r, leaf)
		if detail > 0.0:
			draw_circle(crown + Vector2(r * 0.35, r * 0.3), r * 0.62, shade)
			draw_circle(crown + Vector2(-r * 0.2, -r * 0.15), r * 0.66, leaf)

	# --- castle ---

	func _castle(cx: float) -> void:
		const STONE := Color("a3b8b3")
		const STONE_SHADE := Color("93aaa7")
		const ROOF := Color("8794ad")
		const GLOW := Color("ffe9a6")
		const FLAG := Color("dc8573")
		# A hill for it to stand on.
		draw_circle(Vector2(cx, base_y + 170.0), 232.0, leaf)
		draw_circle(Vector2(cx + 46.0, base_y + 178.0), 232.0, shade)
		var foot := base_y - 56.0

		# Towers behind the wall, tallest in the middle.
		_tower(cx + 24.0, 17.0, 132.0, 38.0, foot, STONE, STONE_SHADE, ROOF, FLAG, 1)
		_tower(cx - 30.0, 15.0, 104.0, 30.0, foot, STONE, STONE_SHADE, ROOF, FLAG, 2)
		# The keep.
		draw_rect(Rect2(cx - 22.0, foot - 90.0, 44.0, 90.0), STONE)
		draw_rect(Rect2(cx + 8.0, foot - 90.0, 14.0, 90.0), STONE_SHADE)
		_battlements(cx - 24.0, cx + 24.0, foot - 90.0, STONE)
		for k in 3:
			draw_rect(Rect2(cx - 13.0 + k * 10.0, foot - 76.0 + (k % 2) * 16.0, 4.0, 7.0), GLOW)
		# Curtain wall and gate.
		draw_rect(Rect2(cx - 70.0, foot - 36.0, 140.0, 40.0), STONE)
		draw_rect(Rect2(cx + 30.0, foot - 36.0, 40.0, 40.0), STONE_SHADE)
		_battlements(cx - 70.0, cx + 70.0, foot - 36.0, STONE)
		draw_rect(Rect2(cx - 13.0, foot - 48.0, 26.0, 50.0), STONE)
		_battlements(cx - 14.0, cx + 14.0, foot - 48.0, STONE)
		draw_circle(Vector2(cx, foot - 18.0), 7.0, STONE_SHADE.darkened(0.25))
		draw_rect(Rect2(cx - 7.0, foot - 18.0, 14.0, 20.0), STONE_SHADE.darkened(0.25))
		for k in 4:
			draw_rect(Rect2(cx - 58.0 + k * 14.0 + (26.0 if k > 1 else 0.0), foot - 24.0, 3.0, 6.0), GLOW)
		# Corner towers in front.
		_tower(cx - 72.0, 21.0, 72.0, 30.0, foot + 2.0, STONE, STONE_SHADE, ROOF, FLAG, 3)
		_tower(cx + 72.0, 23.0, 86.0, 34.0, foot + 2.0, STONE, STONE_SHADE, ROOF, FLAG, 4)

	func _battlements(left: float, right: float, top: float, color: Color) -> void:
		var x := left
		while x < right - 2.0:
			draw_rect(Rect2(x, top - 4.0, 4.0, 4.0), color)
			x += 8.0

	func _tower(x: float, w: float, h: float, roof: float, foot: float, stone: Color, stone_shade: Color, roof_color: Color, flag: Color, n: int) -> void:
		var top := foot - h
		draw_rect(Rect2(x - w * 0.5, top, w, h), stone)
		draw_rect(Rect2(x + w * 0.15, top, w * 0.35, h), stone_shade)
		draw_rect(Rect2(x - w * 0.5 - 2.0, top - 3.0, w + 4.0, 5.0), stone)
		draw_rect(Rect2(x - 1.5, top + 12.0, 3.0, 7.0), Color("ffe9a6"))
		var tip := Vector2(x, top - 3.0 - roof)
		draw_colored_polygon(PackedVector2Array([tip, Vector2(x + w * 0.5 + 4.0, top - 3.0), Vector2(x - w * 0.5 - 4.0, top - 3.0)]), roof_color)
		draw_colored_polygon(PackedVector2Array([tip, Vector2(x + w * 0.5 + 4.0, top - 3.0), Vector2(x + 1.0, top - 3.0)]), roof_color.darkened(0.1))
		# A pennant that ripples in the wind.
		draw_rect(Rect2(tip.x - 0.7, tip.y - 11.0, 1.4, 12.0), stone_shade.darkened(0.2))
		var wave := sin(t * 5.0 + n * 1.7) * 1.8
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(0.7, -11.0), tip + Vector2(6.0, -9.5 + wave * 0.5),
			tip + Vector2(11.0, -8.5 + wave), tip + Vector2(6.0, -6.0 + wave * 0.5), tip + Vector2(0.7, -5.5),
		]), flag)

	# --- lake ---

	func _lake_water(span: Vector2) -> void:
		const WATER: Array[Color] = [Color("d6e9e1"), Color("bcdad6"), Color("a2cbcb"), Color("8abbc0")]
		const DEPTHS: Array[float] = [0.0, 9.0, 22.0, 38.0]
		var top := base_y - 54.0
		var width := span.y - span.x
		for k in 4:
			draw_rect(Rect2(span.x, top + DEPTHS[k], width, 80.0), WATER[k])
		# The far shore, with small trees mirrored in the water.
		var shore := leaf.lerp(Backdrop.SKY_BOTTOM, 0.42)
		draw_rect(Rect2(span.x, top - 4.0, width, 5.0), shore)
		var count := int(width / 15.0)
		for j in count:
			var x := span.x + 6.0 + j * 15.0 + Backdrop.rand(j, 71) * 8.0
			var h := 11.0 + 17.0 * Backdrop.rand(j, 72)
			var half := 4.0 + h * 0.18
			draw_colored_polygon(PackedVector2Array([Vector2(x, top - 3.0 - h), Vector2(x + half, top - 3.0), Vector2(x - half, top - 3.0)]), shore)
			draw_colored_polygon(PackedVector2Array([Vector2(x, top + 1.0 + h * 0.75), Vector2(x + half, top + 1.0), Vector2(x - half, top + 1.0)]), Color(shade, 0.3))

	func _lake_life(span: Vector2, zone: int) -> void:
		var top := base_y - 54.0
		var width := span.y - span.x
		# The sun's glitter follows you along the shore.
		if sun_x > span.x + 16.0 and sun_x < span.y - 16.0:
			for k in 9:
				var w := (5.0 + k * 2.4) * (0.55 + 0.45 * sin(t * 3.0 + k * 1.7))
				draw_rect(Rect2(sun_x - w * 0.5 + sin(t * 1.3 + k) * 2.0, top + 4.0 + k * 5.3, w, 1.4), Color(Backdrop.SUN, 0.85))
		# Ripples.
		for k in 16:
			var x := span.x + 12.0 + Backdrop.rand(k + zone * 31, 73) * (width - 40.0) + sin(t * 0.6 + k) * 5.0
			var y := top + 5.0 + Backdrop.rand(k + zone * 31, 74) * 44.0
			var glint := 0.3 + 0.25 * sin(t * 1.5 + k * 2.0)
			draw_rect(Rect2(x, y, 6.0 + Backdrop.rand(k, 75) * 10.0, 1.4), Color(1.0, 1.0, 1.0, glint))
		# Lily pads.
		for k in 7:
			var pad := Vector2(span.x + 20.0 + Backdrop.rand(k + zone * 17, 76) * (width - 50.0), top + 30.0 + Backdrop.rand(k, 77) * 20.0)
			draw_rect(Rect2(pad, Vector2(6.7, 2.7)), Color("6fa873"))
			if k % 3 == 0:
				draw_rect(Rect2(pad + Vector2(2.7, -1.4), Vector2(2.7, 2.7)), Color("f3b6c4"))
		# Two ducks paddling across, each trailing a wake.
		for k in 2:
			var dir := 1.0 if k == 0 else -1.0
			var travel := fposmod(t * (5.0 + k * 2.0) + k * 190.0, width - 60.0)
			var duck := Vector2(span.x + 30.0 + (travel if dir > 0.0 else width - 60.0 - travel), top + 16.0 + k * 15.0 + sin(t * 2.0 + k) * 0.7)
			draw_rect(Rect2(duck + Vector2(-9.0 * dir - 4.0, 2.2), Vector2(8.0, 1.4)), Color(1.0, 1.0, 1.0, 0.45))
			draw_rect(Rect2(duck + Vector2(-4.0, -2.7), Vector2(8.0, 4.0)), Color("fbfaf4"))
			draw_rect(Rect2(duck + Vector2(2.0 * dir - 1.4, -5.4), Vector2(2.8, 3.4)), Color("fbfaf4"))
			draw_rect(Rect2(duck + Vector2(4.0 * dir - 0.7, -4.0), Vector2(1.4, 1.4)), Color("f0a23c"))
		# Reeds along the near bank, swaying.
		for k in 22:
			var x := span.x + 4.0 + Backdrop.rand(k + zone * 13, 78) * (width - 8.0)
			var h := 9.0 + 9.0 * Backdrop.rand(k, 79)
			var sway := sin(t * 1.4 + k * 0.9) * 1.6
			draw_line(Vector2(x, base_y + 2.0), Vector2(x + sway, base_y - h), shade.darkened(0.1), 1.4)
			if k % 2 == 0:
				draw_rect(Rect2(x + sway - 1.0, base_y - h - 3.0, 2.0, 4.5), Color("7a5c44"))

	# --- cottage ---

	func _cottage(cx: float, zone: int) -> void:
		const WALL := Color("e6dcc3")
		const WALL_SHADE := Color("cfc3a8")
		const ROOF := Color("b97862")
		const ROOF_SHADE := Color("a26652")
		const WOOD := Color("7a5c44")
		const GLOW := Color("ffd98a")
		var foot := base_y + 2.0
		# Meadow flowers.
		const PETALS: Array[Color] = [Color("f3b6c4"), Color("ffe38a"), Color("fbfaf4"), Color("c9b3ea")]
		for k in 34:
			var x := cx - 140.0 + Backdrop.rand(k + zone * 7, 81) * 280.0
			draw_rect(Rect2(x, base_y - 2.0 - Backdrop.rand(k, 82) * 4.0, 2.7, 2.7), PETALS[k % 4])
		# Fence.
		for side: float in [-1.0, 1.0]:
			draw_rect(Rect2(cx + side * 34.0 - (48.0 if side < 0.0 else 0.0), foot - 6.0, 48.0, 1.4), WOOD)
			for k in 6:
				draw_rect(Rect2(cx + side * (34.0 + k * 9.0) - 1.0, foot - 9.0, 2.0, 9.0), WOOD)
		# Chimney smoke, drifting up and thinning out.
		var chimney := Vector2(cx + 13.0, foot - 62.0)
		for k in 6:
			var age := fposmod(t * 0.22 + k / 6.0, 1.0)
			var puff := chimney + Vector2(sin(age * 5.0 + k) * 4.0 + age * 18.0, -age * 52.0)
			draw_circle(puff, 2.5 + age * 6.5, Color(1.0, 1.0, 1.0, (1.0 - age) * 0.6))
		draw_rect(Rect2(chimney.x - 3.5, chimney.y, 7.0, 20.0), ROOF_SHADE)
		# House.
		draw_rect(Rect2(cx - 24.0, foot - 28.0, 48.0, 28.0), WALL)
		draw_rect(Rect2(cx + 10.0, foot - 28.0, 14.0, 28.0), WALL_SHADE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 30.0, foot - 27.0), Vector2(cx + 30.0, foot - 27.0),
			Vector2(cx + 19.0, foot - 50.0), Vector2(cx - 19.0, foot - 50.0),
		]), ROOF)
		draw_rect(Rect2(cx - 30.0, foot - 30.0, 60.0, 3.0), ROOF_SHADE)
		draw_rect(Rect2(cx - 4.5, foot - 15.0, 9.0, 15.0), WOOD)
		for side: float in [-1.0, 1.0]:
			var pane := Rect2(cx + side * 14.5 - 4.0, foot - 21.0, 8.0, 8.0)
			draw_rect(pane.grow(1.2), WOOD)
			draw_rect(pane, GLOW)
			draw_rect(Rect2(pane.position.x + 3.4, pane.position.y, 1.3, 8.0), WOOD)

	# --- ruins ---

	func _ruins(cx: float) -> void:
		const STONE := Color("b3bfb1")
		const STONE_SHADE := Color("9aa89b")
		var foot := base_y + 2.0
		const COLUMNS: Array[Vector2] = [Vector2(-78.0, 64.0), Vector2(-40.0, 36.0), Vector2(18.0, 70.0), Vector2(62.0, 70.0), Vector2(98.0, 20.0)]
		# An arch still standing between two of the columns.
		draw_arc(Vector2(cx + 40.0, foot - 70.0), 22.0, PI, TAU, 14, STONE_SHADE, 8.0)
		draw_arc(Vector2(cx + 40.0, foot - 70.0), 22.0, PI, PI * 1.62, 10, STONE, 8.0)
		for k in COLUMNS.size():
			var x := cx + COLUMNS[k].x
			var h := COLUMNS[k].y
			draw_rect(Rect2(x - 5.0, foot - h, 10.0, h), STONE)
			draw_rect(Rect2(x + 1.5, foot - h, 3.5, h), STONE_SHADE)
			draw_rect(Rect2(x - 7.0, foot - 4.0, 14.0, 4.0), STONE)
			if h > 50.0:
				draw_rect(Rect2(x - 7.0, foot - h - 4.0, 14.0, 5.0), STONE)
			else:
				# Broken off: a jagged top.
				draw_colored_polygon(PackedVector2Array([Vector2(x - 5.0, foot - h), Vector2(x - 1.0, foot - h - 5.0), Vector2(x + 5.0, foot - h)]), STONE)
			# Ivy.
			for j in 4:
				if Backdrop.rand(k * 9 + j, 85) < 0.6:
					draw_rect(Rect2(x - 5.0 + Backdrop.rand(k * 9 + j, 86) * 7.0, foot - h + 4.0 + j * 7.0, 4.0, 5.4), leaf.darkened(0.12))
		# A lintel slab across the first pair, and fallen blocks in the grass.
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 84.0, foot - 70.0), Vector2(cx - 52.0, foot - 70.0),
			Vector2(cx - 36.0, foot - 40.0), Vector2(cx - 44.0, foot - 37.0),
			Vector2(cx - 60.0, foot - 62.0), Vector2(cx - 84.0, foot - 62.0),
		]), STONE)
		draw_rect(Rect2(cx - 14.0, foot - 8.0, 14.0, 8.0), STONE)
		draw_rect(Rect2(cx - 8.0, foot - 13.0, 9.0, 5.4), STONE_SHADE)
		draw_rect(Rect2(cx + 76.0, foot - 6.0, 11.0, 6.0), STONE_SHADE)
		draw_rect(Rect2(cx - 14.0, foot - 9.4, 8.0, 2.7), leaf)


## Shafts of sunlight slanting down through the trees.
class Rays extends Node2D:
	var _camera: CameraRig
	var _t := 0.0

	func update(camera: CameraRig, t: float) -> void:
		_camera = camera
		_t = t
		queue_redraw()

	func _draw() -> void:
		if _camera == null:
			return
		var size := _camera.view_size
		var corner := _camera.view_center - size * 0.5
		var sun := corner + size * Backdrop.SUN_AT
		for k in 5:
			var spread := (k - 2.0) * 0.16 + sin(_t * 0.1 + k * 2.1) * 0.04
			var width := 16.0 + 16.0 * Backdrop.rand(k, 91)
			var reach := size.y * 1.1
			var end := sun + Vector2(-0.55 + spread, 1.0) * reach
			var glow := 0.06 + 0.035 * sin(_t * 0.4 + k * 1.3)
			draw_colored_polygon(PackedVector2Array([
				sun + Vector2(-3.0, 0.0), sun + Vector2(3.0, 0.0),
				end + Vector2(width, 0.0), end + Vector2(-width, 0.0),
			]), Color(Backdrop.SUN, glow))


## Slow drifting specks of light in front of everything.
class Motes extends Node2D:
	const COUNT := 26
	const COLOR := Color("fff3b0")
	var camera: CameraRig
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if camera == null:
			return
		var size := camera.view_size + Vector2(80.0, 80.0)
		var corner := camera.view_center - size * 0.5
		for i in COUNT:
			var home := Vector2(Backdrop.rand(i, 91) * size.x, Backdrop.rand(i, 92) * size.y)
			var drift := Vector2(sin(_t * 0.3 + i * 1.7) * 26.0 + _t * 6.0, cos(_t * 0.23 + i * 2.3) * 18.0 - _t * 3.0)
			# Wrap around the view, scrolling a little faster than the level.
			var p := home + drift - camera.view_center * 0.25
			p = Vector2(fposmod(p.x, size.x), fposmod(p.y, size.y)) + corner
			var glow := 0.35 + 0.35 * sin(_t * 1.3 + i * 2.1)
			draw_rect(Rect2(p, Vector2(2.7, 2.7)), Color(COLOR, glow))
