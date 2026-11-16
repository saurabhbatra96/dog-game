class_name Level
extends Node2D
## Builds a grey-box level from a text map (see level_maps.gd).

signal goal_reached

const TILE := 32.0
## Terrain colours and plant life per theme. "flowers" is how much of the
## grass is covered by drifts; "drift" lists their colours.
const THEMES := {
	"woods": {
		"dirt": "6b5442", "dirt_dark": "58432f", "dirt_light": "7e6650",
		"top": "86c35c", "top_dark": "5d9f4a", "tufts": true, "flowers": 0.5,
		"drift": ["a98bd8", "a98bd8", "8f6fc9", "c3a6ea", "ffd95a", "fff6ea", "f29bb8"],
	},
	"meadow": {
		"dirt": "86694a", "dirt_dark": "6d5338", "dirt_light": "9b7d5a",
		"top": "cdb95e", "top_dark": "a39242", "tufts": true, "flowers": 0.6,
		"drift": ["f4d23a", "f4d23a", "ffe27a", "fff6ea", "e9a53a"],
	},
	"town": {
		"dirt": "5f5a58", "dirt_dark": "4c4846", "dirt_light": "736d69",
		"top": "a3a29b", "top_dark": "7c7b75", "tufts": false, "flowers": 0.0,
		"drift": ["f29bb8"],
	},
	"gloam": {
		"dirt": "17232e", "dirt_dark": "101a23", "dirt_light": "22323f",
		"top": "7fb0b4", "top_dark": "3f6f78", "tufts": true, "flowers": 0.0,
		"drift": ["a98bd8"],
	},
	"night": {
		"dirt": "222a40", "dirt_dark": "181f31", "dirt_light": "2e3853",
		"top": "46526f", "top_dark": "313b55", "tufts": false, "flowers": 0.0,
		"drift": ["a98bd8"],
	},
}

var theme := "woods"
## True for puzzle rooms: a fall restarts the room, and the dog cannot cheat by bounding to you.
var puzzle := false
## Hunger the dog starts the room with, or -1 to carry it over.
var start_hunger := -1.0
var C_DIRT := Color("6b5442")
var C_DIRT_DARK := Color("58432f")
var C_DIRT_LIGHT := Color("7e6650")
var C_GRASS := Color("86c35c")
var C_GRASS_DARK := Color("5d9f4a")
var _tufts := true
var _flowers := 0.5
var _drift: Array[Color] = []
const C_POLE := Color("4a3b30")
const C_GOAL := Color("e8574c")
const C_LABEL := Color("fff8e6")
const C_LABEL_EDGE := Color(0.2, 0.16, 0.12, 0.85)

var title := ""
var player_spawn := Vector2.ZERO
var dog_spawn := Vector2.ZERO
var bounds := Rect2()
var kill_y := 0.0

var _cols := 0
var _rows := 0
var _solid := {}
var _rects: Array[Rect2] = []
## Feet positions of the level exits.
var goals: Array[Vector2] = []


