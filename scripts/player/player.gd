extends CharacterBody2D
## The Resonant Blade.  Actor origin is at the feet.
##
## Attack lifecycle is explicit: startup -> active -> recovery.  Hit detection
## is polled every physics tick during the active window, and the rhythm grade
## is taken at the exact moment a hurtbox is touched.

const ATTACK_IDS := ["light", "heavy", "thrust", "launcher"]

var facing := 1
var hp := GameConfig.PLAYER_MAX_HP
var max_hp := GameConfig.PLAYER_MAX_HP
var state := "Idle"
var state_time := 0.0
var invuln := 0.0
var dodge_cd := 0.0
var dodge_actions := 0
var air_dodges := GameConfig.PLAYER_AIR_DODGES
var hitstop := 0.0
var input_enabled := true
var dead := false

var attack_id := ""
var attack_elapsed := 0.0
var attack_hit_targets: Array[int] = []
var attack_did_hit := false
var attack_lunged := false
var combo_index := 0
var combo_window := 0.0

var buffered_attack := ""
var buffer_timer := 0.0
var jump_buffer := 0.0
var coyote := 0.0
var was_on_floor := false
var run_clock := 0.0
var _dodge_credit_cd := 0.0
var _hurt_flash := 0.0
var _afterimages: Array[Dictionary] = []
var _dodge_dir := 1
var _attack_queued_grade := 0

var fx: Node
var world: Node


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 8.0
	floor_stop_on_slope = true
	safe_margin = 0.08
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 16.0
	cap.height = 72.0
	shape.shape = cap
	shape.position = Vector2(0, -36)
	add_child(shape)
	GameEvents.player_health_changed.emit(hp, max_hp)


func setup(fx_node: Node, world_node: Node) -> void:
	fx = fx_node
	world = world_node


