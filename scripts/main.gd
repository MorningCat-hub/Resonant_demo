extends Node2D
## Application shell: menu <-> run <-> pause <-> calibration <-> results.

const MENU := preload("res://scripts/ui/menu.gd")
const HUD := preload("res://scripts/ui/hud.gd")
const PAUSE := preload("res://scripts/ui/pause_screen.gd")
const CALIBRATION := preload("res://scripts/ui/calibration.gd")
const HELP := preload("res://scripts/ui/help_screen.gd")
const TUTORIAL := preload("res://scripts/ui/tutorial_overlay.gd")
const RESULTS := preload("res://scripts/ui/results.gd")
const WORLD := preload("res://scripts/world/world.gd")
const BACKDROP := preload("res://scripts/world/backdrop.gd")
const DEMO_DIRECTOR := preload("res://scripts/tools/demo_director.gd")
const TUTORIAL_DIRECTOR := preload("res://scripts/tools/tutorial_director.gd")

enum State { MENU, PLAYING, PAUSED, CALIBRATION, HELP, RESULTS }

var state := State.MENU
var backdrop: Control
var world: Node2D
var hud: Control
var menu: Control
var pause_screen: Control
var calibration: Control
var help_screen: Control
var results: Control
var tutorial_overlay: Control

var _bg_layer: CanvasLayer
var _ui_layer: CanvasLayer
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _calibration_from_pause := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg_layer = CanvasLayer.new()
	_bg_layer.layer = -20
	add_child(_bg_layer)
	backdrop = BACKDROP.new()
	backdrop.name = "Backdrop"
	_bg_layer.add_child(backdrop)

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 50
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.005, 0.01, 0.016, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)

	show_menu(true)
	var args := OS.get_cmdline_user_args()
	if "--tutorial-demo" in args:
		var tut_director := TUTORIAL_DIRECTOR.new()
		add_child(tut_director)
		tut_director.setup(self)
	elif "--demo" in args:
		var director := DEMO_DIRECTOR.new()
		add_child(director)
		director.setup(self)
	elif "--tutorial" in args:
		call_deferred("start_game", true, false)
	elif "--autostart" in args:
		call_deferred("start_game", false, false)
	_handle_capture_args(args)


func _unhandled_input(event: InputEvent) -> void:
	if state == State.PLAYING and event.is_action_pressed("pause"):
		_open_pause()
		get_viewport().set_input_as_handled()


func show_menu(first: bool = false) -> void:
	state = State.MENU
	get_tree().paused = false
	Conductor.set_paused(false)
	Conductor.stop_all()
	AudioBank.stop_all_sfx()
	_clear_run()
	_clear_screens()
	backdrop.set_mode("menu")
	backdrop.set_stage(0)
	menu = MENU.new()
	_ui_layer.add_child(menu)
	menu.start_requested.connect(_start_from_menu)
	menu.tutorial_requested.connect(_start_tutorial)
	menu.calibration_requested.connect(_open_calibration_from_menu)
	menu.help_requested.connect(_open_help)
	menu.quit_requested.connect(_quit)
	fade_in(0.7 if not first else 0.9)


func _start_from_menu() -> void:
	start_game(false, true)


func _start_tutorial() -> void:
	start_game(true, false)


func start_game(tutorial: bool = false, auto_tutorial: bool = true) -> void:
	var run_tutorial := tutorial or (auto_tutorial and not Settings.tutorial_seen)
	get_tree().paused = false
	Conductor.set_paused(false)
	Conductor.stop_all()
	AudioBank.stop_all_sfx()
	GameState.reset_run()
	_clear_run()
	_clear_screens()
	backdrop.set_mode("level")
	backdrop.set_stage(0)
	state = State.PLAYING

	hud = HUD.new()
	_ui_layer.add_child(hud)

	world = WORLD.new()
	world.name = "World"
	add_child(world)
	world.run_complete.connect(_on_run_complete)
	world.build(backdrop, run_tutorial)
	if run_tutorial:
		tutorial_overlay = TUTORIAL.new()
		tutorial_overlay.setup(world)
		_ui_layer.add_child(tutorial_overlay)
		tutorial_overlay.finished.connect(_on_tutorial_finished)
	fade_in(0.55)