func build(data: Dictionary) -> void:
	title = data.get("name", "")
	theme = data.get("theme", "woods")
	puzzle = data.get("puzzle", false)
	start_hunger = data.get("hunger", -1.0)
	var look: Dictionary = THEMES.get(theme, THEMES["woods"])
	C_DIRT = Color(look["dirt"])
	C_DIRT_DARK = Color(look["dirt_dark"])
	C_DIRT_LIGHT = Color(look["dirt_light"])
	C_GRASS = Color(look["top"])
	C_GRASS_DARK = Color(look["top_dark"])
	_tufts = look["tufts"]
	_flowers = look["flowers"]
	_drift.clear()
	for hex: String in look["drift"]:
		_drift.append(Color(hex))
	var labels: Dictionary = data.get("labels", {})
	var lines: Array[String] = []
	for line: String in String(data["map"]).split("\n"):
		if line.strip_edges() != "" or not lines.is_empty():
			lines.append(line)
	while not lines.is_empty() and lines[-1].strip_edges() == "":
		lines.pop_back()

	_rows = lines.size()
	for line in lines:
		_cols = maxi(_cols, line.length())
	bounds = Rect2(0.0, 0.0, _cols * TILE, _rows * TILE)
	kill_y = bounds.end.y + 240.0

	var has_dog_spawn := false
	for y in _rows:
		for x in lines[y].length():
			var ch := lines[y][x]
			var feet := Vector2((x + 0.5) * TILE, (y + 1) * TILE)
			match ch:
				"#":
					_solid[Vector2i(x, y)] = true
				"P":
					player_spawn = feet
				"D":
					dog_spawn = feet
					has_dog_spawn = true
				"?":
					_add_poi(feet, Poi.Kind.CURIOUS)
				"!":
					_add_poi(feet, Poi.Kind.SCARY)
				">":
					_add_goal(feet)
				"=":
					var plate := Plate.new()
					plate.position = feet
					add_child(plate)
				"|", "&":
					var gate := Gate.new()
					gate.needs_key = ch == "&"
					gate.position = feet
					add_child(gate)
				"*":
					_add_prop(Treat.new(), feet)
				"%":
					_add_prop(Lure.new(), feet)
				"$":
					_add_prop(Item.new(), feet)
				"E":
					var enemy := Enemy.new()
					enemy.position = feet
					add_child(enemy)
				_:
					if labels.has(ch):
						_add_label(Vector2(x * TILE, y * TILE), labels[ch])
	if not has_dog_spawn:
		dog_spawn = player_spawn + Vector2(-40.0, 0.0)

	_build_collision()
	queue_redraw()


func _is_solid(x: int, y: int) -> bool:
	return _solid.has(Vector2i(x, y))


## Merges tiles into as few rectangles as possible, so bodies never catch on
## the seam between two tiles.
func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var open := {}  # Vector2i(start column, end column) -> start row
	for y in range(_rows + 1):
		var runs := {}
		var x := 0
		while y < _rows and x < _cols:
			if _is_solid(x, y):
				var start := x
				while x < _cols and _is_solid(x, y):
					x += 1
				runs[Vector2i(start, x)] = true
			else:
				x += 1
		for key: Vector2i in open.keys():
			if not runs.has(key):
				var top: int = open[key]
				_rects.append(Rect2(key.x * TILE, top * TILE, (key.y - key.x) * TILE, (y - top) * TILE))
				open.erase(key)
		for key: Vector2i in runs:
			if not open.has(key):
				open[key] = y

	# Invisible walls at both ends of the level.
	var walls: Array[Rect2] = [
		Rect2(-TILE, -2000.0, TILE, bounds.size.y + 4000.0),
		Rect2(bounds.end.x, -2000.0, TILE, bounds.size.y + 4000.0),
	]
	for rect in _rects + walls:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collider := CollisionShape2D.new()
		collider.shape = shape
		collider.position = rect.get_center()
		body.add_child(collider)


func _add_prop(prop: Node2D, feet: Vector2) -> void:
	prop.position = feet
	add_child(prop)


func _add_poi(feet: Vector2, kind: Poi.Kind) -> void:
	var poi := Poi.new()
	poi.kind = kind
	poi.position = feet
	add_child(poi)


