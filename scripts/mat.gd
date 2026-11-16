class_name Mat
extends Node2D
## A dog mat. Told to stay nearby, the dog comes and sits on it. Unlike a
## plate it is wired to nothing: it only fixes where the dog sits.


func _ready() -> void:
	add_to_group("seats")


func _draw() -> void:
	draw_rect(Rect2(-17.0, -3.0, 34.0, 3.0), Color("8a3f4a"))
	draw_rect(Rect2(-15.0, -3.0, 30.0, 1.4), Color("c9697a"))
	for k in 5:
		draw_rect(Rect2(-17.0 + k * 8.0, -1.0, 2.0, 2.0), Color("e9d8b0"))
