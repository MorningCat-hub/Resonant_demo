extends Node
## Sets up the keyboard map in code so the project has no hidden editor state.

const ACTIONS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_W],
	"dodge": [KEY_SHIFT],
	"attack_light": [KEY_K],
	"attack_heavy": [KEY_J],
	"attack_thrust": [KEY_L],
	"attack_launcher": [KEY_I],
	"pause": [KEY_ESCAPE],
	"restart": [KEY_R],
	"confirm": [KEY_ENTER, KEY_KP_ENTER],
	"back": [KEY_ESCAPE],
	"ui_up": [KEY_W, KEY_UP],
	"ui_down": [KEY_S, KEY_DOWN],
	"ui_left": [KEY_A, KEY_LEFT],
	"ui_right": [KEY_D, KEY_RIGHT],
}

const MOUSE_ACTIONS := {
	"attack_light": [MOUSE_BUTTON_LEFT],
	"attack_heavy": [MOUSE_BUTTON_RIGHT],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action: String in ACTIONS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key: Key in ACTIONS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
	for action: String in MOUSE_ACTIONS.keys():
		for button: MouseButton in MOUSE_ACTIONS[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			if not InputMap.action_has_event(action, ev):
				InputMap.action_add_event(action, ev)
	DisplayServer.window_set_title("弦刃 Resonant")
	Engine.max_fps = 120
	# Keep dense stem + SFX moments from hard-clipping on the master bus.
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.threshold_db = -3.0
		limiter.ceiling_db = -0.5
		limiter.soft_clip_db = -1.0
		limiter.soft_clip_ratio = 2.0
		AudioServer.add_bus_effect(0, limiter)