func _physics_process(delta: float) -> void:
	if dead:
		state_time += delta
		queue_redraw()
		return
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		velocity = Vector2.ZERO
		queue_redraw()
		return

	invuln = maxf(0.0, invuln - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	_dodge_credit_cd = maxf(0.0, _dodge_credit_cd - delta)
	_hurt_flash = maxf(0.0, _hurt_flash - delta * 4.0)
	buffer_timer = maxf(0.0, buffer_timer - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	combo_window = maxf(0.0, combo_window - delta)
	state_time += delta
	run_clock += delta

	if state == "Hit" and state_time > 0.24:
		state = "Idle"
	if state == "Dodge":
		_update_dodge(delta)
		queue_redraw()
		return
	if state in ["LightAttack", "HeavyAttack", "Thrust", "Launcher"]:
		_update_attack(delta)
		queue_redraw()
		return

	_read_actions()
	if state == "Dodge":
		queue_redraw()
		return
	if state == "Death":
		queue_redraw()
		return
	_update_locomotion(delta)
	queue_redraw()


func _read_actions() -> void:
	if not input_enabled:
		return
	if Input.is_action_just_pressed("attack_light"):
		_buffer_attack("light")
	elif Input.is_action_just_pressed("attack_heavy"):
		_buffer_attack("heavy")
	elif Input.is_action_just_pressed("attack_thrust"):
		_buffer_attack("thrust")
	elif Input.is_action_just_pressed("attack_launcher"):
		_buffer_attack("launcher")
	if Input.is_action_just_pressed("jump"):
		jump_buffer = GameConfig.JUMP_BUFFER
	if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0 and _can_dodge():
		_start_dodge()


func _buffer_attack(id: String) -> void:
	buffered_attack = id
	buffer_timer = 0.16


func _can_act() -> bool:
	return state in ["Idle", "Run", "Jump", "Fall"] and state != "Hit"


func _update_locomotion(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		coyote = GameConfig.COYOTE_TIME
		air_dodges = GameConfig.PLAYER_AIR_DODGES
	else:
		coyote = maxf(0.0, coyote - delta)

	var axis := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
	if absf(axis) > 0.08:
		facing = 1 if axis > 0.0 else -1
		velocity.x = move_toward(velocity.x, axis * GameConfig.RUN_SPEED,
			(GameConfig.GROUND_ACCEL if on_floor else GameConfig.AIR_ACCEL) * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0,
			(GameConfig.GROUND_FRICTION if on_floor else GameConfig.AIR_ACCEL * 0.45) * delta)

	if jump_buffer > 0.0 and coyote > 0.0:
		velocity.y = GameConfig.JUMP_VELOCITY
		jump_buffer = 0.0
		coyote = 0.0
		state = "Jump"
		if fx:
			fx.spawn_dust(global_position, Color(0.55, 0.95, 0.85, 0.35))
		AudioBank.play("dodge", 1.45, -20.0)
	if Input.is_action_just_released("jump") and velocity.y < -300.0:
		velocity.y *= 0.56

	if buffered_attack != "" and buffer_timer > 0.0 and _can_act():
		_start_attack(buffered_attack)
		return

	if not on_floor:
		velocity.y = minf(velocity.y + GameConfig.GRAVITY * delta, GameConfig.MAX_FALL)
		if velocity.y < -40.0:
			state = "Jump"
		elif velocity.y > 60.0:
			state = "Fall"
	else:
		if velocity.y > 0.0:
			velocity.y = 0.0
		if absf(velocity.x) > 24.0:
			state = "Run"
		else:
			state = "Idle"
		if not was_on_floor:
			_land()
	was_on_floor = on_floor
	move_and_slide()
	if is_on_floor() and velocity.y > 0.0:
		velocity.y = 0.0


func _land() -> void:
	state = "Idle"
	if fx:
		fx.spawn_dust(global_position, Color(0.55, 0.95, 0.85, 0.32))
	AudioBank.play("ui_move", 0.72, -26.0)


func _start_dodge() -> void:
	var axis := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
	_dodge_dir = facing
	if absf(axis) > 0.2:
		_dodge_dir = 1 if axis > 0.0 else -1
		facing = _dodge_dir
	state = "Dodge"
	state_time = 0.0
	dodge_actions += 1
	invuln = maxf(invuln, GameConfig.DODGE_IFRAMES)
	dodge_cd = GameConfig.DODGE_COOLDOWN
	if not is_on_floor():
		air_dodges -= 1
		velocity.y = minf(velocity.y, 20.0)
	velocity.x = _dodge_dir * GameConfig.DODGE_SPEED
	AudioBank.play_varied("dodge", -3.0, 0.04)
	if fx:
		fx.spawn_dust(global_position, Color(0.45, 0.95, 0.9, 0.4))
	GameEvents.shake.emit(0.8)


func _can_dodge() -> bool:
	if is_on_floor():
		return true
	return air_dodges > 0


func _update_dodge(delta: float) -> void:
	velocity.x = move_toward(velocity.x, _dodge_dir * GameConfig.DODGE_SPEED, 900.0 * delta)
	if not is_on_floor():
		velocity.y = minf(velocity.y + GameConfig.GRAVITY * 0.25 * delta, 220.0)
	if state_time >= GameConfig.DODGE_TIME:
		state = "Fall" if not is_on_floor() else "Idle"
		velocity.x *= 0.5
		state_time = 0.0
	move_and_slide()
	var ghost := {
		"pos": global_position,
		"facing": facing,
		"life": 0.18,
		"max_life": 0.18,
	}
	_afterimages.append(ghost)


func _start_attack(id: String) -> void:
	var data := GameConfig.attack(id)
	attack_id = id
	attack_elapsed = 0.0
	attack_hit_targets.clear()
	attack_did_hit = false
	attack_lunged = false
	buffered_attack = ""
	buffer_timer = 0.0
	state_time = 0.0
	match id:
		"light":
			state = "LightAttack"
			if combo_window > 0.0:
				combo_index = (combo_index + 1) % 3
			else:
				combo_index = 0
			combo_window = 0.55
		"heavy":
			state = "HeavyAttack"
			combo_index = 0
		"thrust":
			state = "Thrust"
			combo_index = 0
		"launcher":
			state = "Launcher"
			combo_index = 0
	AudioBank.play_varied(data.swing_sfx, -5.0, 0.025)
	if fx:
		var color: Color = data.color
		fx.spawn_dust(global_position + Vector2(facing * 20, 0),
			Color(color, 0.35))


func _update_attack(delta: float) -> void:
	var data := GameConfig.attack(attack_id)
	attack_elapsed += delta
	state_time = attack_elapsed
	if input_enabled:
		if Input.is_action_just_pressed("attack_light"):
			buffered_attack = "light"
			buffer_timer = 0.16
		elif Input.is_action_just_pressed("attack_heavy"):
			buffered_attack = "heavy"
			buffer_timer = 0.16
		elif Input.is_action_just_pressed("attack_thrust"):
			buffered_attack = "thrust"
			buffer_timer = 0.16
		elif Input.is_action_just_pressed("attack_launcher"):
			buffered_attack = "launcher"
			buffer_timer = 0.16
	var startup: float = data.startup
	var active_end: float = startup + data.active
	var total: float = active_end + data.recovery

	# steering is locked: only the designed lunge moves the character
	if not attack_lunged and attack_elapsed >= startup:
		attack_lunged = true
		var lunge: float = data.lunge
		if lunge > 0.0:
			velocity.x = facing * lunge
		if fx:
			fx.spawn_slash(global_position + Vector2(facing * 22, -48), facing,
				data.color, data.reach * 0.62, attack_id == "heavy")
	if attack_elapsed >= startup and attack_elapsed <= active_end:
		_scan_hits(data)

	# light attacks chain from late active / recovery
	if attack_id == "light" and buffered_attack == "light" \
			and attack_elapsed >= startup + data.active * 0.55:
		_start_attack("light")
		return
	# dodge may cancel the tail of recovery, never the committed swing
	if input_enabled and Input.is_action_just_pressed("dodge") \
			and dodge_cd <= 0.0 and attack_elapsed >= active_end + data.recovery * 0.18:
		_start_dodge()
		return

	if attack_elapsed >= total:
		if attack_id == "light":
			combo_window = 0.6
		else:
			combo_window = 0.0
		if not attack_did_hit:
			GameState.register_whiff(attack_id)
		state = "Idle" if is_on_floor() else "Fall"
		state_time = 0.0
		attack_id = ""
		velocity.x *= 0.35
	if not is_on_floor():
		velocity.y = minf(velocity.y + GameConfig.GRAVITY * 0.75 * delta, GameConfig.MAX_FALL)
	move_and_slide()


func _scan_hits(data: Dictionary) -> void:
	var rect := _attack_rect(data)
	var targets := get_tree().get_nodes_in_group("hurtable")
	for target: Node in targets:
		if target == self or target.is_queued_for_deletion():
			continue
		if not target.has_method("receive_attack"):
			continue
		var id := target.get_instance_id()
		if attack_hit_targets.has(id):
			continue
		if target.has_method("get_hurtbox"):
			var box: Rect2 = target.get_hurtbox()
			if not rect.intersects(box):
				continue
		elif target is Node2D:
			if not rect.has_point((target as Node2D).global_position - Vector2(0, 30)):
				continue
		attack_hit_targets.append(id)
		var info := {
			"damage": _damage_for(data),
			"attack_id": attack_id,
			"direction": facing,
			"poise": data.poise,
			"knockback": data.knockback,
			"lift": data.lift,
			"hitstop": data.hitstop,
			"combo_index": combo_index,
			"source": self,
		}
		var result: Dictionary = target.call("receive_attack", info)
		if not bool(result.get("hit", false)):
			continue
		attack_did_hit = true
		var blocked := bool(result.get("blocked", false))
		var rhythm_ok := bool(result.get("count_rhythm", true))
		var fx_pos: Vector2 = result.get("fx_pos", (target as Node2D).global_position - Vector2(0, 34))
		var color: Color = result.get("color", data.color)
		if rhythm_ok:
			var judged := Conductor.judge()
			var grade: int = judged.grade
			var delta_ms: float = judged.delta_ms
			GameState.register_hit(attack_id, grade, delta_ms)
			if fx:
				fx.spawn_judgement_text(fx_pos + Vector2(0, -36),
					Rhythm.grade_name(grade), Rhythm.grade_color(grade), 20)
			if grade <= Rhythm.Grade.GOOD:
				AudioBank.play("perfect" if grade == Rhythm.Grade.PERFECT else "great",
					1.0 + combo_index * 0.02, -8.0)
		if blocked:
			AudioBank.play_varied("hit_armor", -1.0, 0.03)
			if fx:
				fx.spawn_hit(fx_pos, facing, Color("d9e2ff"), 0.65)
			hitstop = maxf(hitstop, 0.025)
			GameEvents.shake.emit(1.2)
		else:
			var power: float = 0.7 + float(data.damage) / 38.0
			AudioBank.play_varied(data.hit_sfx, 0.0, 0.035)
			if fx:
				fx.spawn_hit(fx_pos, facing, color, power,
					Rhythm.Grade.PERFECT if rhythm_ok and Conductor.is_on_beat(0.05) else Rhythm.Grade.GREAT)
				var dmg: float = result.get("damage", 0.0)
				if dmg > 0.0:
					fx.spawn_damage(fx_pos + Vector2(0, -24), dmg, color,
						result.get("crit", false))
			hitstop = maxf(hitstop, data.hitstop)
			GameEvents.shake.emit(data.shake)
			if result.get("crit", false) and fx:
				fx.spawn_shockwave(fx_pos, color, 90.0)
		if bool(result.get("killed", false)):
			GameEvents.shake.emit(maxf(3.0, float(data.shake)))


func _damage_for(data: Dictionary) -> float:
	var damage: float = data.damage
	if attack_id == "light":
		var chain: Array = data.combo_damage
		damage = float(chain[clampi(combo_index, 0, chain.size() - 1)])
	return damage


func _attack_rect(data: Dictionary) -> Rect2:
	var center := global_position + Vector2(facing * float(data.offset), -44.0)
	return Rect2(center.x - float(data.reach) * 0.5,
		center.y - float(data.half_height),
		float(data.reach), float(data.half_height) * 2.0)


func receive_hit(damage: float, source_pos: Vector2, knockback: float = 280.0) -> bool:
	if dead:
		return true
	if invuln > 0.0:
		if _dodge_credit_cd <= 0.0:
			_dodge_credit_cd = 0.18
			GameState.register_dodge()
			AudioBank.play("resonance", 1.15, -8.0)
			GameEvents.flash.emit(Color(0.4, 1.0, 0.9, 0.08), 0.12)
			if fx:
				fx.spawn_judgement_text(global_position + Vector2(0, -100),
					"DODGE", ResonantUI.TEAL, 22)
		return true
	hp = maxf(0.0, hp - damage)
	GameState.register_hurt(damage)
	invuln = GameConfig.PLAYER_HIT_IFRAMES
	_hurt_flash = 1.0
	state = "Hit"
	state_time = 0.0
	var dir := signf(global_position.x - source_pos.x)
	if absf(dir) < 0.1:
		dir = -facing
	velocity = Vector2(dir * knockback, -220.0)
	hitstop = maxf(hitstop, 0.06)
	AudioBank.play("hurt", 1.0, -2.0)
	GameEvents.shake.emit(5.0)
	GameEvents.flash.emit(Color(1.0, 0.2, 0.22, 0.12), 0.18)
	if fx:
		fx.spawn_hit(global_position + Vector2(0, -44), int(dir),
			ResonantUI.CORAL, 1.2)
		fx.spawn_damage(global_position + Vector2(0, -76), damage, ResonantUI.RED)
	GameEvents.player_health_changed.emit(hp, max_hp)
	if hp <= 0.0:
		_die()
	return true


func heal(amount: float) -> void:
	if dead:
		return
	hp = minf(max_hp, hp + amount)
	GameEvents.player_health_changed.emit(hp, max_hp)
	if fx:
		fx.spawn_heal(global_position + Vector2(0, -40))


func _die() -> void:
	dead = true
	state = "Death"
	state_time = 0.0
	velocity = Vector2.ZERO
	collision_layer = 0
	AudioBank.play("death_guard", 0.9, -3.0)
	GameEvents.shake.emit(10.0)
	GameEvents.flash.emit(Color(0.7, 0.05, 0.1, 0.22), 0.45)
	if fx:
		fx.spawn_death(global_position + Vector2(0, -40), ResonantUI.CORAL, "player")
	GameEvents.player_died.emit()


func force_death() -> void:
	if dead:
		return
	hp = 0.0
	GameEvents.player_health_changed.emit(hp, max_hp)
	_die()


func respawn(at: Vector2) -> void:
	dead = false
	hp = max_hp
	global_position = at
	velocity = Vector2.ZERO
	state = "Idle"
	state_time = 0.0
	invuln = 1.8
	dodge_cd = 0.0
	collision_layer = 2
	visible = true
	GameEvents.player_health_changed.emit(hp, max_hp)
	GameEvents.player_respawned.emit()
	if fx:
		fx.spawn_heal(global_position + Vector2(0, -40))


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		velocity.x = move_toward(velocity.x, 0.0, 600.0)
		buffered_attack = ""


func get_hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-15, -76), Vector2(30, 74))


func get_center() -> Vector2:
	return global_position + Vector2(0, -40)


func is_invulnerable() -> bool:
	return invuln > 0.0 or dead


func _process(delta: float) -> void:
	if not dead:
		for i in range(_afterimages.size() - 1, -1, -1):
			_afterimages[i].life -= delta
			if _afterimages[i].life <= 0.0:
				_afterimages.remove_at(i)
	queue_redraw()


func _draw() -> void:
	if dead and state_time > 0.45:
		return
	var alpha := 1.0
	if invuln > 0.0 and not dead:
		alpha = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.024))
	if _hurt_flash > 0.0:
		alpha = minf(1.0, alpha + 0.2)
	modulate = Color(1, 1, 1, alpha)

	# shadow and beat ring
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2(0, 10), 21.0, Color(0, 0, 0, 0.38), true)
	draw_set_transform(Vector2.ZERO)
	var phase := Conductor.get_beat_phase() if Conductor.playing else 0.0
	var ring_alpha := (1.0 - absf(phase - 0.15) * 2.2)
	if ring_alpha > 0.0:
		draw_arc(Vector2(0, 1), 26.0 + phase * 14.0, 0, TAU, 36,
			Color(ResonantUI.TEAL, ring_alpha * 0.24), 1.2, true)

	# dodge ghosts
	for ghost: Dictionary in _afterimages:
		var a: float = ghost.life / ghost.max_life
		draw_set_transform(Vector2(ghost.pos.x - global_position.x,
			ghost.pos.y - global_position.y), 0, Vector2(ghost.facing, 1))
		_draw_figure(Color(0.35, 0.95, 0.9, 0.11 * a), 0.0, false)
	draw_set_transform(Vector2.ZERO)

	var body_alpha := 1.0
	if dead:
		body_alpha = maxf(0.0, 1.0 - state_time * 1.8)
		draw_set_transform(Vector2(0, -10 * state_time), -0.9 * state_time,
			Vector2(facing * (1.0 - state_time * 0.3), 1.0 - state_time * 0.3))
	else:
		draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	_draw_figure(Color(1, 1, 1, body_alpha), _sword_angle(), true)
	draw_set_transform(Vector2.ZERO)


