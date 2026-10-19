extends Node2D
## 失序指挥家 — the final exam.
##
## Its attacks are scheduled against the Conductor's audio clock:
## telegraph on a beat, strike on the next.  Phase 2 shifts the interval and
## doubles a move.  Phase 3 only accepts damage through an exposed core, and
## the last four prompts ask the player to place four different attacks on
## four beats rather than mash them.

var player: Node2D
var fx: Node
var world: Node
var hp := 620.0
var max_hp := 620.0
var phase := 1
var state := "Intro"
var state_time := 0.0
var flash := 0.0
var dead := false
var core_open := false
var _move := ""
var _strike_time := 0.0
var _recover_until := 0.0
var _next_action_time := 0.0
var _core_end_time := 0.0
var _attacks_since_core := 0
var _move_index := 0
var _queued_followup := false
var _hit_flash := 0.0
var _death_time := 0.0
var _rng := RandomNumberGenerator.new()

var finale_start_time := 0.0
var finale_prompt_times: Array[float] = []
var finale_prompt_results: Array = []   # 0 pending, 1 success, 2 miss
var finale_index := 0
var finale_hits := 0
var finale_done := false
var finale_success := false
var _finale_finish_at := -1.0
var _last_player_hit := -10.0


func setup(p_player: Node2D, p_fx: Node, p_world: Node) -> void:
	player = p_player
	fx = p_fx
	world = p_world
	hp = GameConfig.BOSS.hp
	max_hp = hp
	_rng.seed = 0xB055
	add_to_group("hurtable")
	add_to_group("boss")
	z_index = 9
	GameEvents.boss_health_changed.emit(hp, max_hp)


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if fx == null:
		fx = get_tree().get_first_node_in_group("fx")
	GameEvents.boss_health_changed.emit(hp, max_hp)


func begin_fight() -> void:
	state = "Idle"
	state_time = 0.0
	_next_action_time = Conductor.get_timeline() + Conductor.time_to_next_beat() \
		+ Rhythm.BEAT * 4.0
	GameEvents.boss_started.emit()
	GameEvents.boss_phase_changed.emit(phase)


func _process(delta: float) -> void:
	state_time += delta
	flash = maxf(0.0, flash - delta * 5.0)
	_hit_flash = maxf(0.0, _hit_flash - delta * 8.0)
	if _last_player_hit > 0.0:
		_last_player_hit -= delta
	if dead:
		_death_time += delta
		queue_redraw()
		return
	if player == null:
		return
	var now := Conductor.get_timeline()
	match state:
		"Intro":
			pass
		"Idle":
			if now >= _next_action_time:
				_choose_move(now)
		"Telegraph":
			if now >= _strike_time:
				_strike(now)
		"Recover":
			if now >= _recover_until:
				_after_recover(now)
		"Transition":
			if now >= _recover_until:
				_state_idle(now, 2)
		"Core":
			if now >= _core_end_time:
				core_open = false
				state = "Recover"
				_recover_until = now + Rhythm.BEAT
				GameEvents.toast.emit("核心闭合", ResonantUI.MUTED)
		"Finale":
			_update_finale(now)
		"Death":
			pass
	queue_redraw()


func _state_idle(now: float, gap_beats: float) -> void:
	state = "Idle"
	state_time = 0.0
	core_open = false
	_next_action_time = now + Conductor.time_to_next_beat() + Rhythm.BEAT * gap_beats


func _choose_move(now: float) -> void:
	if phase >= 3 and _attacks_since_core >= 2:
		_begin_core(now)
		return
	var pool: Array
	if phase == 1:
		pool = ["slam", "sweep", "arpeggio"]
	elif phase == 2:
		pool = ["sweep", "slam", "arpeggio", "sweep"]
	else:
		pool = ["slam", "sweep", "arpeggio"]
	_move = pool[_move_index % pool.size()]
	_move_index += 1
	_attacks_since_core += 1
	state = "Telegraph"
	state_time = 0.0
	core_open = false
	# Phase 2 occasionally delays the strike by half a beat.  The tell is in
	# the animation; the player cannot rely on a fixed metronome.
	var beats_to_strike := 1.0
	if phase >= 2 and _rng.randf() < 0.42:
		beats_to_strike = 1.5
	if phase >= 3:
		beats_to_strike = 0.75 if _rng.randf() < 0.5 else 1.0
	_strike_time = now + beats_to_strike * Rhythm.BEAT
	AudioBank.play("boss_telegraph", 1.0 if phase < 3 else 0.82, -3.0)
	GameEvents.shake.emit(0.8)


