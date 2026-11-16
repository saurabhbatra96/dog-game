class_name Lure
extends Node2D
## Something delicious lying about. The hungrier the dog, the further away it
## will catch the smell and abandon whatever it was told to do. The ring shows
## how far the pull reaches right now, so you can plan around it.

var _t := 0.0


func _ready() -> void:
	add_to_group("lures")


## How far the smell reaches for a dog this hungry (0 to 1).
static func reach(hunger: float) -> float:
	return 30.0 + 200.0 * hunger


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var dog := get_tree().get_first_node_in_group("dog") as Dog
	if dog != null:
		var r := Lure.reach(dog.hunger) * dog.lure_resistance()
		draw_arc(Vector2(0.0, -6.0), r, 0.0, TAU, 72, Color(1.0, 0.75, 0.4, 0.16 + 0.06 * sin(_t * 2.0)), 2.0, true)
	# A sandwich.
	draw_rect(Rect2(-8.0, -9.0, 16.0, 3.0), Color("e9cf9a"))
	draw_rect(Rect2(-9.0, -6.0, 18.0, 2.0), Color("7fb35a"))
	draw_rect(Rect2(-8.0, -4.0, 16.0, 2.0), Color("d9655a"))
	draw_rect(Rect2(-8.0, -2.0, 16.0, 3.0), Color("e9cf9a"))
	for k in 3:
		var rise := fposmod(_t * 0.6 + k / 3.0, 1.0)
		draw_circle(Vector2(-5.0 + k * 5.0 + sin(_t * 2.0 + k) * 2.0, -12.0 - rise * 14.0), 1.5, Color(1.0, 0.9, 0.7, (1.0 - rise) * 0.5), true, -1.0, true)
