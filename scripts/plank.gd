class_name Plank
extends StaticBody2D
## A rotten plank. It carries the dog without complaint and snaps under the
## player, for good. Position is the top-left corner of its tile.

const SIZE := Vector2(32.0, 8.0)

var broken := false
var _strain := 0.0
var _fall := 0.0
var _collider: CollisionShape2D


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	_collider = CollisionShape2D.new()
	_collider.shape = shape
	_collider.position = SIZE * 0.5
	add_child(_collider)


func _physics_process(delta: float) -> void:
	if broken:
		_fall += delta
		queue_redraw()
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	var on_it := false
	if player != null and player.is_on_floor():
		var d := player.global_position - global_position
		on_it = d.x >= 0.0 and d.x <= SIZE.x and absf(d.y) < 3.0
	_strain = _strain + delta if on_it else 0.0
	if _strain > 0.12:
		broken = true
		_collider.disabled = true
	queue_redraw()


func _draw() -> void:
	var wood := Color("9a7a55")
	if broken:
		var drop := _fall * _fall * 600.0
		if drop < 400.0:
			draw_rect(Rect2(0.0, drop, 13.0, 6.0), wood)
			draw_rect(Rect2(18.0, drop * 1.2, 14.0, 6.0), wood.darkened(0.15))
		return
	draw_rect(Rect2(0.0, 0.0, SIZE.x, 6.0), wood)
	draw_rect(Rect2(0.0, 0.0, SIZE.x, 1.5), wood.lightened(0.25))
	draw_rect(Rect2(10.0, 2.0, 1.2, 4.0), wood.darkened(0.35))
	draw_rect(Rect2(22.0, 1.0, 1.2, 3.0), wood.darkened(0.35))