func _strike(now: float) -> void:
	state = "Attack"
	state_time = 0.0
	match _move:
		"slam":
			_do_slam()
		"sweep":
			_do_sweep()
		"arpeggio":
			_do_arpeggio()
	# recovery is short enough to keep the pressure, long enough to punish
	var recovery := 1.0
	if phase == 2:
		recovery = 0.5
	elif phase == 3:
		recovery = 0.75
	_recover_until = now + recovery * Rhythm.BEAT + 0.12
	state = "Recover"
	if phase >= 2 and _move == "slam" and _rng.randf() < 0.55:
		_queued_followup = true
		_recover_until = now + Rhythm.BEAT * 0.5
	if _queued_followup:
		_queued_followup = false
		_strike_time = now + Rhythm.BEAT * 0.5
		_move = "sweep"
		state = "Telegraph"
		AudioBank.play("boss_telegraph", 1.15, -6.0)


func _do_slam() -> void:
	var color := Color("ff8a6b") if phase < 3 else Color("ff5f6d")
	AudioBank.play("boss_slam", 0.92, 0.0)
	GameEvents.shake.emit(12.0)
	GameEvents.flash.emit(Color(color, 0.16), 0.2)
	if fx:
		fx.spawn_shockwave(Vector2(global_position.x, 602), color, 360.0)
		for i in 9:
			fx.spawn_dust(Vector2(global_position.x + randf_range(-260, 260), 606), color)
	if player and absf(player.global_position.x - global_position.x) < 255.0 \
			and player.global_position.y > 548.0:
		player.receive_hit(22.0, global_position, 430.0)
		GameEvents.shake.emit(6.0)


func _do_sweep() -> void:
	var color := Color("b28dff") if phase < 3 else Color("ff5f6d")
	AudioBank.play("swing_heavy", 0.8, 0.0)
	if fx:
		fx.spawn_slash(global_position + Vector2(0, -120),
			1 if player.global_position.x > global_position.x else -1,
			color, 230.0, true)
	GameEvents.shake.emit(5.0)
	if player:
		var dx := player.global_position.x - global_position.x
		var facing_to_player := 1 if dx >= 0 else -1
		if signf(dx) == float(facing_to_player) and absf(dx) < 330.0 \
				and player.global_position.y > 418.0 and player.global_position.y < 606.0:
			player.receive_hit(18.0, global_position, 350.0)


func _do_arpeggio() -> void:
	var color := Color("8fb8ff") if phase < 3 else Color("ff8a6b")
	AudioBank.play("boss_shot", 0.7, -1.0)
	if world == null or not world.has_method("spawn_enemy_projectile"):
		return
	var ppos: Vector2 = player.get_center()
	for i in 5:
		var x := ppos.x + (i - 2) * 95.0
		var origin := Vector2(x, 160.0 + i * 18.0)
		world.spawn_enemy_projectile(origin, Vector2(x, 590.0), 10.0, color)
		if fx:
			fx.spawn_glyph(Vector2(x, 150.0), "♪", color, 18)


func _begin_core(now: float) -> void:
	_attacks_since_core = 0
	state = "Core"
	state_time = 0.0
	core_open = true
	_core_end_time = now + Rhythm.BEAT * 4.0
	AudioBank.play("seal_complete", 0.82, -4.0)
	GameEvents.toast.emit("核心暴露 · 抓住四拍", ResonantUI.GOLD)
	GameEvents.flash.emit(Color(1.0, 0.82, 0.4, 0.1), 0.3)
	if fx:
		fx.spawn_unlock(global_position + Vector2(0, -125), ResonantUI.GOLD)


func _after_recover(now: float) -> void:
	if phase == 1 and hp <= max_hp * float(GameConfig.BOSS.phase_2):
		_enter_phase(2, now)
		return
	if phase == 2 and hp <= max_hp * float(GameConfig.BOSS.phase_3):
		_enter_phase(3, now)
		return
	var gap := 1.0
	if phase == 2:
		gap = 0.5
	elif phase == 3:
		gap = 1.0
	_state_idle(now, gap)


func _enter_phase(new_phase: int, now: float) -> void:
	phase = new_phase
	state = "Transition"
	state_time = 0.0
	_recover_until = now + Rhythm.BEAT * 2.0
	core_open = false
	Conductor.set_boss_phase(phase)
	GameEvents.boss_phase_changed.emit(phase)
	GameEvents.flash.emit(Color(1.0, 0.55, 0.35, 0.18), 0.35)
	GameEvents.shake.emit(10.0)
	AudioBank.play("seal_complete", 0.62, -3.0)
	if fx:
		fx.spawn_unlock(global_position + Vector2(0, -120),
			Color("ff8a6b") if phase == 2 else Color("ffd166"))
	if phase == 2:
		GameEvents.toast.emit("第二乐章 · 变奏", ResonantUI.CORAL)
	elif phase == 3:
		GameEvents.toast.emit("第三乐章 · 终章", ResonantUI.GOLD)


