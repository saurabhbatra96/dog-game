class_name Gate
extends StaticBody2D
## A portcullis three tiles tall. It lifts while any plate in the level is
## pressed and drops the moment none is. Its state is never recorded for
## rewinding: it only ever reflects what is on the plates right now.

const SIZE := Vector2(20.0, 96.0)

var _lift := 0.0
var _collider: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	_collider = CollisionShape2D.new()
	_collider.shape = shape
	_collider.position = Vector2(0.0, -SIZE.y * 0.5)
	add_child(_collider)


func _physics_process(delta: float) -> void:
	var open := false
	for node in get_tree().get_nodes_in_group("plates"):
		if (node as Plate).pressed:
			open = true
	_lift = move_toward(_lift, 1.0 if open else 0.0, delta * 3.5)
	_collider.disabled = _lift > 0.35
	queue_redraw()


func _draw() -> void:
	var raise := _lift * (SIZE.y - 14.0)
	var iron := Color("3a3a42")
	for k in 3:
		draw_rect(Rect2(-8.0 + k * 6.5, -SIZE.y - raise, 3.0, SIZE.y), iron)
		draw_colored_polygon(PackedVector2Array([
			Vector2(-8.0 + k * 6.5, -raise), Vector2(-5.0 + k * 6.5, -raise), Vector2(-6.5 + k * 6.5, 5.0 - raise),
		]), iron)
	for k in 4:
		draw_rect(Rect2(-10.0, -SIZE.y + 8.0 + k * 24.0 - raise, 20.0, 3.0), iron.lightened(0.15))
