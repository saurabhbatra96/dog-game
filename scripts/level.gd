class_name Level
extends Node2D
## Builds a grey-box level from a text map (see level_maps.gd).

signal goal_reached

const TILE := 32.0
const C_DIRT := Color("6b5442")
const C_DIRT_DARK := Color("58432f")
const C_DIRT_LIGHT := Color("7e6650")
const C_GRASS := Color("86c35c")
const C_GRASS_DARK := Color("5d9f4a")
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
var _goals: Array[Vector2] = []


func build(data: Dictionary) -> void:
	title = data.get("name", "")
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
	_goals.append(feet)


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
			if _rand(cell, 40 + n) < 0.6:
				draw_rect(Rect2(corner + Vector2(x + 2.0, -4.0), Vector2(3.0, 4.0)), C_GRASS)
			if _rand(cell, 50 + n) < 0.5:
				draw_rect(Rect2(corner + Vector2(x, 12.0), Vector2(4.0, 4.0)), C_GRASS_DARK)

	for feet in _goals:
		draw_rect(Rect2(feet + Vector2(-2.0, -60.0), Vector2(4.0, 60.0)), C_POLE)
		draw_colored_polygon(PackedVector2Array([
			feet + Vector2(2.0, -60.0), feet + Vector2(28.0, -50.0), feet + Vector2(2.0, -40.0),
		]), C_GOAL)