func _draw_figure(tint: Color, sword_angle: float, full: bool) -> void:
	var speed := absf(velocity.x)
	var bob := 0.0
	if state == "Run":
		bob = absf(sin(run_clock * 11.0)) * 3.0
	elif state == "Idle":
		bob = sin(Time.get_ticks_msec() * 0.003) * 1.2
	var crouch := 0.0
	if state == "HeavyAttack":
		var d := GameConfig.attack("heavy")
		crouch = 5.0 if attack_elapsed < d.startup else 8.0
	elif state == "Dodge":
		crouch = 10.0
	var hip := Vector2(0, -34 + crouch + bob)
	var shoulder := Vector2(5, -59 + crouch + bob)
	var head := Vector2(7, -72 + crouch + bob)
	var coat := Color(0.055, 0.10, 0.14) * tint
	var coat2 := Color(0.10, 0.17, 0.21) * tint
	var trim := Color(0.67, 0.98, 0.90) * tint
	var skin := Color(0.92, 0.88, 0.77) * tint
	var scarf := Color(0.30, 0.93, 0.82) * tint

	# trailing coat
	var flow := sin(run_clock * 7.0 + 1.0) * 5.0
	var coat_pts := PackedVector2Array([
		shoulder + Vector2(-7, 2), hip + Vector2(-10, 4),
		hip + Vector2(-27 - speed * 0.012, 18 + flow), hip + Vector2(-9, 27),
		hip + Vector2(13, 20), hip + Vector2(10, 1),
	])
	draw_colored_polygon(coat_pts, Color(coat, 0.94))
	draw_polyline(coat_pts + PackedVector2Array([coat_pts[0]]),
		Color(trim, 0.26), 1.0, true)

	# legs
	var leg_phase := sin(run_clock * 12.0) * (10.0 if state == "Run" else 2.0)
	var leg_a := hip + Vector2(-5 + leg_phase * 0.6, 25)
	var leg_b := hip + Vector2(7 - leg_phase * 0.6, 25)
	draw_line(hip + Vector2(-5, 0), leg_a, Color(coat2, 1.0), 6.0, true)
	draw_line(hip + Vector2(6, 0), leg_b, Color(coat2, 1.0), 6.0, true)
	draw_line(leg_a, leg_a + Vector2(1, 7), Color(trim, 0.7), 2.0, true)
	draw_line(leg_b, leg_b + Vector2(1, 7), Color(trim, 0.7), 2.0, true)

	# torso
	var torso := PackedVector2Array([
		shoulder + Vector2(-9, 0), shoulder + Vector2(10, 1),
		hip + Vector2(9, 2), hip + Vector2(-8, 1),
	])
	draw_colored_polygon(torso, Color(coat2, 0.98))
	draw_line(shoulder + Vector2(0, 0), hip + Vector2(0, 2),
		Color(trim, 0.55), 1.2, true)
	draw_line(shoulder + Vector2(-5, 8), hip + Vector2(4, 10),
		Color(trim, 0.2), 1.0, true)

	# scarf: two ribbons, always opposite the run direction
	for k in 2:
		var pts := PackedVector2Array([shoulder + Vector2(2, 0)])
		for i in 4:
			pts.append(shoulder + Vector2(-10 - i * 11 - speed * 0.008,
				i * 3 + sin(run_clock * 7.0 + i * 0.9 + k) * (3 + i * 1.5)))
		draw_polyline(pts, Color(scarf, 0.72 - k * 0.22), 3.0 - k, true)

	# head, hair and mask
	draw_circle(head, 10.5, Color(0.025, 0.045, 0.06) * tint, true)
	draw_circle(head + Vector2(1, 0), 8.4, skin, true)
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-9, -3), head + Vector2(4, -10), head + Vector2(10, -4),
		head + Vector2(8, 1), head + Vector2(1, -3),
	]), Color(0.03, 0.055, 0.07, 1.0))
	# narrow resonance visor
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-7, 0), head + Vector2(9, -2),
		head + Vector2(9, 2), head + Vector2(-6, 4),
	]), Color(0.015, 0.035, 0.045, 0.94))
	draw_line(head + Vector2(2, 0), head + Vector2(8, -1), Color(trim, 0.9), 1.2, true)
	# one glowing eye
	draw_circle(head + Vector2(5, -0.5), 1.4, Color(ResonantUI.GOLD, 0.95), true)
	draw_circle(head + Vector2(5, -0.5), 3.4, Color(ResonantUI.GOLD, 0.12), true)

	if not full:
		return

	# arm + sword
	var pivot := shoulder + Vector2(8, 7)
	var dir := Vector2.from_angle(sword_angle)
	var hand := pivot + dir * 21.0
	draw_line(pivot, hand, Color(skin, 0.92), 4.0, true)
	draw_line(pivot, hand, Color(trim, 0.35), 1.2, true)
	var guard := hand
	var tip := hand + dir * 64.0
	var blade_col := Color(0.98, 0.87, 0.55)
	# glow layers
	for i in 3:
		draw_line(guard, tip, Color(ResonantUI.GOLD, 0.09 - i * 0.02),
			7.0 + i * 4.0, true)
	draw_line(guard, tip, blade_col, 3.0, true)
	draw_line(guard, tip, Color(1, 1, 1, 0.9), 1.0, true)
	draw_line(hand - Vector2(-dir.y, dir.x) * 7.0,
		hand + Vector2(-dir.y, dir.x) * 7.0, Color(ResonantUI.GOLD, 0.9), 2.0, true)

	# active swing arc
	if state in ["LightAttack", "HeavyAttack", "Thrust", "Launcher"]:
		var data := GameConfig.attack(attack_id)
		if attack_elapsed >= data.startup and attack_elapsed <= data.startup + data.active:
			var a0 := sword_angle - 0.85
			var a1 := sword_angle + 0.45
			draw_arc(pivot, 68.0, a0, a1, 22,
				Color(data.color, 0.10), 12.0, true)
			draw_arc(pivot, 68.0, a0, a1, 22,
				Color(data.color, 0.24), 7.0, true)
			draw_arc(pivot, 68.0, a0, a1, 22,
				Color(data.color, 0.75), 2.0, true)


