extends CharacterBody2D
## Config-driven note creature.  Four silhouettes, four lessons:
##   note      — basic spacing and combo practice
##   guard     — front armour, punished by a heavy on the beat
##   sprite    — air control and projectiles
##   dissonant — off-grid timing; read the animation, not the music

var kind := "note"
var config: Dictionary = {}
var encounter_id := -1
var player: Node2D
var fx: Node
var world: Node
var facing := -1
var hp := 30.0
var max_hp := 30.0
var poise := 14.0
var max_poise := 14.0
var state := "Idle"
var state_time := 0.0
var cooldown := 0.6
var activated := false
var dead := false
var hitstop := 0.0
var flash := 0.0
var stagger_left := 0.0
var armor_broken := false
var armor_restore := 0.0
var attack_landed := false
var windup_scale := 1.0
var _hover_phase := 0.0
var _poise_regen := 0.0
var _death_time := 0.0
var _spawn_bob := 0.0
var _id := 0

static var _next_id := 1


func setup(p_kind: String, p_player: Node2D, p_fx: Node, p_world: Node) -> void:
	kind = p_kind
	config = GameConfig.enemy(kind)
	player = p_player
	fx = p_fx
	world = p_world
	_id = _next_id
	_next_id += 1
	hp = float(config.hp)
	max_hp = hp
	poise = float(config.poise)
	max_poise = poise
	_hover_phase = randf() * TAU
	_spawn_bob = randf() * TAU
	cooldown = randf_range(0.4, 1.0)
	state = "Idle"
	state_time = 0.0


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("hurtable")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 6.0
	if config.get("flying", false):
		collision_mask = 0
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	match kind:
		"guard":
			cap.radius = 26.0
			cap.height = 94.0
			shape.position = Vector2(0, -47)
		"sprite":
			cap.radius = 18.0
			cap.height = 54.0
			shape.position = Vector2(0, -27)
		"dissonant":
			cap.radius = 17.0
			cap.height = 66.0
			shape.position = Vector2(0, -33)
		_:
			cap.radius = 16.0
			cap.height = 52.0
			shape.position = Vector2(0, -26)
	shape.shape = cap
	add_child(shape)
	z_index = 8


func _physics_process(delta: float) -> void:
	if dead:
		_death_time += delta
		queue_redraw()
		return
	if hitstop > 0.0:
		hitstop = maxf(0.0, hitstop - delta)
		queue_redraw()
		return
	flash = maxf(0.0, flash - delta * 6.0)
	state_time += delta
	cooldown = maxf(0.0, cooldown - delta)
	_poise_regen += delta
	if _poise_regen > 2.2 and poise < max_poise and state != "Stagger":
		poise = minf(max_poise, poise + max_poise * delta * 0.9)
	if armor_broken:
		armor_restore -= delta
		if armor_restore <= 0.0:
			armor_broken = false
	if stagger_left > 0.0:
		stagger_left -= delta
		if stagger_left <= 0.0 and state == "Stagger":
			state = "Recover"
			state_time = 0.0

	if player == null or player.dead:
		_idle(delta)
		queue_redraw()
		return

	var pp: Vector2 = player.global_position
	var dist := global_position.distance_to(pp)
	if not activated:
		if dist < 760.0:
			activated = true
			state = "Approach"
			state_time = 0.0
			if fx:
				fx.spawn_glyph(global_position + Vector2(0, -80), "!", config.color, 22)
		_idle(delta)
		queue_redraw()
		return

	facing = 1 if pp.x >= global_position.x else -1
	match state:
		"Idle", "Approach":
			_update_approach(delta)
		"Windup":
			_update_windup(delta)
		"Attack":
			_update_attack_state(delta)
		"Recover":
			_update_recover(delta)
		"Stagger":
			_update_stagger(delta)
		"Hurt":
			if state_time > 0.13:
				state = "Approach"
				state_time = 0.0
			_apply_gravity(delta)
		_:
			_update_approach(delta)
	queue_redraw()


func _idle(delta: float) -> void:
	if config.get("flying", false):
		_hover(delta)
	else:
		_apply_gravity(delta)
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + float(config.gravity) * delta, 1000.0)