func _on_tutorial_finished(skipped: bool) -> void:
	if is_instance_valid(tutorial_overlay):
		tutorial_overlay.queue_free()
	tutorial_overlay = null
	Settings.mark_tutorial_seen()
	if is_instance_valid(world):
		world.finish_tutorial(skipped)


func _open_pause() -> void:
	if state != State.PLAYING or world == null:
		return
	state = State.PAUSED
	_conductor_pause(true)
	get_tree().paused = true
	pause_screen = PAUSE.new()
	_ui_layer.add_child(pause_screen)
	pause_screen.resume_requested.connect(_resume)
	pause_screen.calibration_requested.connect(_open_calibration_from_pause)
	pause_screen.restart_requested.connect(_restart)
	pause_screen.title_requested.connect(_to_title)


func _resume() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	_conductor_pause(false)
	if is_instance_valid(pause_screen):
		pause_screen.queue_free()
	pause_screen = null


func _open_calibration_from_menu() -> void:
	state = State.CALIBRATION
	_calibration_from_pause = false
	if is_instance_valid(menu):
		menu.visible = false
	_open_calibration()


func _open_calibration_from_pause() -> void:
	state = State.CALIBRATION
	_calibration_from_pause = true
	if is_instance_valid(pause_screen):
		pause_screen.visible = false
	_open_calibration()


func _open_calibration() -> void:
	calibration = CALIBRATION.new()
	_ui_layer.add_child(calibration)
	calibration.closed.connect(_on_calibration_closed)


func _on_calibration_closed(_applied: bool) -> void:
	if is_instance_valid(calibration):
		calibration.queue_free()
	calibration = null
	if _calibration_from_pause:
		state = State.PAUSED
		if is_instance_valid(pause_screen):
			pause_screen.visible = true
	else:
		state = State.MENU
		if is_instance_valid(menu):
			menu.visible = true


func _open_help() -> void:
	state = State.HELP
	if is_instance_valid(menu):
		menu.visible = false
	help_screen = HELP.new()
	_ui_layer.add_child(help_screen)
	help_screen.closed.connect(_close_help)


func _close_help() -> void:
	if is_instance_valid(help_screen):
		help_screen.queue_free()
	help_screen = null
	state = State.MENU
	if is_instance_valid(menu):
		menu.visible = true


func _restart() -> void:
	get_tree().paused = false
	Conductor.set_paused(false)
	Conductor.stop_all()
	AudioBank.stop_all_sfx()
	_clear_run()
	_clear_screens()
	start_game(not Settings.tutorial_seen, false)


func _to_title() -> void:
	get_tree().paused = false
	Conductor.set_paused(false)
	show_menu()


func _on_run_complete(_victory: bool, _success: bool, _hits: int) -> void:
	if state == State.RESULTS:
		return
	get_tree().paused = true
	Conductor.set_paused(false)
	AudioBank.stop_all_sfx()
	state = State.RESULTS
	if is_instance_valid(hud):
		hud.visible = false
	backdrop.set_mode("boss")
	backdrop.set_stage(3)
	results = RESULTS.new()
	_ui_layer.add_child(results)
	results.replay_requested.connect(_replay)
	results.title_requested.connect(_to_title)


func _replay() -> void:
	get_tree().paused = false
	if is_instance_valid(results):
		results.queue_free()
	results = null
	start_game(false, false)


func _clear_run() -> void:
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = null
	if is_instance_valid(hud):
		hud.queue_free()
	hud = null


func _clear_screens() -> void:
	for node in [menu, pause_screen, calibration, help_screen, results, tutorial_overlay]:
		if is_instance_valid(node):
			node.queue_free()
	menu = null
	pause_screen = null
	calibration = null
	help_screen = null
	results = null
	tutorial_overlay = null


func _conductor_pause(value: bool) -> void:
	Conductor.set_paused(value)
	if value:
		AudioBank.stop_all_sfx()


func fade_in(duration: float = 0.5) -> void:
	_fade.color.a = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)


func _quit() -> void:
	get_tree().quit()


