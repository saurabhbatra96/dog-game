class_name Backdrop
extends Node2D
## The woods behind the level: a banded morning sky and three rows of trees
## that scroll at different speeds. Everything is drawn from shapes and placed
## by a repeatable hash, so the forest is endless and needs no image files.

const SKY_TOP := Color("c9dfd3")
const SKY_BOTTOM := Color("f6edcf")
const SUN := Color("fff8dc")

var camera: CameraRig
## Camera height at which every row of trees sits at its natural height.
var reference_y := 0.0
## World height of the level's main ground.
var ground_y := 0.0

var _sky: SkyBands
var _layers: Array[TreeLayer] = []


func _ready() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	_sky = SkyBands.new()
	sky_layer.add_child(_sky)

	# factor: 0 is pinned to the screen, 1 moves with the level.
	_add_layer(0.12, -46.0, 54.0, 120.0, 0.0, Color("b9d3b8"), Color("abc8ad"), Color("abc8ad"), 11)
	_add_layer(0.3, -14.0, 96.0, 190.0, 0.25, Color("8cb58f"), Color("79a581"), Color("7f9a80"), 23)
	_add_layer(0.55, 64.0, 150.0, 290.0, 0.5, Color("568c69"), Color("467a5b"), Color("5a4b3f"), 37)


func _add_layer(factor: float, base: float, spacing: float, height: float, detail: float, leaf: Color, shade: Color, trunk: Color, salt: int) -> void:
	var layer := TreeLayer.new()
	layer.factor = factor
	layer.base_offset = base
	layer.spacing = spacing
	layer.tree_height = height
	layer.detail = detail
	layer.leaf = leaf
	layer.shade = shade
	layer.trunk = trunk
	layer.salt = salt
	layer.mist = Color(SKY_BOTTOM, 0.32 * (1.0 - factor))
	add_child(layer)
	_layers.append(layer)


func set_level(spawn: Vector2) -> void:
	ground_y = spawn.y
	reference_y = spawn.y - 44.0


func _process(_delta: float) -> void:
	if camera == null or camera.world == null:
		return
	var center := camera.view_center
	var half := camera.view_size * 0.5
	_sky.set_size(Vector2(camera.world.size))
	for layer in _layers:
		layer.position = Vector2(center.x * (1.0 - layer.factor), (center.y - reference_y) * (1.0 - layer.factor))
		layer.base_y = ground_y + layer.base_offset
		layer.set_view(center.x * layer.factor - half.x, center.x * layer.factor + half.x)


## Repeatable pseudo-random number in 0..1 for tree number i.
static func rand(i: int, salt: int) -> float:
	var h := (i * 73856093) ^ (salt * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0


class SkyBands extends Node2D:
	var _size := Vector2(642.0, 362.0)

	func set_size(size: Vector2) -> void:
		if size != _size:
			_size = size
			queue_redraw()

	func _draw() -> void:
		# Stepped bands instead of a smooth gradient, to suit the pixel look.
		const BANDS := 9
		var band := ceilf(_size.y / BANDS)
		for i in BANDS:
			var t := float(i) / float(BANDS - 1)
			draw_rect(Rect2(0.0, i * band, _size.x, band + 1.0), Backdrop.SKY_TOP.lerp(Backdrop.SKY_BOTTOM, t))
		var sun := Vector2(_size.x * 0.74, _size.y * 0.24)
		draw_circle(sun, _size.y * 0.16, Color(Backdrop.SUN, 0.35))
		draw_circle(sun, _size.y * 0.1, Backdrop.SUN)


class TreeLayer extends Node2D:
	var factor := 0.3
	var base_offset := 0.0
	var base_y := 0.0
	var spacing := 90.0
	var tree_height := 160.0
	## 0 draws flat silhouettes, higher adds shading and bushes.
	var detail := 0.0
	var leaf := Color.WHITE
	var shade := Color.WHITE
	var trunk := Color.WHITE
	var mist := Color.TRANSPARENT
	var salt := 0

	var _first := 0
	var _last := -1
	var _x0 := 0.0
	var _x1 := 0.0
	var _drawn_base := INF

	func set_view(x0: float, x1: float) -> void:
		_x0 = x0
		_x1 = x1
		var first := floori(x0 / spacing) - 2
		var last := ceili(x1 / spacing) + 2
		if first != _first or last != _last or base_y != _drawn_base:
			_first = first
			_last = last
			_drawn_base = base_y
			queue_redraw()

	func _draw() -> void:
		var left := _first * spacing
		var width := (_last - _first) * spacing
		for i in range(_first, _last + 1):
			var x := i * spacing + (Backdrop.rand(i, salt) - 0.5) * spacing * 0.7
			var h := tree_height * (0.7 + 0.6 * Backdrop.rand(i, salt + 1))
			if Backdrop.rand(i, salt + 2) < 0.55:
				_pine(x, h)
			else:
				_round_tree(x, h)
		# The forest floor of this row, with a bumpy top edge.
		draw_rect(Rect2(left, base_y, width, 4000.0), shade)
		if detail > 0.0:
			# Darker with depth, so a pit reads as a drop and not as ground.
			draw_rect(Rect2(left, base_y + 56.0, width, 4000.0), shade.darkened(0.14))
			draw_rect(Rect2(left, base_y + 128.0, width, 4000.0), shade.darkened(0.28))
		for i in range(_first * 3, _last * 3 + 1):
			var x := i * spacing / 3.0 + Backdrop.rand(i, salt + 5) * spacing * 0.3
			var r := 9.0 + 14.0 * Backdrop.rand(i, salt + 6)
			draw_circle(Vector2(x, base_y + r * 0.35), r, shade)
			if detail > 0.0 and Backdrop.rand(i, salt + 7) < 0.5:
				draw_circle(Vector2(x - r * 0.25, base_y + r * 0.2), r * 0.6, leaf)
		if mist.a > 0.0:
			draw_rect(Rect2(left, base_y - 70.0, width, 4000.0), mist)

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
