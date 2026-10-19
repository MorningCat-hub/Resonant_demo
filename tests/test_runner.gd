extends Node
## Headless logic + integration suite.  Scene (not --script) so autoloads and
## global classes resolve exactly as they do in the game.

const MAIN := preload("res://scenes/Main.tscn")
const LEVEL_ART := preload("res://scripts/world/level_art.gd")

var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_test_rhythm()
	_test_config()
	_test_game_state()
	_test_audio()
	await _test_level()
	await _test_calibration()
	await _test_tutorial()
	await _test_scene_flow()
	_report()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: ", label)


func near(a: float, b: float, eps: float, label: String) -> void:
	check(absf(a - b) <= eps, "%s (got %.4f, want %.4f)" % [label, a, b])


func _test_rhythm() -> void:
	var info := Rhythm.beat_info(1.25)
	check(int(info.beat) == 2, "beat index at 1.25s")
	check(int(info.beat_in_bar) == 2, "beat in bar at 1.25s")
	near(float(info.phase), 0.5, 0.001, "beat phase")
	near(Rhythm.delta_to_beat(0.52), 0.02, 0.001, "signed beat delta")
	near(Rhythm.delta_to_beat(0.47), -0.03, 0.001, "negative beat delta")
	check(Rhythm.grade_for_delta(0.050) == Rhythm.Grade.PERFECT, "PERFECT boundary")
	check(Rhythm.grade_for_delta(0.051) == Rhythm.Grade.GREAT, "GREAT at 51ms")
	check(Rhythm.grade_for_delta(0.100) == Rhythm.Grade.GREAT, "GREAT boundary")
	check(Rhythm.grade_for_delta(0.150) == Rhythm.Grade.GOOD, "GOOD at 150ms")
	check(Rhythm.grade_for_delta(0.180) == Rhythm.Grade.GOOD, "GOOD boundary")
	check(Rhythm.grade_for_delta(0.181) == Rhythm.Grade.OFF, "OFF over 180ms")
	check(Rhythm.grade_for_delta(-0.05) == Rhythm.Grade.PERFECT, "absolute delta")
	var judged := Rhythm.judge_at(1.02)
	near(float(judged.delta_ms), 20.0, 0.1, "judge delta ms")
	check(Rhythm.grade_name(Rhythm.Grade.PERFECT) == "PERFECT", "grade label")
	check(Rhythm.GRADE_COLORS.size() == 4, "grade palette size")


func _test_config() -> void:
	check(GameConfig.ATTACKS.size() == 4, "four attacks configured")
	for id: String in GameConfig.ATTACKS.keys():
		var a: Dictionary = GameConfig.ATTACKS[id]
		check(float(a.startup) > 0.0, id + " has startup")
		check(float(a.active) > 0.0, id + " has active frames")
		check(float(a.recovery) > 0.0, id + " has recovery")
		check(float(a.damage) > 0.0, id + " deals damage")
		var total := float(a.startup) + float(a.active) + float(a.recovery)
		check(total < 1.2, id + " total duration under 1.2s")
	check(GameConfig.ENEMIES.size() == 4, "four enemy types")
	check(float(GameConfig.BOSS.hp) > 400.0, "boss health")
	check(GameConfig.FINALE_SEQUENCE.size() == 4, "four finale prompts")
	var actions := {}
	for item: Dictionary in GameConfig.FINALE_SEQUENCE:
		actions[item.action] = true
	check(actions.size() == 4, "finale uses four different attacks")
	near(GameConfig.GRAVITY, 2250.0, 0.01, "gravity tuning")