# --------------------------------------------------------------------------- #
# damage interface
# --------------------------------------------------------------------------- #
func receive_attack(info: Dictionary) -> Dictionary:
	if dead:
		return {"hit": false}
	if state == "Transition" or state == "Intro":
		return {"hit": true, "blocked": true, "damage": 0.0, "killed": false,
			"count_rhythm": false, "fx_pos": global_position + Vector2(0, -130),
			"color": Color("d9e2ff")}
	if state == "Finale":
		return _receive_finale_hit(info)
	if state == "Core" and core_open:
		var damage := float(info.damage) * float(GameConfig.BOSS.core_damage_scale)
		_apply_damage(damage)
		AudioBank.play("boss_hurt", 1.1, 0.0)
		GameEvents.shake.emit(4.0)
		if fx:
			fx.spawn_judgement_text(global_position + Vector2(0, -160),
				"核心", ResonantUI.GOLD, 20)
		return {"hit": true, "blocked": false, "damage": damage,
			"killed": false, "crit": true,
			"count_rhythm": true,
			"fx_pos": global_position + Vector2(0, -128),
			"color": ResonantUI.GOLD}
	if phase >= 3:
		AudioBank.play("hit_armor", 0.7, -3.0)
		return {"hit": true, "blocked": true, "damage": 0.0, "killed": false,
			"count_rhythm": false,
			"fx_pos": global_position + Vector2(0, -120),
			"color": Color("d9e2ff")}
	var damage := float(info.damage) * (float(GameConfig.BOSS.body_damage_scale) if phase >= 3 else 1.0)
	_apply_damage(damage)
	AudioBank.play("boss_hurt", 1.0, -2.0)
	GameEvents.shake.emit(2.5)
	return {"hit": true, "blocked": false, "damage": damage,
		"killed": false, "crit": false, "count_rhythm": true,
		"fx_pos": global_position + Vector2(0, -130), "color": ResonantUI.CORAL}


func _apply_damage(damage: float) -> void:
	hp = maxf(0.0, hp - damage)
	flash = 1.0
	_hit_flash = 1.0
	GameEvents.boss_health_changed.emit(hp, max_hp)
	if hp <= 0.0 and state != "Finale":
		begin_finale()


func get_hurtbox() -> Rect2:
	if state == "Finale":
		return Rect2(global_position + Vector2(-70, -180), Vector2(140, 130))
	if state == "Core" and core_open:
		return Rect2(global_position + Vector2(-58, -172), Vector2(116, 110))
	return Rect2(global_position + Vector2(-82, -255), Vector2(164, 245))


func get_core_center() -> Vector2:
	return global_position + Vector2(0, -132)


# --------------------------------------------------------------------------- #
# final performance
# --------------------------------------------------------------------------- #
func begin_finale() -> void:
	if state == "Finale":
		return
	state = "Finale"
	state_time = 0.0
	core_open = true
	hp = 0.0
	GameEvents.boss_health_changed.emit(0, max_hp)
	var now_music := Conductor.get_song_time()
	var now := Conductor.get_timeline()
	var to_bar := Rhythm.BAR - fposmod(now_music, Rhythm.BAR)
	if to_bar < 0.25:
		to_bar += Rhythm.BAR
	finale_start_time = now + to_bar
	finale_prompt_times.clear()
	finale_prompt_results.clear()
	for i in GameConfig.FINALE_SEQUENCE.size():
		finale_prompt_times.append(finale_start_time + i * 2.0 * Rhythm.BEAT)
		finale_prompt_results.append(0)
	finale_index = 0
	finale_hits = 0
	finale_done = false
	finale_success = false
	_finale_finish_at = -1.0
	GameState.finale_start_time = finale_start_time
	GameState.finale_results = [0, 0, 0, 0]
	GameState.finale_hits = 0
	GameState.finale_success = false
	GameEvents.finale_started.emit()
	if not GameConfig.FINALE_SEQUENCE.is_empty():
		GameEvents.finale_prompt.emit(0, GameConfig.FINALE_SEQUENCE[0].action,
			GameConfig.FINALE_SEQUENCE[0].key)
	GameEvents.flash.emit(Color(1.0, 0.85, 0.5, 0.2), 0.35)
	AudioBank.play("seal_complete", 0.55, -2.0)
	if fx:
		fx.spawn_beam(global_position + Vector2(-260, -130),
			global_position + Vector2(260, -130), ResonantUI.GOLD)


