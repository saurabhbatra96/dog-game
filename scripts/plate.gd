class_name Plate
extends Node2D
## A pressure plate. Every gate on the same channel is open while any plate
## on that channel is pressed. A normal plate is pressed by the player, the
## dog or a bramble. A heavy plate needs real weight: the dog is too light.

const HALF_WIDTH := 20.0
const COLORS := {"A": Color("e9b93a"), "B": Color("5aa7e6")}

var channel := "A"
var heavy := false
var pressed := false
var _sink := 0.0


func _ready() -> void:
	add_to_group("plates")
	add_to_group("seats")


func _physics_process(delta: float) -> void:
	pressed = false
	for group: String in ["player", "enemies"] if heavy else ["player", "dog", "enemies"]:
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
	var color: Color = COLORS[channel]
	draw_rect(Rect2(-22.0, -2.0, 44.0, 4.0), Color("1d1a22"))
	if heavy:
		# A thick stone slab with a weight carved on it.
		draw_rect(Rect2(-20.0, -9.0 + _sink * 5.0, 40.0, 8.0), Color("8d949c"))
		draw_rect(Rect2(-20.0, -9.0 + _sink * 5.0, 40.0, 2.0), color)
		draw_rect(Rect2(-5.0, -6.0 + _sink * 5.0, 10.0, 4.0), Color("4a5058"))
		draw_rect(Rect2(-2.0, -7.5 + _sink * 5.0, 4.0, 2.0), Color("4a5058"))
	else:
		draw_rect(Rect2(-18.0, -6.0 + _sink * 4.0, 36.0, 5.0), color if pressed else color.darkened(0.2))
		draw_rect(Rect2(-18.0, -6.0 + _sink * 4.0, 36.0, 1.4), color.lightened(0.5))