func _sword_angle() -> float:
	var base := 1.72
	if state == "Run":
		return base + sin(run_clock * 12.0) * 0.08
	if state == "Jump":
		return 1.35
	if state == "Fall":
		return 1.5
	if state == "Dodge":
		return 0.2
	if state == "Hit":
		return 1.1
	if state == "Death":
		return 0.6
	if state not in ["LightAttack", "HeavyAttack", "Thrust", "Launcher"]:
		return base
	var data := GameConfig.attack(attack_id)
	var t := attack_elapsed
	var startup: float = data.startup
	var active: float = data.active
	var recovery: float = data.recovery
	if t < startup:
		var k := ease(clampf(t / maxf(startup, 0.001), 0, 1), 0.6)
		match attack_id:
			"light":
				return lerp_angle(1.72, -1.35 if combo_index % 2 == 0 else 2.5, k)
			"heavy":
				return lerp_angle(1.72, -2.35, k)
			"thrust":
				return lerp_angle(1.72, -0.12, k)
			"launcher":
				return lerp_angle(1.72, 1.0, k)
	if t < startup + active:
		var k := clampf((t - startup) / maxf(active, 0.001), 0, 1)
		k = ease(k, 0.4)
		match attack_id:
			"light":
				return lerp_angle(-1.35 if combo_index % 2 == 0 else 2.5,
					0.25 if combo_index % 2 == 0 else -0.55, k)
			"heavy":
				return lerp_angle(-2.35, 0.95, k)
			"thrust":
				return lerp_angle(-0.12, 0.04, k)
			"launcher":
				return lerp_angle(1.0, -1.55, k)
	var k := clampf((t - startup - active) / maxf(recovery, 0.001), 0, 1)
	var end_angle := 0.4
	match attack_id:
		"light":
			end_angle = 1.3
		"heavy":
			end_angle = 1.9
		"thrust":
			end_angle = 0.3
		"launcher":
			end_angle = 1.55
	return lerp_angle(end_angle, 1.72, k)