func _update_finale(now: float) -> void:
	if finale_done:
		if _finale_finish_at >= 0.0 and now >= _finale_finish_at:
			_finish_finale()
		return
	for i in GameConfig.FINALE_SEQUENCE.size():
		if finale_prompt_results[i] != 0:
			continue
		var target := finale_prompt_times[i]
		if now > target + Rhythm.FINALE_WINDOW:
			finale_prompt_results[i] = 2
			GameState.finale_results[i] = 2
			if i == finale_index:
				finale_index += 1
				GameEvents.finale_hit.emit(i, false, finale_hits)
				AudioBank.play("ui_back", 0.8, -8.0)
				_announce_next_prompt()
	if finale_index >= GameConfig.FINALE_SEQUENCE.size() and not finale_done:
		var last := finale_prompt_times[finale_prompt_times.size() - 1]
		if now > last + Rhythm.BEAT:
			_end_finale()
	elif _all_prompts_resolved() and not finale_done:
		_end_finale()


func _all_prompts_resolved() -> bool:
	for value: int in finale_prompt_results:
		if value == 0:
			return false
	return true


func _receive_finale_hit(info: Dictionary) -> Dictionary:
	var now := Conductor.get_timeline()
	var action: String = info.get("attack_id", "light")
	var core_pos: Vector2 = get_core_center()
	# Only one attempt per prompt.  Accept a hit within the visible window;
	# early hits are blocked and do not consume the prompt.
	for i in GameConfig.FINALE_SEQUENCE.size():
		if finale_prompt_results[i] != 0:
			continue
		var target := finale_prompt_times[i]
		var diff := now - target
		if diff < -Rhythm.FINALE_WINDOW:
			GameEvents.finale_hit.emit(i, false, finale_hits)
			return {"hit": true, "blocked": true, "damage": 0.0,
				"count_rhythm": false, "fx_pos": core_pos, "color": ResonantUI.MUTED}
		if absf(diff) <= Rhythm.FINALE_WINDOW:
			var expected: String = GameConfig.FINALE_SEQUENCE[i].action
			if action == expected:
				finale_prompt_results[i] = 1
				GameState.finale_results[i] = 1
				finale_hits += 1
				GameState.finale_hits = maxi(GameState.finale_hits, finale_hits)
				AudioBank.play("finale_hit", 0.95 + finale_hits * 0.04, 0.0)
				GameEvents.shake.emit(9.0)
				GameEvents.flash.emit(Color(1.0, 0.9, 0.6, 0.18), 0.22)
				if fx:
					fx.spawn_hit(core_pos, info.get("direction", 1),
						ResonantUI.GOLD, 1.6, Rhythm.Grade.PERFECT)
					fx.spawn_shockwave(core_pos, ResonantUI.GOLD, 160.0)
					fx.spawn_glyph(core_pos + Vector2(0, -20),
						"第 %d 击" % finale_hits, ResonantUI.GOLD, 22)
			else:
				finale_prompt_results[i] = 2
				GameState.finale_results[i] = 2
				GameEvents.toast.emit("音色错误 · 需要 " +
					GameConfig.FINALE_SEQUENCE[i].label, ResonantUI.CORAL)
			finale_index = maxi(finale_index, i + 1)
			GameEvents.finale_hit.emit(i, action == expected, finale_hits)
			_announce_next_prompt()
			return {"hit": true, "blocked": action != expected, "damage": 0.0,
				"count_rhythm": action == expected,
				"fx_pos": core_pos, "color": ResonantUI.GOLD if action == expected
					else ResonantUI.CORAL}
		if diff > Rhythm.FINALE_WINDOW:
			continue
		# hit is inside the gap before the next prompt: a real strike, no credit
		return {"hit": true, "blocked": true, "damage": 0.0,
			"count_rhythm": false, "fx_pos": core_pos,
			"color": ResonantUI.MUTED}
	return {"hit": true, "blocked": true, "damage": 0.0,
		"count_rhythm": false, "fx_pos": core_pos, "color": ResonantUI.MUTED}


func _announce_next_prompt() -> void:
	for i in GameConfig.FINALE_SEQUENCE.size():
		if finale_prompt_results[i] == 0:
			GameEvents.finale_prompt.emit(i, GameConfig.FINALE_SEQUENCE[i].action,
				GameConfig.FINALE_SEQUENCE[i].key)
			return


