class_name Poi
extends Node2D
## A point of interest the dog reacts to. This is the hook for story beats:
## place one in a level and the dog notices it before the player does.
##   CURIOUS: the dog trots over, sniffs it, and reports back. Once only.
##   SCARY:   the dog turns wary and hides behind the player while in range.

enum Kind { CURIOUS, SCARY }

@export var kind: Kind = Kind.CURIOUS
## The dog reacts when it is within this many pixels.
@export var radius := 230.0

var seen := false
var _t := 0.0


func _ready() -> void:
	add_to_group("poi")


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if kind == Kind.CURIOUS:
		var color := Color("3aa6a0") if not seen else Color("9fb8b4")
		var lift := 0.0 if seen else sin(_t * 2.5) * 1.5
		var c := Vector2(0.0, -9.0 + lift)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(6, 0), c + Vector2(0, 7), c + Vector2(-6, 0)]), color)
		if not seen:
			draw_arc(c, 10.0 + sin(_t * 2.5) * 1.5, 0.0, TAU, 24, Color(color, 0.35), 1.2, Shapes.AA)
	else:
		var color := Color("5b3a6e")
		draw_arc(Vector2(0.0, -10.0), radius, 0.0, TAU, 96, Color(color, 0.07), 2.0, Shapes.AA)
		var pts := PackedVector2Array()
		for i in 14:
			var angle := PI + PI * float(i) / 13.0
			var r := 13.0 + (5.0 if i % 2 == 0 else 0.0) + sin(_t * 3.0 + i) * 1.2
			pts.append(Vector2(cos(angle) * r, sin(angle) * r))
		draw_colored_polygon(pts, color)
		draw_circle(Vector2(-4.0, -7.0), 1.6, Color("ff6b5e"), true, -1.0, Shapes.AA)
		draw_circle(Vector2(4.0, -7.0), 1.6, Color("ff6b5e"), true, -1.0, Shapes.AA)
