class_name OutlinedArt
extends Node2D
## Base for the shape-drawn characters. A character draws itself twice: once
## with `outline` on, where every shape is drawn slightly larger in a dark
## colour, then again normally on top. The result is a clean dark edge around
## the whole silhouette, which keeps a white dog readable on a pale backdrop.

const LINE := Color("4f443c")
## How far the dark edge extends past each shape, before the node's own scale.
var grow := 1.4

var outline := false


func blob(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center, radius + (grow if outline else 0.0), LINE if outline else color, true, -1.0, Shapes.AA)


func box(rect: Rect2, radius: float, color: Color) -> void:
	var g := grow if outline else 0.0
	Shapes.rrect(self, rect.grow(g), radius + g, LINE if outline else color)


func limb(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	draw_line(from, to, LINE if outline else color, width + (grow * 2.0 if outline else 0.0), Shapes.AA)


func tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c]), LINE if outline else color)
	if outline:
		draw_polyline(PackedVector2Array([a, b, c, a]), LINE, grow * 2.0, Shapes.AA)