# --------------------------------------------------------------------------- #
# automated visual capture (development convenience)
# --------------------------------------------------------------------------- #
func _handle_capture_args(args: PackedStringArray) -> void:
	for arg: String in args:
		if arg.begins_with("--capture="):
			var target := arg.substr("--capture=".length())
			_capture(target)


func _capture(target: String) -> void:
	await get_tree().create_timer(1.2).timeout
	if target == "game":
		await get_tree().create_timer(0.4).timeout
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
			e.activated = false
		if is_instance_valid(world):
			world.player.global_position = Vector2(470, 560)
		await get_tree().create_timer(4.6).timeout
	elif target == "combat" and is_instance_valid(world):
		var enemy_list := get_tree().get_nodes_in_group("enemies")
		if not enemy_list.is_empty():
			var dummy: Node2D = enemy_list[0]
			dummy.global_position = Vector2(900, 610)
			dummy.activated = false
			dummy.set_physics_process(false)
		world.player.global_position = Vector2(804, 560)
		world.player.facing = 1
		await get_tree().create_timer(0.25).timeout
		world.player.call("_start_attack", "heavy")
		await get_tree().create_timer(0.34).timeout
	elif target == "tutorial":
		await get_tree().create_timer(0.9).timeout
	elif target == "stage2" and is_instance_valid(world):
		world.player.global_position = Vector2(3000, 560)
		await get_tree().create_timer(1.2).timeout
	elif target == "stage3" and is_instance_valid(world):
		world.player.global_position = Vector2(5200, 560)
		await get_tree().create_timer(1.2).timeout
	elif target == "seal" and is_instance_valid(world):
		for e: Node in get_tree().get_nodes_in_group("enemies"):
			e.visible = false
			e.set_physics_process(false)
		world.call("_open_seal", 0)
		world.player.global_position = Vector2(1590, 560)
		world.player.heal(100.0)
		await get_tree().create_timer(6.2).timeout
	elif target == "boss" and is_instance_valid(world):
		world.player.global_position = Vector2(7060, 560)
		await get_tree().create_timer(5.0).timeout
	elif target == "finale" and is_instance_valid(world):
		world.player.global_position = Vector2(7060, 560)
		await get_tree().create_timer(4.5).timeout
		world.player.global_position = Vector2(7460, 560)
		if is_instance_valid(world.boss):
			world.boss.call("force_finale")
			print("CAPTURE finale boss state=", world.boss.state,
				" hud active=", hud.finale_active if is_instance_valid(hud) else "?")
		await get_tree().create_timer(0.8).timeout
	elif target == "pause" and is_instance_valid(world):
		_open_pause()
		await get_tree().create_timer(0.3).timeout
	elif target == "calibration":
		_open_calibration_from_menu()
		await get_tree().create_timer(1.1).timeout
	elif target == "help":
		_open_help()
		await get_tree().create_timer(0.5).timeout
	elif target == "results" or target == "perfect":
		GameState.hits = 20
		GameState.perfect = 14
		GameState.great = 4
		GameState.good = 2
		GameState.off = 0
		GameState.max_combo = 26
		GameState.combo = 0
		GameState.key_notes = 4
		GameState.finale_hits = 4
		GameState.finale_success = true
		GameState.coda_restored = true
		GameState.layers = [true, true, true, true]
		GameState.boss_defeated = true
		GameState.used_attacks = {"light": true, "heavy": true,
			"thrust": true, "launcher": true}
		GameState.damage_taken = 18.0
		GameState.hits_taken = 2
		GameState.dodges = 6
		GameState.deaths = 0
		GameState.elapsed = 218.0
		if target == "perfect":
			GameState.perfect = 18
			GameState.great = 2
			GameState.good = 0
			GameState.hits = 20
		else:
			GameState.finale_hits = 3
			GameState.finale_success = false
			GameState.coda_restored = false
		_on_run_complete(true, true, 4)
		await get_tree().create_timer(1.0).timeout
	var image := get_viewport().get_texture().get_image()
	var dir := "res://screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/shot_%s.png" % [dir, target]
	image.save_png(path)
	print("CAPTURED ", ProjectSettings.globalize_path(path))
	if "--quit-after-capture" in OS.get_cmdline_user_args():
		get_tree().quit()
