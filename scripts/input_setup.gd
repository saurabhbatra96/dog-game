extends Node
## Registers the input actions in code, so the bindings live in one readable
## place instead of the serialized blobs in project.godot.


func _enter_tree() -> void:
	# Arrow keys and a cluster under the left hand, in the style of a
	# classic keyboard platformer.
	_action("move_left", [KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("jump", [KEY_Z, KEY_SPACE], [JOY_BUTTON_A])
	_action("stay", [KEY_X], [JOY_BUTTON_X])
	_action("call_dog", [KEY_C], [JOY_BUTTON_B])
	_action("fetch", [KEY_A], [JOY_BUTTON_Y])
	_action("throw", [KEY_S], [JOY_BUTTON_RIGHT_SHOULDER])
	# One key for kindness: a biscuit if you have one, otherwise a pat.
	_action("feed", [KEY_D], [JOY_BUTTON_LEFT_SHOULDER])
	_action("restart", [KEY_R], [])
	_action("next_level", [KEY_BRACKETRIGHT], [])
	_action("prev_level", [KEY_BRACKETLEFT], [])
	_action("toggle_debug", [KEY_TAB], [])


func _action(action: StringName, keys: Array, buttons: Array, axis: int = -1, axis_value: float = 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.3)
	for key: int in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key as Key
		InputMap.action_add_event(action, key_event)
	for button: int in buttons:
		var button_event := InputEventJoypadButton.new()
		button_event.button_index = button as JoyButton
		InputMap.action_add_event(action, button_event)
	if axis >= 0:
		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = axis as JoyAxis
		axis_event.axis_value = axis_value
		InputMap.action_add_event(action, axis_event)
