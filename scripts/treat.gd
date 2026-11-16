class_name Treat
extends Node2D
## A dog biscuit lying in the level. Walk over it to put it in your pouch.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and player.global_position.distance_to(global_position) < 22.0:
		player.treats += 1
		queue_free()
	queue_redraw()


func _draw() -> void:
	var c := Vector2(0.0, -10.0 + sin(_t * 3.0) * 1.5)
	var biscuit := Color("e8c48a")
	draw_circle(c, 10.0, Color(biscuit, 0.2), true, -1.0, true)
	draw_rect(Rect2(c + Vector2(-5.0, -1.8), Vector2(10.0, 3.6)), biscuit)
	for corner: Vector2 in [Vector2(-5.0, -2.2), Vector2(-5.0, 2.2), Vector2(5.0, -2.2), Vector2(5.0, 2.2)]:
		draw_circle(c + corner, 2.4, biscuit, true, -1.0, true)
