class_name Backdrop
extends Node2D
## The world behind the level, drawn entirely from shapes and placed by a
## repeatable hash, so it is endless and needs no image files.
##
## Each level picks a theme (see _apply): woods, meadow, town or night.
## Back to front: sky, mountains, a far row with one landmark, a middle row
## that cycles through scenes, shafts of light, and a near row.

const SUN := Color("fff8dc")
## Where the sun or moon sits, as a fraction of the screen.
const SUN_AT := Vector2(0.74, 0.24)

var camera: CameraRig
## Camera height at which every layer sits at its natural height.
var reference_y := 0.0
## World height of the level's main ground.
var ground_y := 0.0
var theme := ""

var _sky: SkyBands
var _rays: Rays
var _mountains: Mountains
var _far: Woods
var _mid: Woods
var _near: Woods
var _layers: Array[Layer] = []
var _t := 0.0


func _ready() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky = SkyBands.new()
	sky_layer.add_child(_sky)

	# factor: 0 is pinned to the screen, 1 moves with the level.
	_mountains = Mountains.new()
	_add(_mountains, 0.04)
	_far = Woods.new()
	_far.animated = true
	_far.salt = 11
	_add(_far, 0.12)
	_mid = Woods.new()
	_mid.animated = true
	_mid.salt = 23
	_add(_mid, 0.3)
	_rays = Rays.new()
	add_child(_rays)
	_near = Woods.new()
	_near.salt = 37
	_add(_near, 0.55)
	_apply("woods")


func _add(layer: Layer, factor: float) -> void:
	layer.factor = factor
	add_child(layer)
	_layers.append(layer)


func set_level(spawn: Vector2, level_theme: String = "woods") -> void:
	ground_y = spawn.y
	reference_y = spawn.y - 44.0
	_apply(level_theme)


## Dresses every layer for a theme.
func _apply(level_theme: String) -> void:
	if level_theme == theme:
		return
	theme = level_theme
	for woods: Woods in [_far, _mid, _near]:
		woods.landmark = Woods.NO_LANDMARK
		woods.props = Woods.NO_PROPS
		woods.scenes = [Woods.FOREST]
		woods.density = 1.0
		woods.pine_share = 0.55
		woods.bushes = true
		woods.night = false
	_mountains.base_offset = -58.0
	_far.base_offset = -46.0
	_mid.base_offset = -14.0
	_near.base_offset = 64.0
	_mountains.visible = false
	_rays.visible = true
	var horizon := Color("f6edcf")
	match theme:
		"meadow":
			# Dry golden parkland under a wide blue sky.
			horizon = Color("e6f0e6")
			_sky.dress(Color("86bfe9"), horizon, false)
			_far.setup(40.0, 70.0, 0.0, Color("86ad86"), Color("78a07b"), Color("78a07b"), Color("c9bf7a"))
			_far.pine_share = 0.0
			_far.landmark = Woods.SPIRE
			_mid.setup(120.0, 150.0, 0.25, Color("5f9463"), Color("4e8254"), Color("5b4a3c"), Color("cdb866"))
			_mid.pine_share = 0.1
			_mid.density = 0.45
			_mid.bushes = false
			_mid.props = Woods.GRASS
			_mid.scenes = [Woods.DEAD_OAK, Woods.DEER, Woods.GUARDS, Woods.FOREST]
			_near.setup(260.0, 300.0, 0.5, Color("3f7a50"), Color("336a45"), Color("4a3c32"), Color("b9a552"))
			_near.pine_share = 0.0
			_near.density = 0.7
			_near.bushes = false
			_near.props = Woods.GRASS
		"town":
			# An old town street beneath a tower on a wooded hill.
			horizon = Color("eef0ea")
			_sky.dress(Color("a9bdd2"), horizon, false)
			_far.setup(50.0, 90.0, 0.0, Color("a3b9a6"), Color("94ac99"), Color("94ac99"), Color("94ac99"))
			_far.pine_share = 0.2
			_far.landmark = Woods.TOWER
			_mid.setup(96.0, 150.0, 0.25, Color("5f9463"), Color("4e8254"), Color("5b4a3c"), Color("8c8a84"))
			_mid.density = 0.0
			_mid.bushes = false
			_mid.scenes = [Woods.STREET, Woods.STREET, Woods.KIRKYARD]
			_near.setup(300.0, 150.0, 0.5, Color("4f8560"), Color("417552"), Color("4a3c32"), Color("6b6a66"))
			_near.pine_share = 0.0
			_near.density = 0.5
			_near.bushes = false
			_near.props = Woods.LAMPS
			_near.base_offset = 2.0
			_rays.visible = false
		"night":
			# A city across the river, after dark.
			horizon = Color("24365a")
			_sky.dress(Color("0a1124"), horizon, true)
			_far.setup(50.0, 90.0, 0.0, Color("16233c"), Color("16233c"), Color("16233c"), Color("101a30"))
			_far.density = 0.0
			_far.bushes = false
			_far.landmark = Woods.SKYLINE
			_mid.setup(96.0, 150.0, 0.25, Color("121b2e"), Color("121b2e"), Color("121b2e"), Color("0e1729"))
			_mid.density = 0.0
			_mid.bushes = false
			_mid.scenes = [Woods.RIVER]
			_near.setup(300.0, 150.0, 0.5, Color("0d1422"), Color("0d1422"), Color("0d1422"), Color("0a101d"))
			_near.density = 0.0
			_near.bushes = false
			_near.props = Woods.LAMPS
			_near.base_offset = 2.0
			for woods: Woods in [_far, _mid, _near]:
				woods.night = true
			_rays.visible = false
		"gloam":
			# A hushed, misty hollow: pale light, dark trunks, things that glow.
			horizon = Color("6c93a0")
			_sky.dress(Color("16222f"), horizon, false, Color("3c5666"))
			_far.setup(46.0, 190.0, 0.0, Color("5f8696"), Color("557b8b"), Color("557b8b"), Color("557b8b"))
			_far.pine_share = 1.0
			_mid.setup(110.0, 250.0, 0.25, Color("3a5d6d"), Color("2f4f5e"), Color("26414f"), Color("2f4f5e"))
			_mid.pine_share = 0.7
			_mid.props = Woods.GLOWCAPS
			_near.setup(170.0, 330.0, 0.5, Color("1f3442"), Color("182b38"), Color("12212b"), Color("182b38"))
			_near.pine_share = 0.4
		_:
			# Morning woods, with mountains and a castle beyond.
			_sky.dress(Color("b9dbe4"), horizon, false)
			_mountains.visible = true
			_far.setup(54.0, 120.0, 0.0, Color("b9d3b8"), Color("abc8ad"), Color("abc8ad"), Color("abc8ad"))
			_far.landmark = Woods.CASTLE
			_mid.setup(96.0, 190.0, 0.25, Color("8cb58f"), Color("79a581"), Color("7f9a80"), Color("79a581"))
			_mid.scenes = [Woods.LAKE, Woods.RUINS, Woods.COTTAGE, Woods.FOREST]
			_near.setup(150.0, 290.0, 0.5, Color("568c69"), Color("467a5b"), Color("5a4b3f"), Color("467a5b"))
	for layer in _layers:
		var fog := 0.32
		if theme == "night":
			fog = 0.14
		elif theme == "gloam":
			fog = 0.5
		layer.mist = Color(horizon, fog * (1.0 - layer.factor))
		layer.force_redraw()