func _end_finale() -> void:
	if finale_done:
		return
	finale_done = true
	finale_success = finale_hits >= GameConfig.FINALE_SEQUENCE.size()
	GameState.finale_hits = finale_hits
	GameState.finale_success = finale_success
	_finale_finish_at = Conductor.get_timeline() + 0.9
	if finale_success:
		GameState.finale_success = true
		GameState.coda_restored = true
		Conductor.enable_coda()
		AudioBank.play("finale_success", 1.0, 0.0)
		GameEvents.flash.emit(Color(1.0, 0.9, 0.65, 0.3), 0.55)
		GameEvents.shake.emit(14.0)
		if fx:
			fx.spawn_unlock(global_position + Vector2(0, -130), ResonantUI.GOLD)
			fx.spawn_beam(global_position + Vector2(-500, -130),
				global_position + Vector2(500, -130), ResonantUI.GOLD)
			for i in 24:
				fx.spawn_note_trail(global_position + Vector2(
					randf_range(-220, 220), randf_range(-260, -60)),
					ResonantUI.GOLD)
	else:
		GameState.finale_success = false
		AudioBank.play("finale_fail", 0.9, -2.0)
		GameEvents.flash.emit(Color(0.7, 0.2, 0.2, 0.14), 0.4)
	GameEvents.finale_finished.emit(finale_success, finale_hits)


func _finish_finale() -> void:
	if dead:
		return
	dead = true
	state = "Death"
	state_time = 0.0
	GameEvents.boss_defeated.emit()
	GameState.boss_defeated = true
	GameEvents.shake.emit(16.0)
	if fx:
		fx.spawn_death(global_position + Vector2(0, -120),
			ResonantUI.GOLD, "guard")
		for i in 12:
			fx.spawn_note_trail(global_position + Vector2(
				randf_range(-200, 200), randf_range(-260, -40)),
				ResonantUI.GOLD)
	if world and world.has_method("on_boss_defeated"):
		world.on_boss_defeated(finale_success, finale_hits)


func force_finale() -> void:
	begin_finale()


