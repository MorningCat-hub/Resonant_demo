extends Node
## Development-only 28-second showcase driver.
##
## It starts a real run and uses the real attacks, Conductor and boss systems.
## It does teleport between areas and freeze non-featured enemies so a short
## capture can show every mechanic.

var main: Node
var t := 0.0
var _started := false
var _fired: Dictionary = {}
var _finale_started := false
var _stats_set := false
var _scheduled := [false, false, false, false]
var _quit_at := 28.6


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
		print("DEMO quit t=", t, " main_state=", main.state,
			" boss=", main.world.boss.state if main.world and main.world.boss else "none")
		get_tree().quit()
		return
	if not _started:
		if t >= 2.2:
			_started = true
			main.call("start_game", false, false)
		return
	if main.world == null or main.world.player == null:
		return
	var world: Node = main.world
	var player: Node2D = world.player

	if _once("move", 2.8):
		Input.action_press("move_right")
	if _once("jump", 3.25):
		Input.action_press("jump")
	if _once("jump_release", 3.48):
		Input.action_release("jump")
	if _once("stage_one", 4.0):
		Input.action_release("move_right")
		_stage_one(world, player)
	if _once("light1", 4.18):
		player.call("_start_attack", "light")
	if _once("light2", 4.48):
		player.call("_start_attack", "light")
	if _once("light3", 4.80):
		player.call("_start_attack", "light")
	if _once("stage_two", 5.35):
		_cut_to_stage_two(world, player)
	if _once("heavy_guard", 6.0):
		player.call("_start_attack", "heavy")
	if _once("stage_three", 7.15):
		_cut_to_stage_three(world, player)
	if _once("heavy_dissonant", 7.55):
		player.call("_start_attack", "heavy")
	if _once("boss_cut", 8.25):
		_cut_to_boss(world, player)
	if _once("invuln", 9.0):
		player.invuln = 999.0

	if _once("finale", 11.9):
		player.global_position = Vector2(7560, 560)
		player.velocity = Vector2.ZERO
		player.facing = 1
		if world.boss != null:
			world.boss.call("force_finale")
		_finale_started = true
		Settings.set_offset(0.0, false)

	if _finale_started and world.boss != null:
		_schedule_finale_attacks(player, world.boss)
	if _once("stats", 17.8):
		_stats_set = true
		_set_perfect_stats()
		if main.world.boss != null:
			print("DEMO finale hits=", main.world.boss.finale_hits,
				" results=", main.world.boss.finale_prompt_results,
				" state=", main.world.boss.state)


func _stage_one(world: Node, player: Node2D) -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		e.set_physics_process(false)
		e.activated = false
	var enemies := get_tree().get_nodes_in_group("enemies")
	if not enemies.is_empty():
		var e: Node2D = enemies[0]
		e.global_position = Vector2(900, 610)
	player.global_position = Vector2(804, 560)
	player.velocity = Vector2.ZERO
	player.state = "Idle"
	player.facing = 1
	GameEvents.flash.emit(Color(0.5, 0.95, 0.85, 0.10), 0.2)


func _cut_to_stage_two(world: Node, player: Node2D) -> void:
	GameState.unlock_layer(1)
	GameEvents.flash.emit(Color(0.8, 0.9, 1.0, 0.20), 0.28)
	player.global_position = Vector2(2650, 560)
	player.velocity = Vector2.ZERO
	player.state = "Idle"
	player.facing = 1
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "guard":
			e.global_position = Vector2(2750, 610)
			e.set_physics_process(false)
			break
	_quiet_hud()


func _cut_to_stage_three(world: Node, player: Node2D) -> void:
	GameState.unlock_layer(2)
	GameEvents.flash.emit(Color(1.0, 0.55, 0.55, 0.20), 0.28)
	player.global_position = Vector2(5030, 560)
	player.velocity = Vector2.ZERO
	player.state = "Idle"
	player.facing = 1
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "dissonant":
			e.global_position = Vector2(5120, 610)
			e.set_physics_process(false)
			break
	_quiet_hud()


func _cut_to_boss(world: Node, player: Node2D) -> void:
	GameState.unlock_layer(3)
	GameEvents.flash.emit(Color(1.0, 0.8, 0.5, 0.22), 0.35)
	player.global_position = Vector2(7060, 560)
	player.velocity = Vector2.ZERO
	_quiet_hud()


func _schedule_finale_attacks(player: Node2D, boss: Node) -> void:
	if boss.state != "Finale" or boss.finale_done:
		return
	var timeline := Conductor.get_timeline()
	for i in GameConfig.FINALE_SEQUENCE.size():
		if _scheduled[i] or boss.finale_prompt_results[i] != 0:
			continue
		var item: Dictionary = GameConfig.FINALE_SEQUENCE[i]
		var attack: Dictionary = GameConfig.attack(item.action)
		var target: float = boss.finale_prompt_times[i]
		if timeline >= target - float(attack.startup) - 0.018:
			_scheduled[i] = true
			player.facing = 1
			player.state = "Idle"
			player.call("_start_attack", item.action)


func _set_perfect_stats() -> void:
	GameState.hits = 22
	GameState.perfect = 19
	GameState.great = 3
	GameState.good = 0
	GameState.off = 0
	GameState.max_combo = 24
	GameState.damage_taken = 8.0
	GameState.hits_taken = 1
	GameState.dodges = 5
	GameState.deaths = 0
	GameState.key_notes = 4
	GameState.layers = [true, true, true, true]
	GameState.finale_hits = 4
	GameState.finale_success = true
	GameState.coda_restored = true
	GameState.boss_defeated = true
	GameState.used_attacks = {"light": true, "heavy": true,
		"thrust": true, "launcher": true}
	GameState.elapsed = 214.0


func _quiet_hud() -> void:
	if main.hud == null:
		return
	main.hud.set("title_timer", 0.0)
	main.hud.set("hint_timer", 0.0)
	main.hud.set("toast_timer", 0.0)
