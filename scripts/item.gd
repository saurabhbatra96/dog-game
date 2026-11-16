class_name Item
extends Node2D
## A key. The player can pick it up by touching it, or send the dog to fetch
## it. Carried to a locked door, it opens the door and is used up.

var carried_by: Node2D
var _t := 0.0


func _ready() -> void:
	add_to_group("items")


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(carried_by):
		var lift := -32.0 if carried_by is Player else -13.0
		global_position = carried_by.global_position + Vector2(0.0, lift)
	else:
		carried_by = null
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null and player.global_position.distance_to(global_position) < 20.0:
			carried_by = player
	queue_redraw()


func _draw() -> void:
	var bob := 0.0 if carried_by != null else sin(_t * 3.0) * 1.5
	var c := Vector2(0.0, -9.0 + bob)
	var gold := Color("f0c040")
	draw_circle(c, 9.0 + sin(_t * 3.0), Color(gold, 0.18), true, -1.0, true)
	draw_circle(c + Vector2(-4.0, 0.0), 4.0, gold, true, -1.0, true)
	draw_circle(c + Vector2(-4.0, 0.0), 1.6, Color("1d1a22"), true, -1.0, true)
	draw_rect(Rect2(c + Vector2(-1.0, -1.2), Vector2(9.0, 2.4)), gold)
	draw_rect(Rect2(c + Vector2(5.0, 0.0), Vector2(2.0, 3.6)), gold)
