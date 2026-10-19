extends Node
## Scripted tutorial performance used to record docs/resonant_tutorial.avi.
## It plays the real tutorial, performing the actual inputs and attacks so the
## instructions on screen advance through the real checks.

var main: Node
var t := 0.0
var _started := false
var _fired: Dictionary = {}
var _clean_attempt_at := -10.0
var _heavy_at := -1.0
var _thrust_at := -1.0
var _launcher_at := -1.0
var _dodge_at := -1.0
var _post_done := false
var _quit_at := 24.5


func setup(main_node: Node) -> void:
	main = main_node
	process_mode = Node.PROCESS_MODE_ALWAYS


func _once(key: String, at: float) -> bool:
	if _fired.has(key) or t < at:
		return false
	_fired[key] = true
	return true


func _process(delta: float) -> void:
	t += delta
	if t >= _quit_at:
		get_tree().quit()
		return
	if not _started:
		if t >= 2.2:
			_started = true
			main.call("start_game", true, false)
		return
	if main.world == null or main.world.player == null:
		return
	var player: Node2D = main.world.player
	var overlay: Control = main.tutorial_overlay

	if overlay != null and is_instance_valid(overlay):
		_drive_tutorial(player, overlay)
	else:
		_drive_after_tutorial(player)


func _drive_tutorial(player: Node2D, overlay: Control) -> void:
	var step: int = overlay.step
	# Step 1: walk toward the practice post.
	if _once("walk", 3.2):
		Input.action_press("move_right")
	if _once("stop_walk", 4.3):
		Input.action_release("move_right")
	# Step 2: W jump.
	if _once("jump_press", 5.4):
		Input.action_press("jump")
	if _once("jump_release", 5.62):
		Input.action_release("jump")
	# Step 3: first light hit.
	if step >= 2 and _once("first_light", 7.5):
		_face_post(player)
		player.call("_start_attack", "light")
	# Step 4: one clean hit, scheduled to the audio beat.
	if step >= 3 and step == 3 and player.state in ["Idle", "Run", "Fall"]:
		var to_beat := Conductor.time_to_next_beat()
		if to_beat <= 0.075 and t - _clean_attempt_at > 0.8:
			_clean_attempt_at = t
			_face_post(player)
			player.call("_start_attack", "light")
	# Step 5: all three other attacks, spaced by their recovery.
	if step >= 4 and step == 4:
		if _heavy_at < 0.0:
			_heavy_at = t
			_face_post(player)
			player.call("_start_attack", "heavy")
		elif _thrust_at < 0.0 and t > _heavy_at + 0.92:
			_thrust_at = t
			player.call("_start_attack", "thrust")
		elif _thrust_at >= 0.0 and _launcher_at < 0.0 and t > _thrust_at + 0.55:
			_launcher_at = t
			player.call("_start_attack", "launcher")
	# Step 6: dodge.
	if step >= 5 and step == 5 and _dodge_at < 0.0:
		_dodge_at = t
		player.call("_start_dodge")


func _drive_after_tutorial(player: Node2D) -> void:
	if _post_done:
		return
	_post_done = true
	Input.action_press("move_right")
	await get_tree().create_timer(0.8).timeout
	Input.action_release("move_right")
	await get_tree().create_timer(0.3).timeout
	player.facing = 1
	player.call("_start_attack", "light")
	await get_tree().create_timer(0.35).timeout
	player.call("_start_attack", "light")
	await get_tree().create_timer(0.35).timeout
	player.call("_start_attack", "thrust")


func _face_post(player: Node2D) -> void:
	player.facing = 1
	if player.global_position.x > 390.0:
		player.global_position.x = 385.0
