class_name Shapes
## Small drawing helpers shared by the placeholder character art.
## Call these only from inside a CanvasItem's _draw().

## Edge smoothing for all placeholder art. Off gives the hard, pixel-style edge.
const AA := false


static func rrect(ci: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	ci.draw_rect(Rect2(rect.position + Vector2(r, 0.0), rect.size - Vector2(r * 2.0, 0.0)), color)
	ci.draw_rect(Rect2(rect.position + Vector2(0.0, r), rect.size - Vector2(0.0, r * 2.0)), color)
	ci.draw_circle(rect.position + Vector2(r, r), r, color, true, -1.0, Shapes.AA)
	ci.draw_circle(rect.position + Vector2(rect.size.x - r, r), r, color, true, -1.0, Shapes.AA)
	ci.draw_circle(rect.position + Vector2(r, rect.size.y - r), r, color, true, -1.0, Shapes.AA)
	ci.draw_circle(rect.end - Vector2(r, r), r, color, true, -1.0, Shapes.AA)


## Flat ellipse, used for ground shadows. Resets the draw transform afterwards.
static func ellipse(ci: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	ci.draw_set_transform(center, 0.0, Vector2(1.0, ry / maxf(rx, 0.001)))
	ci.draw_circle(Vector2.ZERO, rx, color, true, -1.0, Shapes.AA)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A starburst with slightly uneven rays.
static func spark(ci: CanvasItem, center: Vector2, radius: float, rays: int, rotation: float, color: Color, width: float) -> void:
	const LENGTHS: Array[float] = [1.0, 0.72, 0.9, 0.66, 1.0, 0.78, 0.86, 0.7]
	for i in rays:
		var angle := rotation + TAU * float(i) / float(rays)
		var dir := Vector2(cos(angle), sin(angle))
		var length := radius * LENGTHS[i % LENGTHS.size()]
		ci.draw_line(center + dir * radius * 0.15, center + dir * length, color, width, Shapes.AA)
