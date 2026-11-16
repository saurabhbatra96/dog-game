class_name Plate
extends Node2D
## A pressure plate. It is pressed while the player, the dog or a bramble
## stands on it, and every gate in the level opens while any plate is pressed.

const HALF_WIDTH := 20.0

var pressed := false
var _sink := 0.0


func _ready() -> void:
	add_to_group("plates")


func _physics_process(delta: float) -> void:
	pressed = false
	for group: String in ["player", "dog", "enemies"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as CharacterBody2D
			if body == null or (body is Enemy and (body as Enemy).is_dead()):
				continue
			var d := body.global_position - global_position
			if absf(d.x) < HALF_WIDTH and absf(d.y) < 8.0:
				pressed = true
	_sink = lerpf(_sink, 1.0 if pressed else 0.0, 1.0 - exp(-18.0 * delta))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-22.0, -2.0, 44.0, 4.0), Color("4a4038"))
	draw_rect(Rect2(-18.0, -6.0 + _sink * 4.0, 36.0, 5.0), Color("e9b93a") if pressed else Color("c9a13a"))
	draw_rect(Rect2(-18.0, -6.0 + _sink * 4.0, 36.0, 1.4), Color("fff0b0"))