func _update_approach(delta: float) -> void:
	if player == null:
		return
	var pp: Vector2 = player.global_position
	var dist_x := absf(pp.x - global_position.x)
	var dy := pp.y - global_position.y
	if config.get("flying", false):
		_hover(delta)
	else:
		_apply_gravity(delta)
	var speed := float(config.speed)
	match kind:
		"sprite":
			var target_y := pp.y - float(config.hover) + sin(_hover_phase + state_time * 2.0) * 12.0
			var desired_x := pp.x + (global_position.x - pp.x) * 0.82
			global_position.x = move_toward(global_position.x, desired_x, speed * delta * 0.35)
			global_position.y = move_toward(global_position.y,
				target_y + sin(state_time * 2.2 + _hover_phase) * 8.0, 80.0 * delta)
			velocity = Vector2.ZERO
		"guard":
			if dist_x > float(config.attack_range) * 0.82:
				velocity.x = move_toward(velocity.x, facing * speed, 420.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
		"dissonant":
			if dist_x > float(config.attack_range) * 0.8:
				velocity.x = move_toward(velocity.x, facing * speed, 900.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, -facing * 40.0, 600.0 * delta)
		_:
			if dist_x > float(config.attack_range) * 0.72:
				velocity.x = move_toward(velocity.x, facing * speed, 1000.0 * delta)
			else:
				velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	# attack decision
	if cooldown <= 0.0 and _can_start_attack(dist_x, absf(dy)):
		state = "Windup"
		state_time = 0.0
		attack_landed = false
		windup_scale = 1.0
		if kind == "dissonant":
			windup_scale = randf_range(0.68, 1.32)
		velocity.x = 0.0
		AudioBank.play_varied("telegraph", -6.0, 0.04)
		queue_redraw()
	if not config.get("flying", false):
		move_and_slide()


func _hover(delta: float) -> void:
	velocity = Vector2.ZERO
	global_position.y += sin(state_time * 2.1 + _hover_phase) * 4.0 * delta


func _can_start_attack(dist_x: float, dy: float) -> bool:
	match kind:
		"sprite":
			return dist_x < float(config.attack_range) and absf(dy) < 260.0
		"guard":
			return dist_x < float(config.attack_range) + 16.0 and dy > -90.0
		_:
			return dist_x < float(config.attack_range) + 18.0 and dy > -70.0


func _update_windup(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	if not config.get("flying", false):
		_apply_gravity(delta)
		move_and_slide()
	else:
		_hover(delta)
	if state_time >= float(config.windup) * windup_scale:
		state = "Attack"
		state_time = 0.0
		attack_landed = false
		_on_attack_start()


func _on_attack_start() -> void:
	match kind:
		"note":
			velocity.x = facing * 300.0
			if fx:
				fx.spawn_dust(global_position, Color(config.color, 0.35))
			AudioBank.play_varied("swing_light", -5.0, 0.04)
		"guard":
			velocity.x = facing * 55.0
			AudioBank.play("boss_slam", 1.25, -4.0)
			GameEvents.shake.emit(5.0)
			if fx:
				fx.spawn_shockwave(
					global_position + Vector2(facing * 62, -10),
					config.color, 148.0)
		"sprite":
			_fire_projectile()
			AudioBank.play_varied("boss_shot", -4.0, 0.05)
		"dissonant":
			velocity.x = facing * 360.0
			if fx:
				fx.spawn_glitch(global_position + Vector2(0, -32), config.color)
			AudioBank.play_varied("swing_light", 1.25, -7.0)


func _update_attack_state(delta: float) -> void:
	if not attack_landed and state_time <= float(config.active):
		_attack_check()
	if state_time >= float(config.active):
		state = "Recover"
		state_time = 0.0
		velocity.x *= 0.3
	if not config.get("flying", false):
		_apply_gravity(delta)
		move_and_slide()


func _attack_check() -> void:
	if player == null:
		return
	var center := global_position + Vector2(0, -38)
	match kind:
		"note":
			if absf(player.global_position.x - global_position.x) < 78.0 \
					and absf(player.global_position.y - global_position.y) < 76.0:
				_land_attack()
		"guard":
			if center.distance_to(player.get_center()) < 158.0:
				_land_attack()
		"dissonant":
			if absf(player.global_position.x - global_position.x) < 96.0 \
					and absf(player.global_position.y - global_position.y) < 80.0:
				_land_attack()


func _land_attack() -> void:
	attack_landed = true
	if player.receive_hit(float(config.damage), global_position, 280.0):
		GameEvents.shake.emit(2.0)


func _fire_projectile() -> void:
	if world == null or not world.has_method("spawn_enemy_projectile"):
		return
	var origin := global_position + Vector2(facing * 22, -42)
	var target: Vector2 = player.get_center()
	world.spawn_enemy_projectile(origin, target, float(config.damage), config.color)


func _update_recover(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	if not config.get("flying", false):
		_apply_gravity(delta)
		move_and_slide()
	else:
		_hover(delta)
	if state_time >= float(config.recovery):
		state = "Approach"
		state_time = 0.0
		cooldown = float(config.cooldown)
		if kind == "dissonant":
			cooldown += randf_range(-0.18, 0.3)


func _update_stagger(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
	if not config.get("flying", false):
		_apply_gravity(delta)
		move_and_slide()
	if state_time > stagger_left + 0.01 and stagger_left <= 0.0:
		state = "Approach"
		state_time = 0.0
		cooldown = 0.35


func receive_attack(info: Dictionary) -> Dictionary:
	if dead:
		return {"hit": false}
	var attack_id: String = info.get("attack_id", "light")
	var direction: int = info.get("direction", 1)
	var source: Node2D = info.get("source", null) as Node2D
	var from_front := true
	if source != null:
		from_front = signf(source.global_position.x - global_position.x) == float(facing) \
			or absf(source.global_position.x - global_position.x) < 18.0
	var blocked := false
	if kind == "guard" and not armor_broken and from_front \
			and attack_id != "heavy" and state != "Stagger":
		blocked = true
	var damage := 0.0
	if not blocked:
		damage = float(info.damage)
		if kind == "guard" and armor_broken:
			damage *= 1.2
		hp = maxf(0.0, hp - damage)
		poise -= float(info.poise)
		flash = 1.0
		hitstop = maxf(hitstop, float(info.hitstop))
		var kb := float(info.knockback) * float(config.knockback_res)
		velocity.x = signf(global_position.x - source.global_position.x) * kb if source else direction * kb
		if float(info.lift) < 0.0 and not config.get("flying", false):
			velocity.y = float(info.lift) * float(config.knockback_res)
		elif float(info.lift) < 0.0:
			velocity.y = float(info.lift) * 0.4
		if poise <= 0.0 and kind != "guard":
			_enter_stagger(0.65)
		elif kind != "guard" and state not in ["Stagger", "Death"]:
			state = "Hurt"
			state_time = 0.0
			cooldown = maxf(cooldown, 0.28)
		if kind == "guard" and attack_id == "heavy" and not blocked:
			armor_broken = true
			armor_restore = 5.0
			_enter_stagger(1.55)
			GameEvents.enemy_staggered.emit(kind)
			if fx:
				fx.spawn_judgement_text(global_position + Vector2(0, -105),
					"破防", ResonantUI.GOLD, 26)
			AudioBank.play("seal_hit", 0.8, -2.0)
		if hp <= 0.0:
			_die()
		return {
			"hit": true,
			"blocked": false,
			"damage": damage,
			"killed": dead,
			"crit": kind == "guard" and attack_id == "heavy",
			"fx_pos": global_position + Vector2(0, -44),
			"color": config.color,
			"count_rhythm": true,
		}
	else:
		poise -= float(info.poise) * 0.2
		flash = 0.6
		hitstop = maxf(hitstop, 0.02)
		velocity.x = direction * 20.0
		if poise <= 0.0:
			armor_broken = true
			armor_restore = 4.0
			_enter_stagger(1.1)
			GameEvents.enemy_staggered.emit(kind)
		return {
			"hit": true,
			"blocked": true,
			"damage": 0.0,
			"killed": false,
			"crit": false,
			"fx_pos": global_position + Vector2(facing * 24, -50),
			"color": Color("d9e2ff"),
			"count_rhythm": true,
		}


func _enter_stagger(duration: float) -> void:
	state = "Stagger"
	state_time = 0.0
	stagger_left = duration
	poise = 0.0
	_poise_regen = 0.0


func _die() -> void:
	if dead:
		return
	dead = true
	state = "Death"
	state_time = 0.0
	collision_layer = 0
	velocity = Vector2.ZERO
	GameState.register_kill(kind)
	AudioBank.play(str(config.death_sfx), 1.0, -2.0)
	if fx:
		fx.spawn_death(global_position + Vector2(0, -38), config.color, kind)
		fx.spawn_note_trail(global_position + Vector2(0, -60),
			Color(config.color, 0.9))
	GameEvents.shake.emit(2.5)
	if world and world.has_method("on_enemy_killed"):
		world.on_enemy_killed(self)
	var timer := get_tree().create_timer(0.55)
	timer.timeout.connect(queue_free)


func get_hurtbox() -> Rect2:
	match kind:
		"guard":
			return Rect2(global_position + Vector2(-30, -98), Vector2(60, 96))
		"dissonant":
			return Rect2(global_position + Vector2(-23, -72), Vector2(46, 70))
		"sprite":
			return Rect2(global_position + Vector2(-26, -58), Vector2(52, 54))
		_:
			return Rect2(global_position + Vector2(-22, -58), Vector2(44, 56))


func get_center() -> Vector2:
	return global_position + Vector2(0, -38 if kind != "guard" else -50)


func _process(delta: float) -> void:
	_spawn_bob += delta
	queue_redraw()


func _draw() -> void:
	var alpha := 1.0
	if dead:
		alpha = maxf(0.0, 1.0 - _death_time * 2.4)
	if not activated:
		alpha *= 0.72
	modulate = Color(1, 1, 1, alpha)
	# shadow
	if not config.get("flying", false):
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.28))
		draw_circle(Vector2(0, 9), 19.0 if kind != "guard" else 30.0,
			Color(0, 0, 0, 0.34), true)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_set_transform(Vector2(0, 130), 0, Vector2(1, 0.25))
		draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.2), true)
		draw_set_transform(Vector2.ZERO)

	_draw_telegraph()
	var flash_col := Color(1, 1, 1, 1) if flash > 0.35 else Color.WHITE
	match kind:
		"note":
			_draw_note(flash_col)
		"guard":
			_draw_guard(flash_col)
		"sprite":
			_draw_sprite(flash_col)
		"dissonant":
			_draw_dissonant(flash_col)
	_draw_health()
	if state == "Stagger":
		_draw_stagger_marks()