func _process(delta: float) -> void:
	if camera == null or camera.world == null:
		return
	_t += delta
	var center := camera.view_center
	var half := camera.view_size * 0.5
	_sky.update(Vector2(camera.world.size), center.x, _t)
	if _rays.visible:
		_rays.update(camera, _t)
	for layer in _layers:
		if not layer.visible:
			continue
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
	var top := Color("b9dbe4")
	var bottom := Color("f6edcf")
	var night := false
	var cloud_tint := Color("f8faf4")
	var _size := Vector2(642.0, 362.0)
	var _cam_x := 0.0
	var _t := 0.0

	func dress(p_top: Color, p_bottom: Color, p_night: bool, p_cloud: Color = Color("f8faf4")) -> void:
		top = p_top
		bottom = p_bottom
		night = p_night
		cloud_tint = p_cloud

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
			draw_rect(Rect2(0.0, i * band, _size.x, band + 1.0), top.lerp(bottom, float(i) / float(BANDS - 1)))

		var sun := _size * Backdrop.SUN_AT
		if night:
			for k in 70:
				var star := Vector2(Backdrop.rand(k, 51) * _size.x, Backdrop.rand(k, 52) * _size.y * 0.62)
				var twinkle := 0.35 + 0.45 * absf(sin(_t * (0.6 + Backdrop.rand(k, 53)) + k))
				draw_rect(Rect2(star, Vector2(1.0, 1.0) if k % 4 else Vector2(2.0, 2.0)), Color(1.0, 1.0, 0.92, twinkle))
			draw_circle(sun, _size.y * 0.12, Color(0.8, 0.86, 1.0, 0.12))
			draw_circle(sun, _size.y * 0.07, Color("f3f1e0"))
			draw_circle(sun + Vector2(_size.y * 0.03, -_size.y * 0.015), _size.y * 0.06, top.lerp(bottom, 0.3))
		else:
			draw_circle(sun, _size.y * 0.2, Color(Backdrop.SUN, 0.22))
			draw_circle(sun, _size.y * 0.15, Color(Backdrop.SUN, 0.3))
			draw_circle(sun, _size.y * 0.095, Backdrop.SUN)

		# Clouds drift on the wind and barely react to the camera.
		var cloud := Color("1c2947") if night else cloud_tint
		var cloud_shade := Color("162038") if night else top.lerp(cloud_tint, 0.55)
		var span := _size.x + 260.0
		for k in 6:
			var speed := 2.0 + Backdrop.rand(k, 62) * 3.0
			var x := fposmod(Backdrop.rand(k, 61) * span + _t * speed - _cam_x * 0.02, span) - 130.0
			var y := _size.y * (0.05 + 0.3 * Backdrop.rand(k, 63))
			var s := 0.7 + Backdrop.rand(k, 64) * 0.9
			draw_rect(Rect2(x + 4.0 * s, y + 5.0 * s, 50.0 * s, 4.0 * s), cloud_shade)
			draw_rect(Rect2(x, y, 58.0 * s, 7.0 * s), cloud)
			draw_circle(Vector2(x + 14.0 * s, y), 9.0 * s, cloud)
			draw_circle(Vector2(x + 30.0 * s, y - 5.0 * s), 13.0 * s, cloud)
			draw_circle(Vector2(x + 45.0 * s, y + 1.0 * s), 8.5 * s, cloud)

		# Every so often a small flock crosses the sky.
		var crossing := fposmod(_t, 24.0) / 15.0
		if crossing < 1.0 and not night:
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

	func force_redraw() -> void:
		_drawn_base = INF
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


