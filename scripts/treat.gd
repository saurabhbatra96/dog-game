class_name Treat
extends Node2D
## A pickup: a biscuit (for teaching tricks) or a sandwich (for throwing).
## Walk over it to put it in your pouch.

## True for a sandwich to throw, false for a biscuit to feed.
var bait := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and player.global_position.distance_to(global_position) < 22.0:
		if bait:
			player.sandwiches += 1
		else:
			player.biscuits += 1
		queue_free()
	queue_redraw()


func _draw() -> void:
	var c := Vector2(0.0, -10.0 + sin(_t * 3.0) * 1.5)
	if bait:
		draw_circle(c, 11.0, Color(1.0, 0.8, 0.5, 0.2), true, -1.0, true)
		draw_rect(Rect2(c + Vector2(-7.0, -4.0), Vector2(14.0, 3.0)), Color("e9cf9a"))
		draw_rect(Rect2(c + Vector2(-8.0, -1.0), Vector2(16.0, 2.0)), Color("7fb35a"))
		draw_rect(Rect2(c + Vector2(-7.0, 1.0), Vector2(14.0, 3.0)), Color("e9cf9a"))
		return
	var biscuit := Color("e8c48a")
	draw_circle(c, 10.0, Color(biscuit, 0.2), true, -1.0, true)
	draw_rect(Rect2(c + Vector2(-5.0, -1.8), Vector2(10.0, 3.6)), biscuit)
	for corner: Vector2 in [Vector2(-5.0, -2.2), Vector2(-5.0, 2.2), Vector2(5.0, -2.2), Vector2(5.0, 2.2)]:
		draw_circle(c + corner, 2.4, biscuit, true, -1.0, true)