func _add_goal(feet: Vector2) -> void:
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.position = feet + Vector2(0.0, -TILE)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(TILE, TILE * 2.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	area.add_child(collider)
	area.body_entered.connect(_on_goal_entered)
	add_child(area)
	goals.append(feet)


func _on_goal_entered(body: Node2D) -> void:
	if body is Player:
		goal_reached.emit()


func _add_label(at: Vector2, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", C_LABEL)
	label.add_theme_color_override("font_outline_color", C_LABEL_EDGE)
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)


## Repeatable pseudo-random number in 0..1 for a tile.
func _rand(cell: Vector2i, salt: int) -> float:
	return Backdrop.rand(cell.x * 131 + cell.y * 7919, salt)


func _draw() -> void:
	# Earth.
	for rect in _rects:
		draw_rect(rect, C_DIRT)
	for cell: Vector2i in _solid:
		var corner := Vector2(cell.x, cell.y) * TILE
		var open_above := not _is_solid(cell.x, cell.y - 1)
		# Pebbles and darker patches, on a 4 pixel grid to stay chunky.
		for n in 2:
			var roll := _rand(cell, 10 + n)
			if roll < 0.55:
				var at := corner + Vector2(floorf(_rand(cell, 20 + n) * 6.0), floorf(_rand(cell, 30 + n) * 6.0) + 1.0) * 4.0
				draw_rect(Rect2(at, Vector2(8.0, 4.0) if roll < 0.3 else Vector2(4.0, 4.0)), C_DIRT_DARK if roll < 0.4 else C_DIRT_LIGHT)
		if not _is_solid(cell.x, cell.y + 1) and cell.y < _rows - 1:
			draw_rect(Rect2(corner + Vector2(0.0, TILE - 4.0), Vector2(TILE, 4.0)), C_DIRT_DARK)
		if not _is_solid(cell.x + 1, cell.y) and not open_above:
			draw_rect(Rect2(corner + Vector2(TILE - 4.0, 0.0), Vector2(4.0, TILE)), C_DIRT_DARK)

	# Grass on every exposed top, drawn last so it overlaps the earth.
	for cell: Vector2i in _solid:
		if _is_solid(cell.x, cell.y - 1):
			continue
		var corner := Vector2(cell.x, cell.y) * TILE
		draw_rect(Rect2(corner, Vector2(TILE, 8.0)), C_GRASS)
		draw_rect(Rect2(corner + Vector2(0.0, 8.0), Vector2(TILE, 4.0)), C_GRASS_DARK)
		for n in 4:
			var x := n * 8.0
			# Blades poking up, and grass hanging down over the earth.
			if _tufts and _rand(cell, 40 + n) < 0.6:
				draw_rect(Rect2(corner + Vector2(x + 2.0, -4.0), Vector2(3.0, 4.0)), C_GRASS)
			if _tufts and _rand(cell, 50 + n) < 0.5:
				draw_rect(Rect2(corner + Vector2(x, 12.0), Vector2(4.0, 4.0)), C_GRASS_DARK)

	# Wildflowers. Most grow in drifts of one colour that carpet a stretch of
	# grass; a few strays and the odd tropical plant fill in between.
	for cell: Vector2i in _solid:
		if _is_solid(cell.x, cell.y - 1):
			continue
		var corner := Vector2(cell.x, cell.y) * TILE
		var drift := floori(cell.x / 4.0) * 131 + cell.y * 17
		if _flowers <= 0.0:
			continue
		var in_drift := Backdrop.rand(drift, 63) < _flowers
		var color: Color = _drift[int(Backdrop.rand(drift, 64) * _drift.size()) % _drift.size()]
		var count := 8 if in_drift else (1 if _rand(cell, 65) < 0.3 else 0)
		for n in count:
			var x := corner.x + _rand(cell, 70 + n) * TILE
			var h := 2.0 + _rand(cell, 80 + n) * 6.0
			var tint := color.lightened(0.18) if _rand(cell, 90 + n) < 0.35 else color
			draw_rect(Rect2(x + 0.6, corner.y - h, 1.4, h), C_STEM)
			# Taller ones carry a spike of two blooms.
			draw_rect(Rect2(x, corner.y - h - 2.7, 2.7, 2.7 if h < 5.5 else 5.4), tint)
		if theme == "woods" and not in_drift and _rand(cell, 60) < 0.07:
			# Drawn at reduced size so it sits among the small flowers.
			var at := corner + Vector2(TILE * 0.5, 0.0)
			draw_set_transform(at, 0.0, Vector2(0.62, 0.62))
			match int(_rand(cell, 61) * 5.0):
				0:
					_hibiscus(Vector2.ZERO, Color("e2574c"), Color("a8323a"))
				1:
					_hibiscus(Vector2.ZERO, Color("f58ab4"), Color("c2437c"))
				2:
					_bird_of_paradise(Vector2.ZERO)
				3:
					_plumeria(Vector2.ZERO)
				_:
					_big_leaves(Vector2.ZERO, _rand(cell, 62))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	for feet in goals:
		draw_rect(Rect2(feet + Vector2(-2.0, -60.0), Vector2(4.0, 60.0)), C_POLE)
		draw_colored_polygon(PackedVector2Array([
			feet + Vector2(2.0, -60.0), feet + Vector2(28.0, -50.0), feet + Vector2(2.0, -40.0),
		]), C_GOAL)


# --- plants -------------------------------------------------------------------

const C_STEM := Color("3f8a4a")
const C_LEAF := Color("58ad5c")
const C_LEAF_DARK := Color("3c8648")


func _leaf(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var mid := (from + to) * 0.5
	var side := (to - from).orthogonal().normalized() * width
	draw_colored_polygon(PackedVector2Array([from, mid + side, to, mid - side]), color)


## Five round petals, a dark throat, and a long yellow stamen.
func _hibiscus(at: Vector2, petal: Color, throat: Color) -> void:
	draw_rect(Rect2(at.x - 1.0, at.y - 15.0, 2.0, 15.0), C_STEM)
	_leaf(at + Vector2(0.0, -5.0), at + Vector2(9.0, -10.0), 2.6, C_LEAF)
	_leaf(at + Vector2(0.0, -8.0), at + Vector2(-9.0, -12.0), 2.6, C_LEAF_DARK)
	var c := at + Vector2(0.0, -18.0)
	for k in 5:
		var angle := -PI * 0.5 + TAU * k / 5.0
		draw_circle(c + Vector2(cos(angle), sin(angle)) * 4.2, 3.7, petal)
	draw_circle(c, 2.4, throat)
	draw_line(c, c + Vector2(4.0, -6.0), Color("ffe38a"), 1.4)
	draw_rect(Rect2(c + Vector2(3.0, -8.0), Vector2(2.7, 2.7)), Color("ffd23c"))


## Tall blades with an orange and blue crest.
func _bird_of_paradise(at: Vector2) -> void:
	_leaf(at, at + Vector2(-8.0, -22.0), 3.4, C_LEAF_DARK)
	_leaf(at, at + Vector2(9.0, -19.0), 3.4, C_LEAF)
	draw_rect(Rect2(at.x - 1.0, at.y - 22.0, 2.0, 22.0), C_STEM)
	var c := at + Vector2(0.0, -22.0)
	_leaf(c + Vector2(-2.0, 1.0), c + Vector2(9.0, -2.0), 2.0, Color("7a4f8f"))
	draw_colored_polygon(PackedVector2Array([c, c + Vector2(1.0, -11.0), c + Vector2(4.0, -2.0)]), Color("ff8a2a"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(2.0, -1.0), c + Vector2(7.0, -10.0), c + Vector2(6.0, -2.0)]), Color("ffb23c"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(4.0, -2.0), c + Vector2(12.0, -7.0), c + Vector2(8.0, -1.0)]), Color("ff8a2a"))
	draw_colored_polygon(PackedVector2Array([c + Vector2(3.0, -2.0), c + Vector2(11.0, -3.0), c + Vector2(6.0, 0.0)]), Color("4667d6"))


