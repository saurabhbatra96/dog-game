class_name ThrownBait
extends Node2D
## A sandwich in flight. Where it lands it becomes food the dog cannot resist.

const GRAVITY := 900.0

var velocity := Vector2.ZERO
var _spin := 0.0


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	var next := global_position + velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, next, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = next
	elif (hit["normal"] as Vector2).y < -0.5:
		var lure := Lure.new()
		lure.strong = true
		lure.position = get_parent().to_local(hit["position"])
		get_parent().add_child(lure)
		queue_free()
	else:
		# Bounced off a wall.
		velocity.x *= -0.3
	if global_position.y > 5000.0:
		queue_free()
	_spin += delta * 12.0
	queue_redraw()


## The path a throw would take, for drawing the aim. The last point is where
## it lands.
static func preview(space: PhysicsDirectSpaceState2D, from: Vector2, start_velocity: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var at := from
	var v := start_velocity
	for i in 180:
		v.y += GRAVITY / 60.0
		var next := at + v / 60.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(at, next, 1))
		if hit.is_empty():
			at = next
		elif (hit["normal"] as Vector2).y < -0.5:
			points.append(hit["position"])
			break
		else:
			v.x *= -0.3
		points.append(at)
	return points


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
	draw_rect(Rect2(-7.0, -4.0, 14.0, 3.0), Color("e9cf9a"))
	draw_rect(Rect2(-7.0, -1.0, 14.0, 2.0), Color("7fb35a"))
	draw_rect(Rect2(-7.0, 1.0, 14.0, 3.0), Color("e9cf9a"))