func _test_game_state() -> void:
	GameState.reset_run()
	GameState.register_hit("light", Rhythm.Grade.PERFECT, 2.0)
	GameState.register_hit("heavy", Rhythm.Grade.PERFECT, 2.0)
	GameState.register_hit("thrust", Rhythm.Grade.PERFECT, 2.0)
	GameState.register_hit("launcher", Rhythm.Grade.PERFECT, 2.0)
	check(GameState.hits == 4, "hit counter")
	check(GameState.perfect == 4 and GameState.great == 0, "grade counters")
	check(GameState.combo == 4 and GameState.max_combo == 4, "combo counter")
	check(GameState.used_all_attacks(), "attack variety tracked")
	near(GameState.accuracy(), 1.0, 0.001, "weighted accuracy")
	GameState.register_hurt(10.0)
	check(GameState.combo == 0, "hurt breaks combo")
	check(GameState.damage_taken == 10.0, "damage tracked")
	GameState.register_dodge()
	check(GameState.dodges == 1, "dodge tracked")
	check(GameState.unlock_layer(1), "layer unlock accepted")
	check(not GameState.unlock_layer(1), "duplicate layer rejected")
	check(GameState.layer_count() == 2, "layer count after unlock")
	GameState.key_notes = 4
	GameState.boss_defeated = true
	GameState.finale_hits = 4
	GameState.finale_success = true
	GameState.max_combo = 12
	GameState.layers = [true, true, true, true]
	check(GameState.is_perfect(), "perfect performance condition")
	check(GameState.rank_data().code == "S", "perfect rank S")
	GameState.finale_hits = 2
	check(not GameState.is_perfect(), "imperfect run rejected")
	check(GameState.rank_data().code != "S", "imperfect rank below S")
	GameState.reset_run()
	check(GameState.combo == 0 and GameState.hits == 0, "reset clears run")
	check(GameState.layers[0] and not GameState.layers[1], "run starts with pulse only")
	check(GameState.layer_count() == 1, "one active layer at start")
	check(is_equal_approx(GameState.music_fraction(), 0.2), "music fraction start")