# --------------------------------------------------------------------------- #
# drawing
# --------------------------------------------------------------------------- #
func _draw() -> void:
	var alpha := 1.0
	if dead:
		alpha = maxf(0.0, 1.0 - _death_time * 0.8)
	modulate = Color(1, 1, 1, alpha)
	var phase_color := ResonantUI.GOLD
	if phase == 2:
		phase_color = ResonantUI.CORAL
	elif phase == 3:
		phase_color = Color("ff5f6d")
	var bob := sin(state_time * 2.0 + 0.7) * 5.0
	var center := Vector2(0, -130 + bob)

	# aura / beat rings
	var beat_phase := Conductor.get_beat_phase()
	for i in 3:
		var r := 108.0 + i * 34.0
		draw_arc(center, r, -2.7, 0.6, 48,
			Color(phase_color, 0.08 - i * 0.018), 1.2, true)
	draw_arc(center, 98.0 + (1.0 - absf(beat_phase - 0.5) * 2.0) * 8.0,
		0, TAU, 54, Color(phase_color, 0.14), 1.0, true)

	# spectral score ribbons behind the body
	for k in 3:
		var pts := PackedVector2Array()
		for i in 18:
			var t := float(i) / 17.0
			var x := lerpf(-150.0, 150.0, t)
			var y := -190.0 + k * 48.0 + sin(t * 8.0 + state_time * 1.3 + k) * 14.0
			pts.append(Vector2(x, y + bob))
		draw_polyline(pts, Color(phase_color, 0.07 - k * 0.015), 1.0, true)

	# phantom lower robes
	var back_tail_l := PackedVector2Array([
		Vector2(-62, -176 + bob), Vector2(-102, -82 + bob),
		Vector2(-124, 34 + bob), Vector2(-36, -14 + bob),
	])
	var back_tail_r := PackedVector2Array([
		Vector2(62, -176 + bob), Vector2(102, -82 + bob),
		Vector2(124, 34 + bob), Vector2(36, -14 + bob),
	])
	draw_colored_polygon(back_tail_l, Color(0.012, 0.014, 0.02, 0.96))
	draw_colored_polygon(back_tail_r, Color(0.012, 0.014, 0.02, 0.96))
	draw_polyline(back_tail_l + PackedVector2Array([back_tail_l[0]]),
		Color(phase_color, 0.22), 1.0, true)
	draw_polyline(back_tail_r + PackedVector2Array([back_tail_r[0]]),
		Color(phase_color, 0.22), 1.0, true)

	# main tailcoat body
	var coat_pts := PackedVector2Array([
		Vector2(-56, -188 + bob), Vector2(-68, -92 + bob),
		Vector2(-48, 26 + bob), Vector2(0, 8 + bob),
		Vector2(48, 26 + bob), Vector2(68, -92 + bob),
		Vector2(56, -188 + bob),
	])
	draw_colored_polygon(coat_pts, Color(0.018, 0.022, 0.028, 0.99))
	draw_polyline(coat_pts + PackedVector2Array([coat_pts[0]]),
		Color(phase_color, 0.30), 1.5, true)
	# lining and split tails
	draw_colored_polygon(PackedVector2Array([
		Vector2(-44, -90 + bob), Vector2(0, -44 + bob),
		Vector2(-36, 20 + bob), Vector2(-54, -76 + bob),
	]), Color(phase_color, 0.10))
	draw_colored_polygon(PackedVector2Array([
		Vector2(44, -90 + bob), Vector2(0, -44 + bob),
		Vector2(36, 20 + bob), Vector2(54, -76 + bob),
	]), Color(phase_color, 0.08))
	draw_line(Vector2(0, -44 + bob), Vector2(0, 10 + bob),
		Color(phase_color, 0.5), 1.5, true)
	for i in 4:
		var yy := -78.0 + i * 22.0 + bob
		draw_line(Vector2(-40, yy), Vector2(-10 + i * 6, yy + 5),
			Color(phase_color, 0.14), 1.0, true)
		draw_line(Vector2(40, yy), Vector2(10 - i * 6, yy + 5),
			Color(phase_color, 0.11), 1.0, true)

	# ivory waistcoat and belt
	draw_colored_polygon(PackedVector2Array([
		Vector2(-27, -186 + bob), Vector2(0, -128 + bob),
		Vector2(27, -186 + bob), Vector2(21, -102 + bob),
		Vector2(0, -78 + bob), Vector2(-21, -102 + bob),
	]), Color(0.82, 0.78, 0.67, 0.92))
	draw_line(Vector2(0, -186 + bob), Vector2(0, -80 + bob),
		Color(0.18, 0.15, 0.12, 0.8), 1.0, true)
	draw_rect(Rect2(-44, -86 + bob, 88, 12), Color(0.025, 0.025, 0.03, 0.98))
	draw_line(Vector2(-44, -84 + bob), Vector2(44, -84 + bob),
		Color(phase_color, 0.6), 1.0, true)
	draw_circle(Vector2(0, -80 + bob), 5.0, Color(phase_color, 0.8), true)

	# chest core
	var core := get_core_center() + Vector2(0, bob)
	var pulse := 1.0 + sin(state_time * 5.0) * 0.12
	if core_open or state == "Finale":
		for i in 4:
			draw_circle(core, (18 + i * 10) * pulse,
				Color(ResonantUI.GOLD, 0.06 + (3 - i) * 0.02), true)
		draw_circle(core, 16.0 * pulse, Color(1.0, 0.9, 0.6, 0.95), true)
		draw_circle(core, 9.0 * pulse, Color.WHITE, true)
	else:
		draw_circle(core, 9.0, Color(phase_color, 0.25), true)
		draw_arc(core, 13.0, 0, TAU, 24, Color(phase_color, 0.5), 1.2, true)

	# high collar behind the mask
	draw_colored_polygon(PackedVector2Array([
		Vector2(-52, -186 + bob), Vector2(-30, -232 + bob),
		Vector2(-10, -202 + bob), Vector2(-34, -172 + bob),
	]), Color(0.015, 0.018, 0.023, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(52, -186 + bob), Vector2(30, -232 + bob),
		Vector2(10, -202 + bob), Vector2(34, -172 + bob),
	]), Color(0.015, 0.018, 0.023, 1.0))
	draw_line(Vector2(-50, -186 + bob), Vector2(-30, -232 + bob),
		Color(phase_color, 0.5), 1.2, true)
	draw_line(Vector2(50, -186 + bob), Vector2(30, -232 + bob),
		Color(phase_color, 0.5), 1.2, true)

	# spectral extra arms (four-armed conductor motif)
	for side in [-1, 1]:
		var sh := Vector2(side * 62, -174 + bob)
		var el := sh + Vector2(side * 46, 22 + sin(state_time * 2.2 + side) * 9.0)
		var hd := el + Vector2(side * 34, 16 + cos(state_time * 2.0 + side) * 8.0)
		draw_line(sh, el, Color(phase_color, 0.10), 12.0, true)
		draw_line(el, hd, Color(phase_color, 0.10), 8.0, true)
		draw_line(hd, hd + Vector2(side * 68, -34), Color(phase_color, 0.16), 1.0, true)

	# arms with elbows
	var left_shoulder := Vector2(-52, -178 + bob)
	var right_shoulder := Vector2(52, -178 + bob)
	var baton_angle := -0.5
	var baton_length := 148.0
	match state:
		"Telegraph":
			baton_angle = -1.9 if _move != "sweep" else -1.2
		"Attack":
			baton_angle = 0.9 if _move == "slam" else 0.15
		"Core":
			baton_angle = -0.2
		"Finale":
			baton_angle = -0.4
	var hand_r := Vector2(84, -138 + bob)
	var elbow_r := Vector2(88, -168 + bob)
	if state == "Telegraph":
		hand_r = Vector2(82, -218 + bob)
		elbow_r = Vector2(94, -190 + bob)
		baton_length = 128.0
	var hand_l := Vector2(-88, -126 + bob)
	var elbow_l := Vector2(-86, -162 + bob)
	# sleeves
	draw_line(left_shoulder, elbow_l, Color(0.025, 0.03, 0.038), 17.0, true)
	draw_line(elbow_l, hand_l, Color(0.025, 0.03, 0.038), 13.0, true)
	draw_line(right_shoulder, elbow_r, Color(0.025, 0.03, 0.038), 17.0, true)
	draw_line(elbow_r, hand_r, Color(0.025, 0.03, 0.038), 13.0, true)
	draw_line(left_shoulder, elbow_l, Color(phase_color, 0.35), 2.0, true)
	draw_line(right_shoulder, elbow_r, Color(phase_color, 0.35), 2.0, true)
	# cuffs and hands
	draw_line(hand_l + Vector2(-8, -7), hand_l + Vector2(8, 7),
		Color(phase_color, 0.8), 2.0, true)
	draw_line(hand_r + Vector2(-8, -7), hand_r + Vector2(8, 7),
		Color(phase_color, 0.8), 2.0, true)
	draw_circle(hand_l, 6.5, Color(0.78, 0.72, 0.61), true)
	draw_circle(hand_r, 6.5, Color(0.78, 0.72, 0.61), true)
	# shoulder epaulettes
	for side in [-1, 1]:
		var p := Vector2(side * 54, -184 + bob)
		draw_colored_polygon(PackedVector2Array([
			p, p + Vector2(side * 24, -8), p + Vector2(side * 22, 12),
			p + Vector2(0, 16),
		]), Color(0.035, 0.035, 0.042))
		draw_line(p, p + Vector2(side * 24, -8), Color(phase_color, 0.75), 1.5, true)
		for i in 3:
			draw_line(p + Vector2(side * (6 + i * 5), 1 + i * 4),
				p + Vector2(side * (8 + i * 5), 10 + i * 3),
				Color(phase_color, 0.65), 1.0, true)

	# baton
	var baton_tip := hand_r + Vector2.from_angle(baton_angle) * baton_length
	draw_line(hand_r, baton_tip, Color(0.01, 0.01, 0.012), 6.0, true)
	draw_line(hand_r, baton_tip, Color(phase_color, 0.95), 2.6, true)
	draw_line(hand_r, baton_tip, Color(1.0, 0.95, 0.8, 0.9), 1.0, true)
	draw_circle(baton_tip, 5.5, Color(phase_color, 0.95), true)
	draw_circle(baton_tip, 13.0, Color(phase_color, 0.10), true)

	# head: a cracked porcelain mask
	var head := Vector2(0, -232 + bob)
	# crown / tuning fork
	for i in 7:
		var a := -1.75 + i * 0.25
		draw_line(head + Vector2(0, -20),
			head + Vector2.from_angle(a) * (42 + (i % 3) * 9) + Vector2(0, -12),
			Color(0.02, 0.02, 0.025), 2.5, true)
	for side in [-1, 1]:
		draw_line(head + Vector2(side * 15, -16),
			head + Vector2(side * 19, -60), Color(phase_color, 0.72), 2.0, true)
		draw_circle(head + Vector2(side * 19, -60), 3.0, Color(phase_color, 0.9), true)
	# mask
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-23, -18), head + Vector2(0, -33), head + Vector2(24, -17),
		head + Vector2(22, 18), head + Vector2(0, 36), head + Vector2(-22, 19),
	]), Color(0.92, 0.88, 0.78))
	draw_polyline(PackedVector2Array([
		head + Vector2(-23, -18), head + Vector2(0, -33), head + Vector2(24, -17),
		head + Vector2(22, 18), head + Vector2(0, 36), head + Vector2(-22, 19),
		head + Vector2(-23, -18),
	]), Color(0.05, 0.04, 0.04, 0.8), 1.5, true)
	# eye slits
	draw_line(head + Vector2(-17, -4), head + Vector2(-4, -6),
		Color(0.03, 0.02, 0.02), 3.0, true)
	draw_line(head + Vector2(5, -6), head + Vector2(18, -3),
		Color(0.03, 0.02, 0.02), 3.0, true)
	# gold crack and chin line
	var crack := PackedVector2Array([
		head + Vector2(1, -28), head + Vector2(-3, -14),
		head + Vector2(5, -4), head + Vector2(-1, 10), head + Vector2(2, 25),
	])
	draw_polyline(crack, Color(phase_color, 0.85), 1.2, true)
	draw_line(head + Vector2(-4, 24), head + Vector2(4, 24),
		Color(0.1, 0.08, 0.07), 1.0, true)

	# staff ring at feet
	draw_arc(Vector2(0, 3), 104.0, PI, TAU, 48,
		Color(phase_color, 0.18), 1.5, true)
	draw_arc(Vector2(0, 3), 76.0, PI, TAU, 42,
		Color(phase_color, 0.10), 1.0, true)
	for i in 7:
		var a := PI + i * PI / 6.0
		draw_circle(Vector2(cos(a) * 104.0, 3 + sin(a) * 104.0 * 0.35),
			2.0, Color(phase_color, 0.35), true)

	# telegraph tells
	if state == "Telegraph":
		_draw_tell(phase_color, bob)
	if state == "Core":
		_draw_core_tell()
	if state == "Finale":
		_draw_finale_tell()
	if _hit_flash > 0.2:
		draw_circle(center, 120.0, Color(1, 1, 1, _hit_flash * 0.08), true)