func _draw_telegraph() -> void:
	if state != "Windup":
		return
	var t := clampf(state_time / maxf(float(config.windup) * windup_scale, 0.01), 0, 1)
	var col: Color = config.color
	var alpha := 0.18 + sin(t * PI) * 0.45
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.3))
	draw_arc(Vector2.ZERO, 48.0 + t * 28.0, 0, TAU, 30, Color(col, alpha * 0.2), 8.0, true)
	draw_arc(Vector2.ZERO, 48.0 + t * 28.0, 0, TAU, 30, Color(col, alpha), 2.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_note(overlay: Color) -> void:
	var bob := sin(_spawn_bob * 3.0 + _hover_phase) * 3.0
	var c: Color = config.color
	var body := Vector2(0, -28 + bob)
	var squash := 1.0 + sin(_spawn_bob * 4.0) * 0.04
	# legs
	var leg := sin(_spawn_bob * 9.0) * 4.0
	draw_line(Vector2(-7, -9), Vector2(-10 + leg, 0), Color(c, 0.6), 2.0, true)
	draw_line(Vector2(7, -9), Vector2(10 - leg, 0), Color(c, 0.6), 2.0, true)
	# tail / flag
	var pts := PackedVector2Array([
		body + Vector2(7, -8), Vector2(17, -48 + bob), Vector2(24, -37 + bob),
		Vector2(14, -18 + bob),
	])
	draw_colored_polygon(pts, Color(c, 0.2))
	draw_polyline(pts, Color(c, 0.8), 2.0, true)
	# head
	draw_set_transform(Vector2(body.x, body.y), 0, Vector2(squash, 2.0 - squash))
	draw_circle(Vector2.ZERO, 19.0, Color(0.025, 0.06, 0.065, 0.98), true)
	draw_circle(Vector2.ZERO, 16.0, Color(c, 0.16), true)
	draw_arc(Vector2.ZERO, 19.0, 0, TAU, 32, Color(c, 0.8), 2.0, true)
	draw_set_transform(Vector2.ZERO)
	# eyes
	var look := facing * 4.0
	draw_circle(body + Vector2(look - 5, -4), 4.2, Color(0.01, 0.02, 0.03), true)
	draw_circle(body + Vector2(look + 5, -4), 4.2, Color(0.01, 0.02, 0.03), true)
	draw_circle(body + Vector2(look - 4 + facing, -5), 1.6, Color(c, 0.95), true)
	draw_circle(body + Vector2(look + 6 + facing, -5), 1.6, Color(c, 0.95), true)
	# note stem
	draw_line(body + Vector2(9, -14), body + Vector2(9, -38), Color(c, 0.9), 2.0, true)
	if flash > 0.35:
		draw_circle(body, 24.0, Color(overlay, 0.16), true)


func _draw_guard(overlay: Color) -> void:
	var c: Color = config.color
	var crouch := 0.0
	if state == "Windup":
		crouch = sin(clampf(state_time / float(config.windup), 0, 1) * PI) * 7.0
	elif state == "Stagger":
		crouch = 12.0
	var lean := 7.0 * facing if state == "Attack" else 0.0
	# legs
	draw_line(Vector2(-14, -36), Vector2(-18, 0), Color(0.04, 0.07, 0.09), 12.0, true)
	draw_line(Vector2(14, -36), Vector2(18, 0), Color(0.04, 0.07, 0.09), 12.0, true)
	# torso armour
	var torso := PackedVector2Array([
		Vector2(-26, -36 + crouch), Vector2(-31, -80 + crouch),
		Vector2(-17, -98 + crouch), Vector2(20, -98 + crouch),
		Vector2(31, -77 + crouch), Vector2(27, -38 + crouch),
	])
	draw_colored_polygon(torso, Color(0.07, 0.09, 0.10))
	draw_polyline(torso + PackedVector2Array([torso[0]]), Color(c, 0.55), 2.0, true)
	# front shield plate
	var shield_x := facing * 22.0
	var shield := PackedVector2Array([
		Vector2(shield_x - 12, -89 + crouch), Vector2(shield_x + 14, -84 + crouch),
		Vector2(shield_x + 17, -43 + crouch), Vector2(shield_x + 2, -30 + crouch),
		Vector2(shield_x - 15, -42 + crouch),
	])
	draw_colored_polygon(shield, Color(c, 0.16))
	draw_polyline(shield + PackedVector2Array([shield[0]]),
		Color(c, 0.9 if not armor_broken else 0.2), 2.0, true)
	for i in 3:
		draw_line(Vector2(shield_x - 8, -78 + i * 14 + crouch),
			Vector2(shield_x + 11, -76 + i * 14 + crouch),
			Color(c, 0.25 if not armor_broken else 0.08), 1.0, true)
	# head / helmet
	draw_circle(Vector2(5, -104 + crouch), 13.0, Color(0.03, 0.05, 0.06), true)
	draw_arc(Vector2(5, -104 + crouch), 13.0, PI, TAU, 18, Color(c, 0.8), 2.0, true)
	draw_line(Vector2(5, -112 + crouch), Vector2(5, -124 + crouch), Color(c, 0.8), 3.0, true)
	# eye slit
	draw_line(Vector2(facing * 2 + 2, -104 + crouch), Vector2(facing * 9 + 2, -104 + crouch),
		Color(c, 0.95), 2.0, true)
	# hammer arm during windup / attack
	var arm_angle := -1.4
	if state == "Windup":
		arm_angle = lerpf(-1.4, -2.6, clampf(state_time / float(config.windup), 0, 1))
	elif state == "Attack":
		arm_angle = 0.85
	var shoulder := Vector2(facing * 18, -74 + crouch + lean)
	var hand := shoulder + Vector2.from_angle(arm_angle * facing) * 34.0
	draw_line(shoulder, hand, Color(0.06, 0.08, 0.1), 8.0, true)
	draw_circle(hand, 9.0, Color(c, 0.22))
	draw_circle(hand, 5.0, Color(c, 0.8))
	if flash > 0.35:
		draw_colored_polygon(torso, Color(overlay, 0.18))


func _draw_sprite(overlay: Color) -> void:
	var c: Color = config.color
	var bob := sin(_spawn_bob * 2.0 + _hover_phase) * 4.0
	var center := Vector2(0, -32 + bob)
	# wings
	for side in [-1, 1]:
		var flap := sin(_spawn_bob * 8.0 + side) * 0.25
		var pts := PackedVector2Array([
			center + Vector2(0, -2),
			center + Vector2(side * 34, -25 - flap * 20),
			center + Vector2(side * 24, -2),
			center + Vector2(side * 36, 16 + flap * 16),
		])
		draw_colored_polygon(pts, Color(c, 0.09))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(c, 0.55), 1.4, true)
	# body treble-clef-ish
	draw_circle(center, 12.0, Color(0.04, 0.03, 0.08), true)
	draw_arc(center, 13.0, 0, TAU, 28, Color(c, 0.8), 1.8, true)
	draw_arc(center + Vector2(0, -12), 8.0, 1.2, 4.4, 18, Color(c, 0.8), 2.2, true)
	draw_line(center + Vector2(0, -18), center + Vector2(0, 16), Color(c, 0.8), 1.8, true)
	draw_circle(center + Vector2(facing * 4, -2), 2.0, Color(c, 0.95), true)
	if flash > 0.35:
		draw_circle(center, 22.0, Color(overlay, 0.15), true)