func _test_audio() -> void:
	check(AudioBank.sfx.size() >= 30, "SFX loaded")
	check(AudioBank.music.size() == 7, "seven music stems")
	var pulse: AudioStream = AudioBank.music.get("level_pulse")
	var bass: AudioStream = AudioBank.music.get("level_bass")
	check(pulse != null and bass != null, "level stems present")
	if pulse:
		near(pulse.get_length(), 64.0, 0.05, "stem length is 64s")
	if pulse is AudioStreamWAV:
		check((pulse as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"pulse loop enabled")
	if bass:
		near(bass.get_length(), 64.0, 0.05, "bass length matches pulse")
	check(AudioBank.sfx.has("hit_heavy") and AudioBank.sfx.has("perfect"),
		"impact and judgement SFX present")


func _test_level() -> void:
	var art := LEVEL_ART.new()
	add_child(art)
	await get_tree().process_frame
	check(LEVEL_ART.FLOORS.size() >= 4, "floor sections")
	check(LEVEL_ART.PLATFORMS.size() >= 10, "platform count")
	check(LEVEL_ART.GATES.size() == 4, "gate positions")
	var bodies := 0
	for child in art.get_children():
		if child is StaticBody2D:
			bodies += 1
	check(bodies == LEVEL_ART.FLOORS.size() + LEVEL_ART.PLATFORMS.size(),
		"collision body per platform")
	art.queue_free()


func _test_calibration() -> void:
	var cal_script := preload("res://scripts/ui/calibration.gd")
	var cal: Control = cal_script.new()
	add_child(cal)
	await get_tree().process_frame
	for i in 8:
		cal._elapsed = 0.53 + i * 0.5
		cal._tap()
	check(cal.taps.size() == 8, "calibration collects eight taps")
	check(not cal._measuring, "calibration stops after eight taps")
	check(absf(cal.candidate + 30.0) < 1.0, "calibration suggests inverse median")
	cal.queue_free()
	await get_tree().process_frame


func _test_tutorial() -> void:
	var original_seen: bool = Settings.tutorial_seen
	Settings.tutorial_seen = false
	var main := MAIN.instantiate()
	add_child(main)
	await get_tree().create_timer(0.2).timeout
	main.start_game(false, true)
	await get_tree().create_timer(0.35).timeout
	check(main.world != null and main.world.tutorial_mode,
		"first run enters the tutorial")
	check(main.tutorial_overlay != null, "tutorial overlay is present")
	check(main.world.tutorial_dummy != null, "tutorial room has a practice dummy")
	check(main.world.tutorial_gate != null, "tutorial room has a barrier")
	var first_enemy: Node = get_tree().get_nodes_in_group("enemies")[0]
	check(not first_enemy.visible, "normal enemies wait during the tutorial")
	var jump_events := InputMap.action_get_events("jump")
	var has_w := false
	for ev: InputEvent in jump_events:
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == KEY_W:
			has_w = true
	check(has_w, "jump is bound to W")

	var overlay: Control = main.tutorial_overlay
	var player: Node2D = main.world.player
	player.global_position.x += 120.0
	await get_tree().create_timer(0.65).timeout
	check(overlay.step >= 1, "tutorial advances after movement")
	player.state = "Jump"
	player.velocity.y = -200.0
	await get_tree().create_timer(0.65).timeout
	check(overlay.step >= 2, "tutorial advances after a jump")
	GameState.used_attacks["light"] = true
	await get_tree().create_timer(0.65).timeout
	check(overlay.step >= 3, "tutorial advances after a light hit")
	GameState.perfect += 1
	await get_tree().create_timer(0.65).timeout
	check(overlay.step >= 4, "tutorial advances after a clean hit")
	GameState.used_attacks["heavy"] = true
	GameState.used_attacks["thrust"] = true
	GameState.used_attacks["launcher"] = true
	await get_tree().create_timer(0.65).timeout
	check(overlay.step >= 5, "tutorial advances after three techniques")
	player.dodge_actions += 1
	await get_tree().create_timer(0.65).timeout
	check(overlay.step >= 6, "tutorial reaches its completion card")
	await get_tree().create_timer(2.2).timeout
	check(main.tutorial_overlay == null, "tutorial overlay closes after completion")
	check(not main.world.tutorial_mode, "tutorial mode ends")
	check(main.world.tutorial_gate.is_open, "tutorial barrier opens")
	check(first_enemy.visible, "normal enemies wake after the tutorial")
	check(Settings.tutorial_seen, "tutorial completion is remembered")
	Settings.tutorial_seen = original_seen
	Settings.save_settings()
	main.queue_free()
	await get_tree().process_frame


func _test_scene_flow() -> void:
	var main := MAIN.instantiate()
	add_child(main)
	await get_tree().create_timer(0.25).timeout
	check(main.menu != null, "menu booted")
	main.start_game(false, false)
	await get_tree().create_timer(0.35).timeout
	check(main.world != null, "world built")
	check(main.hud != null, "HUD built")
	check(main.state == 1, "state is PLAYING")
	check(main.world.player != null, "player spawned")
	check(Conductor.playing, "level music playing")
	check(Conductor.song_id == "level", "level song selected")
	check(GameState.hits == 0, "run starts clean")

	var player: Node2D = main.world.player
	var x0: float = player.global_position.x
	Input.action_press("move_right")
	await get_tree().create_timer(0.45).timeout
	Input.action_release("move_right")
	check(player.global_position.x > x0 + 70.0, "A/D input moves the player")
	await get_tree().create_timer(0.25).timeout
	var ground_y: float = player.global_position.y
	Input.action_press("jump")
	await get_tree().create_timer(0.12).timeout
	Input.action_release("jump")
	check(player.global_position.y < ground_y - 20.0, "W jumps")
	await get_tree().create_timer(0.8).timeout

	var enemies := get_tree().get_nodes_in_group("enemies")
	check(enemies.size() == 12, "all enemies spawned")
	if enemies.is_empty():
		return
	var enemy: Node2D = enemies[0]
	enemy.activated = false
	enemy.state = "Idle"
	enemy.set_physics_process(false)
	enemy.global_position = Vector2(900, 610)
	player.global_position = Vector2(804, 560)
	player.velocity = Vector2.ZERO
	player.facing = 1
	await get_tree().create_timer(0.2).timeout
	var hp_before: float = enemy.hp
	Input.action_press("attack_heavy")
	await get_tree().create_timer(0.10).timeout
	Input.action_release("attack_heavy")
	await get_tree().create_timer(0.42).timeout
	check(enemy.hp < hp_before, "heavy input damages an enemy")
	check(GameState.hits >= 1, "first hit registered with the conductor")
	check(GameState.combo >= 1, "combo begins on hit")
	check(player.state in ["HeavyAttack", "Idle", "Fall"], "attack returns to control")

	main.call("_open_pause")
	await get_tree().create_timer(0.06).timeout
	check(get_tree().paused, "pause freezes the tree")
	check(Conductor.paused, "pause freezes the audio clock")
	var paused_timeline: float = Conductor.get_timeline()
	await get_tree().create_timer(0.2).timeout
	check(absf(Conductor.get_timeline() - paused_timeline) < 0.02,
		"pause freezes the scheduling timeline")
	main.call("_resume")
	await get_tree().create_timer(0.2).timeout
	check(not get_tree().paused, "resume unfreezes the tree")
	check(not Conductor.paused, "resume unfreezes the audio clock")
	check(Conductor.get_timeline() > paused_timeline + 0.1,
		"resume advances the scheduling timeline")

	# Clearing the encounter spawns the real seal; the seal restores a stem.
	for e: Node in enemies:
		if is_instance_valid(e) and int(e.encounter_id) == 0 and not e.dead:
			e.call("receive_attack", {
				"damage": 999.0, "attack_id": "heavy", "direction": 1,
				"poise": 999.0, "knockback": 0.0, "lift": 0.0,
				"hitstop": 0.0, "source": player,
			})
	await get_tree().create_timer(0.2).timeout
	check(main.world._cleared[0], "encounter clear flag")
	check(main.world._seal != null, "clearing the encounter spawns a seal")
	var seal: Node2D = main.world._seal
	var t := Conductor.get_song_time()
	var nearest := roundf(t / Rhythm.BEAT) * Rhythm.BEAT
	Settings.set_offset((nearest - t) * 1000.0, false)
	for i in 3:
		seal.receive_attack({
			"damage": 1.0, "attack_id": "light", "direction": 1,
			"poise": 1.0, "knockback": 0.0, "lift": 0.0,
			"source": player,
		})
	await get_tree().create_timer(0.1).timeout
	check(GameState.layers[1], "seal restores the low-end layer")
	check(main.world._gates[0].is_open, "first gate opens after the seal")
	Settings.set_offset(0.0, false)
	await get_tree().create_timer(2.4).timeout
	var bass_player: AudioStreamPlayer = Conductor.players["level_bass"]
	check(bass_player != null and bass_player.volume_db > -30.0,
		"low-end stem fades in at a bar boundary")

	# Requirement-specific seals: heavy break, then varied phrase.
	var seal_script := preload("res://scripts/world/resonance_seal.gd")
	var seal2: Node2D = seal_script.new()
	seal2.setup(1, "heavy2", 2400.0, ResonantUI.BLUE, main.world)
	main.world.add_child(seal2)
	var now2 := Conductor.get_song_time()
	Settings.set_offset((roundf(now2 / Rhythm.BEAT) * Rhythm.BEAT - now2) * 1000.0, false)
	seal2.receive_attack({"damage": 1.0, "attack_id": "light", "direction": 1,
		"poise": 1.0, "knockback": 0.0, "lift": 0.0, "source": player})
	check(seal2.progress == 0, "heavy seal rejects a light attack")
	for i in 2:
		seal2.receive_attack({"damage": 1.0, "attack_id": "heavy", "direction": 1,
			"poise": 1.0, "knockback": 0.0, "lift": 0.0, "source": player})
	await get_tree().create_timer(0.08).timeout
	check(GameState.layers[2], "heavy seal restores the melody layer")
	var seal3: Node2D = seal_script.new()
	seal3.setup(2, "variety3", 5000.0, ResonantUI.CORAL, main.world)
	main.world.add_child(seal3)
	var now3 := Conductor.get_song_time()
	Settings.set_offset((roundf(now3 / Rhythm.BEAT) * Rhythm.BEAT - now3) * 1000.0, false)
	for attack in ["light", "thrust", "launcher"]:
		seal3.receive_attack({"damage": 1.0, "attack_id": attack, "direction": 1,
			"poise": 1.0, "knockback": 0.0, "lift": 0.0, "source": player})
	await get_tree().create_timer(0.08).timeout
	check(GameState.layers[3], "variety seal restores the harmony layer")
	check(GameState.has_all_layers(), "all four voices restored")
	Settings.set_offset(0.0, false)

	# Guard armour / heavy break.
	var enemy_script := preload("res://scripts/enemies/enemy.gd")
	var guard: Node2D = enemy_script.new()
	guard.setup("guard", player, main.world.fx, main.world)
	guard.encounter_id = -1
	guard.position = Vector2(300, 610)
	main.world.add_child(guard)
	guard.set_physics_process(false)
	player.global_position = Vector2(190, 605)
	player.velocity = Vector2.ZERO
	player.facing = 1
	player.state = "Idle"
	await get_tree().create_timer(0.15).timeout
	var guard_hp: float = guard.hp
	player.call("_start_attack", "light")
	await get_tree().create_timer(0.34).timeout
	check(is_equal_approx(guard.hp, guard_hp), "front armour blocks a light attack")
	await get_tree().create_timer(0.12).timeout
	player.call("_start_attack", "heavy")
	await get_tree().create_timer(0.48).timeout
	check(guard.hp < guard_hp, "heavy attack damages the guard")
	check(guard.armor_broken, "heavy attack breaks guard armour")
	guard.queue_free()

	# I-frames and death/respawn.
	var hp_now: float = player.hp
	var dodges_before: int = GameState.dodges
	player.invuln = 0.4
	player.receive_hit(10.0, Vector2(0, 0))
	check(is_equal_approx(player.hp, hp_now), "dodge i-frames prevent damage")
	check(GameState.dodges == dodges_before + 1, "dodged attack is counted")
	player.invuln = 0.0
	player.hp = 1.0
	player.receive_hit(10.0, Vector2(0, 0))
	check(player.dead, "lethal damage kills the player")
	await get_tree().create_timer(2.0).timeout
	check(not player.dead, "player respawns at a checkpoint")
	check(is_equal_approx(player.hp, player.max_hp), "respawn restores health")
	check(GameState.deaths >= 1, "death is recorded")

	# Finale / results plumbing.
	player.global_position = Vector2(7060, 560)
	await get_tree().create_timer(3.4).timeout
	check(main.world.boss != null, "boss spawned on arena trigger")
	check(main.world.boss.state != "", "boss has an active state")
	await get_tree().create_timer(0.2).timeout
	main.world.boss.call("_do_slam")
	main.world.boss.call("_do_sweep")
	main.world.boss.call("_do_arpeggio")
	await get_tree().create_timer(0.12).timeout
	check(get_tree().get_nodes_in_group("enemy_projectiles").size() >= 5,
		"boss arpeggio creates cuttable projectiles")
	var now_boss := Conductor.get_timeline()
	main.world.boss.call("_enter_phase", 2, now_boss)
	check(main.world.boss.phase == 2, "boss phase 2 transition")
	main.world.boss.call("_enter_phase", 3, now_boss)
	check(main.world.boss.phase == 3, "boss phase 3 transition")
	check(Conductor.boss_phase == 3, "boss music phase follows fight phase")
	main.world.boss.call("force_finale")
	await get_tree().create_timer(0.15).timeout
	var boss_node: Node2D = main.world.boss
	var future := Conductor.get_timeline() + 10.0
	for i in 4:
		boss_node.finale_prompt_times[i] = future
	for i in 4:
		var expected: String = GameConfig.FINALE_SEQUENCE[i].action
		boss_node.finale_prompt_times[i] = Conductor.get_timeline()
		boss_node.finale_index = i
		boss_node.call("_receive_finale_hit", {
			"damage": 0.0, "attack_id": expected, "direction": 1,
			"source": player,
		})
	await get_tree().create_timer(6.2).timeout
	check(main.state == 5, "results screen reached")
	check(main.results != null, "results panel instantiated")
	check(GameState.boss_defeated, "boss defeated flag")
	check(GameState.finale_hits == 4, "all four finale hits accepted")
	check(GameState.coda_restored, "coda restored on successful finale")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame


func _report() -> void:
	if failures.is_empty():
		print("PASS: %d checks" % checks)
		get_tree().quit(0)
	else:
		printerr("FAILED: %d / %d checks" % [failures.size(), checks])
		for f: String in failures:
			printerr("  - ", f)
		get_tree().quit(1)