## A low shrub with clusters of white and yellow pinwheel flowers.
func _plumeria(at: Vector2) -> void:
	draw_circle(at + Vector2(-5.0, -4.0), 5.5, C_LEAF_DARK)
	draw_circle(at + Vector2(5.0, -5.0), 6.0, C_LEAF)
	draw_circle(at + Vector2(0.0, -9.0), 5.5, C_LEAF)
	for bloom: Vector2 in [Vector2(-5.0, -8.0), Vector2(4.0, -11.0), Vector2(7.0, -4.0), Vector2(-1.0, -13.0)]:
		var c := at + bloom
		for k in 4:
			var angle := PI * 0.25 + TAU * k / 4.0
			draw_rect(Rect2(c + Vector2(cos(angle), sin(angle)) * 2.4 - Vector2(1.35, 1.35), Vector2(2.7, 2.7)), Color("fffaf0"))
		draw_rect(Rect2(c - Vector2(1.35, 1.35), Vector2(2.7, 2.7)), Color("ffd23c"))


## A fan of broad jungle leaves.
func _big_leaves(at: Vector2, roll: float) -> void:
	_leaf(at, at + Vector2(-13.0, -11.0 - roll * 5.0), 4.0, C_LEAF_DARK)
	_leaf(at, at + Vector2(12.0, -13.0), 4.2, C_LEAF_DARK)
	_leaf(at, at + Vector2(-3.0 + roll * 6.0, -19.0), 4.4, C_LEAF)
	draw_line(at, at + Vector2(-3.0 + roll * 6.0, -19.0), C_LEAF_DARK, 1.4)