## Trees, plus whatever landmark, scenes and props this row is given.
class Woods extends Layer:
	enum { NO_LANDMARK, CASTLE, SPIRE, TOWER, SKYLINE }
	enum { NO_PROPS, LAMPS, GRASS, GLOWCAPS }
	enum { FOREST, LAKE, COTTAGE, RUINS, DEAD_OAK, DEER, GUARDS, STREET, KIRKYARD, RIVER }
	## Scenes repeat along the row, one per ZONE of width.
	const ZONE := 620.0
	const LANDMARK_EVERY := 1100.0
	const LANDMARK_AT := 420.0

	var landmark := NO_LANDMARK
	var props := NO_PROPS
	var scenes: Array[int] = [FOREST]
	var spacing := 90.0
	var tree_height := 160.0
	## 0 draws flat silhouettes, higher adds shading.
	var detail := 0.0
	## Share of tree slots that actually grow a tree.
	var density := 1.0
	var pine_share := 0.55
	var bushes := true
	var night := false
	var leaf := Color.WHITE
	var shade := Color.WHITE
	var trunk := Color.WHITE
	var floor_color := Color.WHITE
	var salt := 0

	func setup(p_spacing: float, p_height: float, p_detail: float, p_leaf: Color, p_shade: Color, p_trunk: Color, p_floor: Color) -> void:
		spacing = p_spacing
		tree_height = p_height
		detail = p_detail
		leaf = p_leaf
		shade = p_shade
		trunk = p_trunk
		floor_color = p_floor

	func _scene(zone: int) -> int:
		return scenes[posmod(zone, scenes.size())]

	## The stretch of a zone its scene occupies; trees keep out of it.
	func _span(zone: int) -> Vector2:
		var start := zone * ZONE
		match _scene(zone):
			LAKE:
				return Vector2(start + 60.0, start + 560.0)
			COTTAGE:
				return Vector2(start + 170.0, start + 450.0)
			RUINS, DEER:
				return Vector2(start + 200.0, start + 420.0)
			DEAD_OAK, GUARDS:
				return Vector2(start + 220.0, start + 400.0)
			STREET, KIRKYARD, RIVER:
				return Vector2(start, start + ZONE)
		return Vector2.ZERO

	func _landmark_near(x: float) -> float:
		return roundf((x - LANDMARK_AT) / LANDMARK_EVERY) * LANDMARK_EVERY + LANDMARK_AT

	func _kept_clear(x: float, margin: float) -> bool:
		var span := _span(floori(x / ZONE))
		if span != Vector2.ZERO and x > span.x - margin and x < span.y + margin:
			return true
		if landmark == CASTLE or landmark == SPIRE or landmark == TOWER:
			return absf(x - _landmark_near(x)) < 78.0 + margin
		return false

	func _draw() -> void:
		var first_zone := floori((x0 - 100.0) / ZONE)
		var last_zone := floori((x1 + 100.0) / ZONE)

		# What sits behind the trees.
		for zone in range(first_zone, last_zone + 1):
			match _scene(zone):
				LAKE:
					_lake_water(_span(zone))
				RIVER:
					_river_water(_span(zone))
		if landmark == SKYLINE:
			_skyline()
		elif landmark != NO_LANDMARK:
			var cx := _landmark_near(x0 - 300.0)
			while cx < x1 + 300.0:
				match landmark:
					CASTLE:
						_castle(cx)
					SPIRE:
						_spire(cx)
					TOWER:
						_hill_tower(cx)
				cx += LANDMARK_EVERY

		var first := floori(x0 / spacing) - 3
		var last := ceili(x1 / spacing) + 3
		for i in range(first, last + 1):
			var x := i * spacing + (Backdrop.rand(i, salt) - 0.5) * spacing * 0.7
			if Backdrop.rand(i, salt + 9) >= density or _kept_clear(x, 16.0):
				continue
			var h := tree_height * (0.7 + 0.6 * Backdrop.rand(i, salt + 1))
			if Backdrop.rand(i, salt + 2) < pine_share:
				_pine(x, h)
			else:
				_round_tree(x, h)

		# The floor of this row.
		ground(floor_color)
		if detail > 0.0:
			# Darker with depth, so a pit reads as a drop and not as ground.
			draw_rect(Rect2(x0 - 200.0, base_y + 56.0, x1 - x0 + 400.0, 4000.0), floor_color.darkened(0.14))
			draw_rect(Rect2(x0 - 200.0, base_y + 128.0, x1 - x0 + 400.0, 4000.0), floor_color.darkened(0.28))
		if bushes:
			for i in range(first * 3, last * 3 + 1):
				var x := i * spacing / 3.0 + Backdrop.rand(i, salt + 5) * spacing * 0.3
				if _span(floori(x / ZONE)) != Vector2.ZERO and _kept_clear(x, -6.0):
					continue
				var r := 9.0 + 14.0 * Backdrop.rand(i, salt + 6)
				draw_circle(Vector2(x, base_y + r * 0.35), r, shade)
				if detail > 0.0 and Backdrop.rand(i, salt + 7) < 0.5:
					draw_circle(Vector2(x - r * 0.25, base_y + r * 0.2), r * 0.6, leaf)
		haze()

		# What stands in front of the haze.
		for zone in range(first_zone, last_zone + 1):
			var span := _span(zone)
			var cx := (span.x + span.y) * 0.5
			match _scene(zone):
				LAKE:
					_lake_life(span, zone)
				COTTAGE:
					_cottage(cx, zone)
				RUINS:
					_ruins(cx)
				DEAD_OAK:
					_dead_oak(cx, zone)
				DEER:
					_deer(cx - 30.0, zone)
					_deer(cx + 50.0, zone + 7)
				GUARDS:
					_guards(cx)
				STREET:
					_street(span, zone)
				KIRKYARD:
					_kirkyard(span, zone)
				RIVER:
					_river_lights(span, zone)
		match props:
			GRASS:
				_tall_grass()
			LAMPS:
				_lamps()
			GLOWCAPS:
				_glowcaps()

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

	# --- castle (woods) ---

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

	# --- lake (woods) ---

	func _lake_water(span: Vector2) -> void:
		const WATER: Array[Color] = [Color("d6e9e1"), Color("bcdad6"), Color("a2cbcb"), Color("8abbc0")]
		const DEPTHS: Array[float] = [0.0, 9.0, 22.0, 38.0]
		var top := base_y - 54.0
		var width := span.y - span.x
		for k in 4:
			draw_rect(Rect2(span.x, top + DEPTHS[k], width, 80.0), WATER[k])
		# The far shore, with small trees mirrored in the water.
		var shore := leaf.lerp(Color("f6edcf"), 0.42)
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

	# --- cottage and ruins (woods) ---

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

	# --- meadow ---

	## A gothic memorial spire rising out of the far trees.
	func _spire(cx: float) -> void:
		const STONE := Color("cfc8b6")
		const STONE_SHADE := Color("b8b09d")
		const HOLLOW := Color("8f8878")
		const GOLD := Color("e9c75a")
		var foot := base_y + 2.0
		for k in 3:
			draw_rect(Rect2(cx - 46.0 + k * 8.0, foot - 8.0 * (k + 1), 92.0 - k * 16.0, 8.0), STONE if k % 2 == 0 else STONE_SHADE)
		var y := foot - 24.0
		draw_rect(Rect2(cx - 20.0, y - 50.0, 40.0, 50.0), STONE)
		draw_rect(Rect2(cx + 9.0, y - 50.0, 11.0, 50.0), STONE_SHADE)
		# The open canopy, with a gilded figure seated inside.
		draw_circle(Vector2(cx, y - 32.0), 10.0, HOLLOW)
		draw_rect(Rect2(cx - 10.0, y - 32.0, 20.0, 32.0), HOLLOW)
		draw_rect(Rect2(cx - 3.5, y - 20.0, 7.0, 20.0), GOLD)
		draw_circle(Vector2(cx, y - 23.0), 3.6, GOLD)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 25.0, y - 50.0), Vector2(cx + 25.0, y - 50.0), Vector2(cx, y - 76.0)]), STONE)
		for side: float in [-22.0, 22.0]:
			draw_rect(Rect2(cx + side - 3.0, y - 72.0, 6.0, 24.0), STONE_SHADE if side > 0.0 else STONE)
			draw_colored_polygon(PackedVector2Array([Vector2(cx + side - 4.5, y - 72.0), Vector2(cx + side + 4.5, y - 72.0), Vector2(cx + side, y - 96.0)]), STONE)
		draw_rect(Rect2(cx - 7.0, y - 106.0, 14.0, 36.0), STONE)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 10.0, y - 106.0), Vector2(cx + 10.0, y - 106.0), Vector2(cx, y - 172.0)]), STONE)
		draw_colored_polygon(PackedVector2Array([Vector2(cx + 1.0, y - 106.0), Vector2(cx + 10.0, y - 106.0), Vector2(cx, y - 172.0)]), STONE_SHADE)
		draw_rect(Rect2(cx - 4.0, y - 122.0, 8.0, 3.0), GOLD)
		draw_rect(Rect2(cx - 0.7, y - 186.0, 1.4, 15.0), GOLD)
		draw_rect(Rect2(cx - 3.4, y - 181.0, 6.8, 1.4), GOLD)

	## A long-dead oak, bare and crooked against the sky.
	func _dead_oak(cx: float, zone: int) -> void:
		const BARK := Color("3b322c")
		var foot := base_y + 2.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 10.0, foot), Vector2(cx + 10.0, foot), Vector2(cx + 6.5, foot - 54.0), Vector2(cx - 6.0, foot - 54.0),
		]), BARK)
		draw_rect(Rect2(cx - 2.0, foot - 34.0, 4.0, 6.0), BARK.lightened(0.12))
		var crown := Vector2(cx, foot - 52.0)
		_branch(crown + Vector2(-3.0, 0.0), -1.05, 30.0, 5.5, 3, zone * 8 + 1, BARK)
		_branch(crown, -0.12, 30.0, 6.0, 3, zone * 8 + 2, BARK)
		_branch(crown + Vector2(3.0, 0.0), 0.85, 28.0, 5.0, 3, zone * 8 + 3, BARK)
		_branch(crown + Vector2(4.0, 14.0), 1.35, 20.0, 3.5, 2, zone * 8 + 4, BARK)
		# Ragwort around its feet.
		for k in 26:
			var x := cx - 90.0 + Backdrop.rand(k + zone * 5, 87) * 180.0
			var h := 3.0 + Backdrop.rand(k, 88) * 9.0
			draw_rect(Rect2(x + 0.6, base_y - h, 1.4, h + 2.0), Color("8f9a4a"))
			draw_rect(Rect2(x, base_y - h - 2.7, 2.7, 2.7), Color("f4d23a"))

	func _branch(from: Vector2, angle: float, length: float, width: float, depth: int, id: int, color: Color) -> void:
		var to := from + Vector2(sin(angle), -cos(angle)) * length
		draw_line(from, to, color, width)
		if depth <= 0:
			return
		var bend := 0.4 + 0.55 * Backdrop.rand(id, 111)
		_branch(to, angle - bend, length * 0.72, maxf(width * 0.62, 1.4), depth - 1, id * 2 + 1, color)
		_branch(to, angle + bend * (0.6 + 0.7 * Backdrop.rand(id, 112)), length * 0.64, maxf(width * 0.58, 1.4), depth - 1, id * 2 + 2, color)

	## A grazing deer that lifts its head now and then to look about.
	func _deer(cx: float, zone: int) -> void:
		const COAT := Color("b9743f")
		const COAT_DARK := Color("8d5631")
		const CREAM := Color("f1e2c8")
		var foot := base_y + 2.0
		for lx: float in [-12.0, -8.0, 8.0, 11.5]:
			draw_rect(Rect2(cx + lx, foot - 14.0, 2.2, 14.0), COAT_DARK)
		draw_rect(Rect2(cx - 14.0, foot - 26.0, 28.0, 13.0), COAT)
		draw_circle(Vector2(cx - 13.0, foot - 19.5), 6.5, COAT)
		draw_circle(Vector2(cx + 13.0, foot - 19.5), 6.5, COAT)
		draw_rect(Rect2(cx - 9.0, foot - 15.0, 18.0, 2.7), CREAM)
		draw_rect(Rect2(cx - 20.5, foot - 25.0, 3.0, 5.5), CREAM)
		var grazing := smoothstep(-0.25, 0.25, sin(t * 0.33 + zone * 1.9))
		var head := Vector2(cx + 23.0, foot - 41.0).lerp(Vector2(cx + 27.0, foot - 7.0), grazing)
		draw_line(Vector2(cx + 14.0, foot - 21.0), head, COAT, 6.0)
		draw_circle(head, 4.4, COAT)
		draw_rect(Rect2(head + Vector2(2.0, -1.4), Vector2(6.0, 4.0)), COAT)
		draw_rect(Rect2(head + Vector2(6.8, -1.0), Vector2(1.6, 2.0)), Color("2b2522"))
		draw_rect(Rect2(head + Vector2(0.6, -2.0), Vector2(1.4, 1.4)), Color("2b2522"))
		var flick := sin(t * 7.0 + zone) * 0.25 if fmod(t + zone, 5.0) < 0.6 else 0.0
		for side: float in [-1.0, 0.4]:
			var tip := head + Vector2(-4.0 + side * 3.0, -9.0).rotated(flick)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-3.5, -2.0), head + Vector2(0.0, -3.4), tip]), COAT_DARK if side < 0.0 else COAT)

	## Saplings in the wooden cages that keep the deer off them.
	func _guards(cx: float) -> void:
		const WOOD := Color("b3a890")
		const WOOD_DARK := Color("968c75")
		var foot := base_y + 2.0
		for off: float in [-56.0, 44.0]:
			var x := cx + off
			draw_rect(Rect2(x - 1.5, foot - 70.0, 3.0, 70.0), trunk)
			draw_circle(Vector2(x, foot - 76.0), 19.0, leaf)
			draw_circle(Vector2(x + 7.0, foot - 70.0), 14.0, shade)
			draw_circle(Vector2(x - 6.0, foot - 80.0), 13.0, leaf)
			for k in 5:
				draw_rect(Rect2(x - 16.0 + k * 7.4, foot - 40.0 - (k % 2) * 3.0, 2.7, 40.0 + (k % 2) * 3.0), WOOD if k % 2 == 0 else WOOD_DARK)
			draw_rect(Rect2(x - 17.0, foot - 32.0, 35.0, 2.7), WOOD)
			draw_rect(Rect2(x - 17.0, foot - 12.0, 35.0, 2.7), WOOD_DARK)

	## Pale mushrooms and hanging lantern-flowers that light the mist.
	func _glowcaps() -> void:
		const GLOW := Color("9ff2e6")
		for i in range(floori(x0 / 70.0) - 1, ceili(x1 / 70.0) + 2):
			var x := i * 70.0 + Backdrop.rand(i, 151) * 50.0
			var pulse := 0.5 + 0.5 * sin(t * 1.3 + i * 1.7)
			if Backdrop.rand(i, 152) < 0.55:
				var h := 8.0 + 16.0 * Backdrop.rand(i, 153)
				draw_circle(Vector2(x, base_y - h), 16.0 + pulse * 5.0, Color(GLOW, 0.07 + 0.05 * pulse))
				draw_rect(Rect2(x - 1.0, base_y - h, 2.0, h + 2.0), Color("cfe9e6"))
				draw_circle(Vector2(x, base_y - h), 5.0, Color(GLOW, 0.7 + 0.3 * pulse))
				draw_rect(Rect2(x - 5.0, base_y - h, 10.0, 5.0), floor_color)
			else:
				# A lantern-flower hanging from a thread.
				var drop := 90.0 + 80.0 * Backdrop.rand(i, 154)
				var sway := sin(t * 0.8 + i) * 4.0
				var bulb := Vector2(x + sway, base_y - drop)
				draw_line(Vector2(x, base_y - drop - 160.0), bulb, Color(trunk, 0.9), 1.2)
				draw_circle(bulb, 13.0 + pulse * 4.0, Color(GLOW, 0.08 + 0.05 * pulse))
				draw_circle(bulb, 3.2, Color(GLOW, 0.85))

	func _tall_grass() -> void:
		var step := 5.0
		for i in range(floori(x0 / step) - 2, ceili(x1 / step) + 3):
			var x := i * step + Backdrop.rand(i, salt + 31) * 4.0
			var h := 6.0 + 15.0 * Backdrop.rand(i, salt + 32)
			var sway := sin(t * 1.2 + i * 0.7) * 1.8 if animated else (Backdrop.rand(i, salt + 33) - 0.5) * 4.0
			var blade := Color("dccb72") if i % 3 else Color("b7a24c")
			draw_line(Vector2(x, base_y + 3.0), Vector2(x + sway, base_y - h), blade, 1.4)
			if i % 11 == 0:
				draw_rect(Rect2(x + sway - 1.3, base_y - h - 2.0, 2.7, 2.7), Color("f4d23a"))

	# --- town ---

	## A round stone tower on a wooded hill.
	func _hill_tower(cx: float) -> void:
		const STONE := Color("8a9694")
		const STONE_SHADE := Color("788582")
		const BAND := Color("9ca8a5")
		draw_circle(Vector2(cx, base_y + 170.0), 232.0, leaf)
		draw_circle(Vector2(cx + 46.0, base_y + 178.0), 232.0, shade)
		var foot := base_y - 56.0
		draw_rect(Rect2(cx - 14.0, foot - 118.0, 28.0, 120.0), STONE)
		draw_rect(Rect2(cx + 4.0, foot - 118.0, 10.0, 120.0), STONE_SHADE)
		for k in 4:
			draw_rect(Rect2(cx - 15.0, foot - 30.0 - k * 26.0, 30.0, 2.7), BAND)
			draw_rect(Rect2(cx - 3.0, foot - 22.0 - k * 26.0, 5.0, 9.0), STONE_SHADE.darkened(0.3))
		draw_rect(Rect2(cx - 18.0, foot - 126.0, 36.0, 9.0), STONE)
		_battlements(cx - 18.0, cx + 18.0, foot - 126.0, STONE)
		draw_rect(Rect2(cx - 8.0, foot - 146.0, 16.0, 20.0), STONE_SHADE)
		_battlements(cx - 8.0, cx + 8.0, foot - 146.0, STONE_SHADE)
		draw_rect(Rect2(cx - 0.7, foot - 166.0, 1.4, 18.0), STONE_SHADE.darkened(0.3))
		draw_rect(Rect2(cx - 4.0, foot - 161.0, 8.0, 1.4), STONE_SHADE.darkened(0.3))
		# Trees crowding the foot of the tower.
		for k in 5:
			var x := cx - 62.0 + k * 31.0
			draw_circle(Vector2(x, foot - 12.0 - Backdrop.rand(k, 95) * 14.0), 20.0, leaf if k % 2 == 0 else shade)

	func _street(span: Vector2, zone: int) -> void:
		var x := span.x
		var id := zone * 40
		while x < span.y - 1.0:
			var w := minf(62.0 + floorf(Backdrop.rand(id, 121) * 4.0) * 12.0, span.y - x)
			if span.y - x - w < 40.0:
				w = span.y - x
			_building(x, w, id)
			x += w
			id += 1

	func _building(x: float, w: float, id: int) -> void:
		const WALLS: Array[Color] = [Color("b98a6a"), Color("ece6da"), Color("b5654f"), Color("d8c9a4"), Color("c9b08a")]
		const SHOPS: Array[Color] = [Color("2c3e5e"), Color("6a2f35"), Color("2f4f44"), Color("3a3a42")]
		const TRIM := Color("f4efe4")
		var wall: Color = WALLS[int(Backdrop.rand(id, 122) * 5.0) % 5]
		var shop: Color = SHOPS[int(Backdrop.rand(id, 124) * 4.0) % 4]
		var h := 112.0 + floorf(Backdrop.rand(id, 123) * 4.0) * 18.0
		var foot := base_y + 2.0
		var top := foot - h
		draw_rect(Rect2(x + 9.0, top - 15.0, 9.0, 15.0), wall.darkened(0.3))
		draw_rect(Rect2(x, top, w, h), wall)
		draw_rect(Rect2(x + w - 4.0, top, 4.0, h), wall.darkened(0.14))
		draw_rect(Rect2(x - 1.0, top - 4.0, w + 2.0, 5.0), wall.darkened(0.22))
		# Sash windows.
		var cols := maxi(int((w - 12.0) / 19.0), 1)
		var gap := (w - cols * 10.0) / (cols + 1)
		var y := top + 12.0
		while y < foot - 62.0:
			for c in cols:
				var wx := x + gap + c * (10.0 + gap)
				var lit := Backdrop.rand(id * 31 + c + int(y), 128) < 0.18
				draw_rect(Rect2(wx - 1.4, y - 1.4, 12.8, 18.8), TRIM)
				draw_rect(Rect2(wx, y, 10.0, 16.0), Color("e9c98a") if lit else Color("4a5d78"))
				draw_rect(Rect2(wx, y + 7.3, 10.0, 1.4), TRIM)
			y += 27.0
		# Shopfront.
		draw_rect(Rect2(x + 2.0, foot - 40.0, w - 4.0, 40.0), shop)
		draw_rect(Rect2(x + 6.0, foot - 30.0, w - 28.0, 21.0), Color("a9bcc6"))
		draw_rect(Rect2(x + w - 18.0, foot - 30.0, 11.0, 30.0), shop.darkened(0.3))
		draw_rect(Rect2(x + w - 16.0, foot - 27.0, 7.0, 12.0), Color("a9bcc6"))
		draw_rect(Rect2(x + 8.0, foot - 38.5, w - 16.0, 5.0), Color("e9e2d0"))
		if Backdrop.rand(id, 125) < 0.5:
			var cloth := Color("2f55c8") if id % 2 == 0 else Color("b23a3a")
			draw_colored_polygon(PackedVector2Array([
				Vector2(x, foot - 40.0), Vector2(x + w, foot - 40.0), Vector2(x + w + 6.0, foot - 25.0), Vector2(x - 6.0, foot - 25.0),
			]), cloth)
			draw_rect(Rect2(x - 6.0, foot - 26.4, w + 12.0, 1.6), TRIM)
		# Hanging baskets in bloom.
		if Backdrop.rand(id, 126) < 0.6:
			for k in 2:
				var basket := Vector2(x + w * (0.25 + 0.5 * k), foot - 50.0)
				draw_circle(basket, 5.0, Color("4e8254"))
				for j in 5:
					draw_rect(Rect2(basket + Vector2(-5.0 + j * 2.2, -3.0 + (j % 2) * 3.0), Vector2(2.7, 2.7)), Color("e2574c") if j % 2 == 0 else Color("f29bb8"))
		# Pavement tables.
		if Backdrop.rand(id, 127) < 0.45:
			for k in 2:
				var table := x + 14.0 + k * 24.0
				draw_rect(Rect2(table - 6.0, foot - 12.0, 12.0, 2.0), Color("f2cf3c"))
				draw_rect(Rect2(table - 0.7, foot - 10.0, 1.4, 10.0), Color("3a3a42"))
				draw_rect(Rect2(table - 12.0, foot - 13.0, 4.0, 13.0), Color("4f9a94"))
				draw_rect(Rect2(table + 8.0, foot - 13.0, 4.0, 13.0), Color("4f9a94"))

	## An old kirkyard wall set with memorial slabs.
	func _kirkyard(span: Vector2, zone: int) -> void:
		const WALL := Color("8f8b80")
		const SLAB := Color("aaa9a1")
		const PANEL := Color("bebdb4")
		const INK := Color("76746d")
		var foot := base_y + 2.0
		var width := span.y - span.x
		# Old trees leaning over from behind.
		for k in 4:
			var tx := span.x + 70.0 + k * 160.0
			draw_rect(Rect2(tx - 4.0, foot - 120.0, 8.0, 120.0), trunk)
			draw_circle(Vector2(tx, foot - 126.0), 44.0, leaf)
			draw_circle(Vector2(tx + 26.0, foot - 110.0), 32.0, shade)
			draw_circle(Vector2(tx - 28.0, foot - 114.0), 30.0, leaf)
		draw_rect(Rect2(span.x, foot - 54.0, width, 54.0), WALL)
		for k in 90:
			var stone := Vector2(span.x + Backdrop.rand(k + zone * 3, 131) * (width - 10.0), foot - 50.0 + Backdrop.rand(k, 132) * 44.0)
			draw_rect(Rect2(stone, Vector2(9.0, 5.0)), WALL.darkened(0.12) if k % 2 == 0 else WALL.lightened(0.1))
		draw_rect(Rect2(span.x, foot - 59.0, width, 6.0), WALL.darkened(0.25))
		for k in 3:
			var sx := span.x + 80.0 + k * 180.0
			draw_rect(Rect2(sx, foot - 82.0, 48.0, 82.0), SLAB)
			draw_colored_polygon(PackedVector2Array([Vector2(sx - 3.0, foot - 82.0), Vector2(sx + 51.0, foot - 82.0), Vector2(sx + 44.0, foot - 92.0), Vector2(sx + 4.0, foot - 92.0)]), SLAB.darkened(0.12))
			draw_rect(Rect2(sx + 6.0, foot - 70.0, 36.0, 60.0), PANEL)
			draw_circle(Vector2(sx + 24.0, foot - 70.0), 9.0, PANEL)
			for j in 9:
				draw_rect(Rect2(sx + 10.0 + (j % 2) * 3.0, foot - 62.0 + j * 5.6, 26.0 - (j % 3) * 6.0, 1.4), INK)
		# Headstones in the grass in front.
		for k in 7:
			var gx := span.x + 30.0 + Backdrop.rand(k + zone * 11, 133) * (width - 60.0)
			var gh := 14.0 + Backdrop.rand(k, 134) * 10.0
			draw_rect(Rect2(gx - 6.0, foot - gh, 12.0, gh), SLAB.darkened(0.08))
			draw_circle(Vector2(gx, foot - gh), 6.0, SLAB.darkened(0.08))
			draw_rect(Rect2(gx - 7.0, foot - 3.0, 14.0, 3.0), Color("6f9a63"))

	func _lamps() -> void:
		const IRON := Color("26262c")
		const GLOW := Color("ffe2a0")
		var foot := base_y + 2.0
		for i in range(floori(x0 / 280.0) - 1, ceili(x1 / 280.0) + 2):
			var x := i * 280.0 + 90.0
			if night:
				draw_circle(Vector2(x, foot - 112.0), 34.0, Color(GLOW, 0.1))
				draw_circle(Vector2(x, foot - 112.0), 17.0, Color(GLOW, 0.2))
				draw_colored_polygon(PackedVector2Array([Vector2(x - 5.0, foot - 106.0), Vector2(x + 5.0, foot - 106.0), Vector2(x + 36.0, foot), Vector2(x - 36.0, foot)]), Color(GLOW, 0.07))
			draw_rect(Rect2(x - 1.6, foot - 104.0, 3.2, 104.0), IRON)
			draw_rect(Rect2(x - 4.0, foot - 8.0, 8.0, 8.0), IRON)
			draw_rect(Rect2(x - 5.5, foot - 119.0, 11.0, 14.0), IRON)
			draw_rect(Rect2(x - 3.5, foot - 117.0, 7.0, 10.0), GLOW)
			draw_colored_polygon(PackedVector2Array([Vector2(x - 7.0, foot - 119.0), Vector2(x + 7.0, foot - 119.0), Vector2(x, foot - 126.0)]), IRON)

	# --- night ---

	## The city across the water: dark blocks, lit windows, cranes and a wheel.
	func _skyline() -> void:
		const DARK := Color("15213a")
		const DARKER := Color("101a30")
		var foot := base_y + 2.0
		var step := 30.0
		for i in range(floori(x0 / step) - 2, ceili(x1 / step) + 3):
			var x := i * step
			var roll := Backdrop.rand(i, 101)
			var h := 26.0 + 120.0 * roll * roll
			var w := step + 2.0
			draw_rect(Rect2(x, foot - h, w, h), DARK if i % 2 == 0 else DARKER)
			# Windows.
			var rows := int(h / 9.0)
			for r in rows:
				for c in 4:
					var pick := Backdrop.rand(i * 97 + r * 7 + c, 102)
					if pick < 0.3:
						var warm := Color("ffd98a") if pick < 0.22 else Color("a8d4ff")
						draw_rect(Rect2(x + 4.0 + c * 6.5, foot - h + 5.0 + r * 9.0, 2.7, 2.7), Color(warm, 0.9))
			# A crane with a warning light.
			if Backdrop.rand(i, 103) < 0.16:
				var cy := foot - h - 34.0
				draw_rect(Rect2(x + 14.0, cy, 1.4, 34.0), DARKER.lightened(0.12))
				draw_rect(Rect2(x - 4.0, cy, 38.0, 1.4), DARKER.lightened(0.12))
				var blink := 0.35 + 0.65 * absf(sin(t * 1.6 + i))
				draw_rect(Rect2(x + 13.0, cy - 3.0, 3.4, 3.4), Color(1.0, 0.25, 0.3, blink))
		# The wheel, slowly turning.
		var cx := _landmark_near(x0 + (x1 - x0) * 0.5)
		var hub := Vector2(cx, foot - 62.0)
		draw_arc(hub, 40.0, 0.0, TAU, 40, DARK.lightened(0.18), 1.6)
		draw_line(hub, Vector2(cx - 14.0, foot), DARK.lightened(0.18), 1.6)
		draw_line(hub, Vector2(cx + 14.0, foot), DARK.lightened(0.18), 1.6)
		for k in 16:
			var angle := TAU * k / 16.0 + t * 0.08
			draw_rect(Rect2(hub + Vector2(cos(angle), sin(angle)) * 40.0 - Vector2(1.4, 1.4), Vector2(2.8, 2.8)), Color("ff7fb0"))

	func _river_water(span: Vector2) -> void:
		var top := base_y - 50.0
		var width := span.y - span.x
		draw_rect(Rect2(span.x, top, width, 90.0), Color("17284a"))
		draw_rect(Rect2(span.x, top + 12.0, width, 80.0), Color("12203c"))
		draw_rect(Rect2(span.x, top + 30.0, width, 70.0), Color("0e1830"))
		draw_rect(Rect2(span.x, top - 3.0, width, 4.0), Color("0b1326"))

	## Lights along the far bank, each smeared down the water in a long ripple.
	func _river_lights(span: Vector2, zone: int) -> void:
		const LIGHTS: Array[Color] = [Color("ffb347"), Color("ffe9b0"), Color("ff5a66"), Color("ffb347"), Color("9fd0ff")]
		var top := base_y - 50.0
		var count := int((span.y - span.x) / 22.0)
		for k in count:
			var id := k + zone * 53
			var x := span.x + 8.0 + k * 22.0 + Backdrop.rand(id, 141) * 10.0
			var color: Color = LIGHTS[int(Backdrop.rand(id, 142) * 5.0) % 5]
			draw_rect(Rect2(x - 1.4, top - 6.0, 2.8, 2.8), color)
			var length := 4 + int(Backdrop.rand(id, 143) * 5.0)
			for j in length:
				var wobble := sin(t * 2.2 + id * 1.3 + j * 0.9) * (0.6 + j * 0.35)
				var fade := (1.0 - float(j) / float(length + 1)) * (0.5 + 0.35 * sin(t * 3.0 + id + j * 1.7))
				draw_rect(Rect2(x - 1.6 - j * 0.25 + wobble, top + 3.0 + j * 6.0, 3.2 + j * 0.5, 2.7), Color(color, maxf(fade, 0.0)))
		# Moonlight on the water.
		if sun_x > span.x and sun_x < span.y:
			for k in 8:
				var w := (6.0 + k * 3.0) * (0.5 + 0.5 * sin(t * 2.4 + k * 1.9))
				draw_rect(Rect2(sun_x - w * 0.5, top + 5.0 + k * 5.5, w, 1.4), Color(0.85, 0.9, 1.0, 0.55))


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
