class_name Rewind
extends Node
## Winds time backwards while the rewind key is held.
##
## Every physics tick it records the state of the player and the enemies on a
## tape. Holding rewind plays the tape backwards. The dog is never recorded:
## it is outside time, and stays wherever it was when the rewind began. Gates
## and plates are not recorded either, because they only ever reflect what is
## standing on them right now.

signal started
signal stopped

## True while time is running backwards. Anything that should freeze checks this.
static var active := false

## Longest stretch that can be wound back, in physics ticks (60 per second).
const MAX_TICKS := 60 * 90

var enabled := false
var player: Player

var _tape: Array = []
var _held := 0.0


func _ready() -> void:
	# Run before the things it controls.
	process_physics_priority = -90


func clear() -> void:
	_tape.clear()
	if Rewind.active:
		Rewind.active = false
		stopped.emit()


func seconds_recorded() -> float:
	return _tape.size() / 60.0


func _physics_process(delta: float) -> void:
	if not enabled or player == null:
		Rewind.active = false
		return
	if Input.is_action_pressed("rewind") and not _tape.is_empty():
		if not Rewind.active:
			Rewind.active = true
			_held = 0.0
			started.emit()
		# Slow at first for fine control, then faster.
		_held += delta
		for i in (1 if _held < 0.7 else 2):
			if _tape.size() > 1:
				_tape.pop_back()
			_play(_tape.back())
	else:
		if Rewind.active:
			Rewind.active = false
			stopped.emit()
		_record()


func _record() -> void:
	var enemies := {}
	for node in get_tree().get_nodes_in_group("enemies"):
		enemies[node] = (node as Enemy).save_state()
	_tape.append([player.save_state(), enemies])
	if _tape.size() > MAX_TICKS:
		_tape.pop_front()


func _play(frame: Array) -> void:
	player.load_state(frame[0])
	var enemies: Dictionary = frame[1]
	for node: Variant in enemies:
		if is_instance_valid(node):
			(node as Enemy).load_state(enemies[node])