func _draw_tell(color: Color, bob: float) -> void:
	# ground target for slam, a wide arc for sweep, falling glyphs for arpeggio
	if _move == "slam" and player:
		var px := player.global_position.x - global_position.x
		var rings := 3
		for i in rings:
			var r := 70.0 + i * 55.0 + sin(state_time * 10.0 + i) * 6.0
			draw_arc(Vector2(px, 603), r, 0.0, PI, 32,
				Color(color, 0.08 + i * 0.03), 2.0, true)
		draw_line(Vector2(px - 250, 603), Vector2(px + 250, 603),
			Color(color, 0.28), 2.0, true)
	elif _move == "sweep":
		var dir := 1 if player and player.global_position.x >= global_position.x else -1
		draw_arc(Vector2(0, -112 + bob), 260.0, -1.4 if dir > 0 else PI - 1.4,
			-0.1 if dir > 0 else PI + 0.1, 40, Color(color, 0.28), 2.5, true)
		draw_line(Vector2(0, -112 + bob),
			Vector2(dir * 300, -112 + bob), Color(color, 0.18), 1.5, true)
	else:
		if player:
			for i in 5:
				var x := player.global_position.x - global_position.x + (i - 2) * 95.0
				draw_arc(Vector2(x, 603), 34.0, 0, PI, 18,
					Color(color, 0.18), 1.5, true)