func _draw_dissonant(overlay: Color) -> void:
	var c: Color = config.color
	var bob := sin(_spawn_bob * 6.0) * 2.0
	var center := Vector2(0, -36 + bob)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_msec() / 50) + _id * 17
	var jitter := Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
	var pts := PackedVector2Array()
	for i in 9:
		var a := i * TAU / 9.0 + _spawn_bob * 0.3
		var r := 22.0 + sin(i * 2.7 + _spawn_bob * 3.0) * 7.0
		pts.append(center + Vector2.from_angle(a) * r + jitter)
	draw_colored_polygon(pts, Color(0.08, 0.02, 0.04, 0.92))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(c, 0.8), 2.0, true)
	# inner eye
	draw_circle(center, 10.0, Color(0.02, 0.01, 0.02), true)
	draw_circle(center + Vector2(facing * 4, 0), 5.0, Color(c, 0.85), true)
	draw_circle(center + Vector2(facing * 5, 0), 2.0, Color(0.05, 0.01, 0.02), true)
	# floating shards
	for i in 4:
		var a := _spawn_bob * 1.5 + i * TAU / 4.0
		var p := center + Vector2.from_angle(a) * (32 + i * 3)
		draw_line(p, p + Vector2(rng.randf_range(-9, 9), rng.randf_range(-9, 9)),
			Color(c, 0.55), 1.5, true)
	# legs
	draw_line(Vector2(-8, -16), Vector2(-13, 0), Color(c, 0.45), 2.0, true)
	draw_line(Vector2(8, -16), Vector2(13, 0), Color(c, 0.45), 2.0, true)
	if flash > 0.35:
		draw_colored_polygon(pts, Color(overlay, 0.16))


func _draw_health() -> void:
	if hp >= max_hp or not activated or dead:
		return
	var w := 44.0 if kind != "guard" else 60.0
	var y := -68.0
	match kind:
		"guard":
			y = -138.0
		"sprite":
			y = -64.0
		"dissonant":
			y = -78.0
	draw_rect(Rect2(-w * 0.5 - 1, y - 1, w + 2, 6), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(-w * 0.5, y, w * (hp / max_hp), 4), Color(config.color, 0.85))
	if armor_broken:
		draw_rect(Rect2(-w * 0.5, y + 6, w, 1), Color(ResonantUI.GOLD, 0.7))


func _draw_stagger_marks() -> void:
	var c := ResonantUI.GOLD
	for i in 3:
		var a := _spawn_bob * 2.0 + i * TAU / 3.0
		var p := Vector2(cos(a) * 30, -80 + sin(a) * 22)
		draw_line(p - Vector2(3, 3), p + Vector2(3, 3), Color(c, 0.7), 1.5, true)
