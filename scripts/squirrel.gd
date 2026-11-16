class_name Squirrel
extends Node2D
## A squirrel minding its own business. When the player or the dog gets
## close it bolts away from whoever startled it, along the ground, until
## something stops it. Then it is gone. The dog cannot help giving chase,
## even from another level, which makes a squirrel a way to send the dog a
## long distance in a direction of your choosing.

var dir := 1
var running := false
var gone := false
var _t := 0.0
var _fade := 0.0


func _ready() -> void:
	add_to_group("squirrels")


func _physics_process(delta: float) -> void:
	_t += delta
	if gone:
		_fade += delta
		position.y -= 160.0 * delta
		if _fade > 0.5:
			queue_free()
	elif running:
		var space := get_world_2d().direct_space_state
		var ahead := global_position + Vector2(dir * 16.0, -6.0)
		var wall := PhysicsRayQueryParameters2D.create(global_position + Vector2(0.0, -6.0), ahead, 1)
		var ground := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0.0, 20.0), 1)
		if not space.intersect_ray(wall).is_empty() or space.intersect_ray(ground).is_empty():
			gone = true
		else:
			position.x += dir * 330.0 * delta
	else:
		for group: String in ["player", "dog"]:
			var body := get_tree().get_first_node_in_group(group) as Node2D
			if body == null:
				continue
			var d := body.global_position - global_position
			if absf(d.x) < 130.0 and absf(d.y) < 30.0:
				running = true
				dir = -1 if d.x > 0.0 else 1
				break
	queue_redraw()


func _draw() -> void:
	var fur := Color(Color("b5683a"), 1.0 - _fade * 2.0)
	var f := float(dir)
	var hop := absf(sin(_t * 22.0)) * 4.0 if running else 0.0
	var c := Vector2(0.0, -6.0 - hop)
	# Tail, body, head, ear, eye.
	draw_circle(c + Vector2(-7.0 * f, -6.0), 5.5, fur, true, -1.0, true)
	draw_circle(c + Vector2(-5.0 * f, -1.0), 4.0, fur, true, -1.0, true)
	draw_circle(c, 5.0, fur, true, -1.0, true)
	draw_circle(c + Vector2(5.0 * f, -4.0), 3.6, fur, true, -1.0, true)
	draw_rect(Rect2(c + Vector2(4.0 * f - 1.0, -9.0), Vector2(2.0, 3.0)), fur)
	draw_rect(Rect2(c + Vector2(6.0 * f - 0.7, -5.0), Vector2(1.4, 1.4)), Color("1d1a22"))
	if not running and not gone:
		draw_rect(Rect2(c + Vector2(7.0 * f - 1.0, -2.0 + sin(_t * 9.0)), Vector2(3.0, 3.0)), Color("8a5a2c"))