func _draw_core_tell() -> void:
	var core := get_core_center()
	for i in 3:
		var r := 34.0 + i * 22.0 + sin(state_time * 6.0 + i) * 4.0
		draw_arc(core, r, 0, TAU, 34, Color(ResonantUI.GOLD, 0.20 - i * 0.05), 1.5, true)
	draw_string(ResonantUI.body_font(), core + Vector2(-68, -72), "CORE",
		HORIZONTAL_ALIGNMENT_CENTER, 136, 13, Color(ResonantUI.GOLD, 0.8))


func _draw_finale_tell() -> void:
	var core := get_core_center()
	for i in range(4):
		var angle := -PI * 0.5 + (i - 1.5) * 0.42
		var p := core + Vector2.from_angle(angle) * 115.0
		var col := ResonantUI.DIM
		if i < finale_index:
			col = ResonantUI.GOLD if finale_prompt_results[i] == 1 else ResonantUI.RED
		elif i == finale_index:
			col = ResonantUI.INK
		draw_line(core, p, Color(col, 0.22), 1.0, true)
		draw_circle(p, 14.0 if i == finale_index else 9.0, Color(col, 0.2), true)
		draw_arc(p, 14.0 if i == finale_index else 9.0, 0, TAU, 20,
			Color(col, 0.8), 1.5, true)
