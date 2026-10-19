extends Node2D
## Builds the run, owns encounters and the boss sequence, and is the only node
## that knows the level's choreography.

signal run_complete(victory: bool, finale_success: bool, finale_hits: int)

const LEVEL_ART := preload("res://scripts/world/level_art.gd")
const GATE := preload("res://scripts/world/resonance_gate.gd")
const SEAL := preload("res://scripts/world/resonance_seal.gd")
const PLAYER := preload("res://scripts/player/player.gd")
const ENEMY := preload("res://scripts/enemies/enemy.gd")
const PROJECTILE := preload("res://scripts/enemies/note_projectile.gd")
const BOSS := preload("res://scripts/boss/boss.gd")
const FX_LAYER := preload("res://scripts/fx/fx_layer.gd")
const CAMERA := preload("res://scripts/fx/game_camera.gd")
const TRAINING_DUMMY := preload("res://scripts/world/training_dummy.gd")

const ENCOUNTERS := [
	{
		"gate": 1800.0, "seal": "clean3", "layer": 1, "stage": 0,
		"spawns": [["note", 620.0, 610.0], ["note", 1120.0, 490.0],
			["note", 1430.0, 610.0]],
	},
	{
		"gate": 3950.0, "seal": "heavy2", "layer": 2, "stage": 1,
		"spawns": [["note", 2290.0, 610.0], ["guard", 2880.0, 610.0],
			["note", 3240.0, 610.0], ["sprite", 3420.0, 430.0]],
	},
	{
		"gate": 6470.0, "seal": "variety3", "layer": 3, "stage": 2,
		"spawns": [["note", 4380.0, 610.0], ["guard", 4900.0, 610.0],
			["dissonant", 5400.0, 610.0], ["sprite", 5700.0, 430.0],
			["note", 6150.0, 610.0]],
	},
]

var player: CharacterBody2D
var fx: Node2D
var camera: Camera2D
var level: Node2D
var boss: Node2D
var backdrop: Node
var _enemy_layer: Node2D
var _projectile_layer: Node2D
var _gates: Array[Node] = []
var _boss_gate: Node
var _seal: Node
var _alive := [3, 4, 5]
var _cleared := [false, false, false]
var _seal_done := [false, false, false]
var _stage := -1
var _boss_started := false
var _boss_intro := false
var _finished := false
var _respawning := false
var _checkpoint := 150.0
var _hints := {}
var _time := 0.0
var tutorial_mode := false
var tutorial_dummy: Node2D
var tutorial_gate: Node


func build(backdrop_node: Node, p_tutorial: bool = false) -> void:
	tutorial_mode = p_tutorial
	backdrop = backdrop_node
	level = LEVEL_ART.new()
	add_child(level)

	_enemy_layer = Node2D.new()
	_enemy_layer.name = "Enemies"
	add_child(_enemy_layer)
	_projectile_layer = Node2D.new()
	_projectile_layer.name = "Projectiles"
	add_child(_projectile_layer)

	fx = FX_LAYER.new()
	fx.name = "FX"
	fx.add_to_group("fx")
	add_child(fx)

	for i in ENCOUNTERS.size():
		var encounter: Dictionary = ENCOUNTERS[i]
		var gate := GATE.new()
		gate.setup(float(encounter.gate), GameConfig.STAGES[i].color)
		add_child(gate)
		_gates.append(gate)

	player = PLAYER.new()
	player.name = "Player"
	player.position = Vector2(150, 560)
	add_child(player)
	player.setup(fx, self)

	camera = CAMERA.new()
	camera.name = "Camera"
	add_child(camera)
	camera.setup(player)
	camera.set_bounds(0.0, 8420.0)
	camera.global_position = Vector2(640, 392)
	camera.make_current()

	for i in ENCOUNTERS.size():
		var encounter: Dictionary = ENCOUNTERS[i]
		for spawn: Array in encounter.spawns:
			_spawn_enemy(str(spawn[0]), Vector2(float(spawn[1]), float(spawn[2])), i)

	if tutorial_mode:
		tutorial_gate = GATE.new()
		tutorial_gate.setup(800.0, ResonantUI.TEAL, 300.0)
		add_child(tutorial_gate)
		tutorial_dummy = TRAINING_DUMMY.new()
		tutorial_dummy.setup(self, fx)
		add_child(tutorial_dummy)

	_boss_gate = GATE.new()
	_boss_gate.setup(6810.0, ResonantUI.GOLD, 340.0, true)
	add_child(_boss_gate)
	_add_wall(8392.0)

	GameEvents.player_died.connect(_on_player_died)

	GameState.stage = 0
	GameState.checkpoint_x = _checkpoint
	Conductor.play_level()
	if tutorial_mode:
		_stage = 0
		GameState.tutorial_mode = true
		if backdrop:
			backdrop.set_stage(0)
		GameEvents.objective_changed.emit("完成基础训练",
			"跟随右侧《调律者手册》")
	else:
		GameState.tutorial_mode = false
		_set_stage(0)
		GameEvents.hint.emit("A / D 移动 · W 跳跃", 5.0)


func _add_wall(x: float) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(30, 500)
	shape.shape = box
	shape.position = Vector2(x, 360)
	body.add_child(shape)
	add_child(body)


func _spawn_enemy(kind: String, pos: Vector2, encounter: int) -> void:
	var e := ENEMY.new()
	e.setup(kind, player, fx, self)
	e.encounter_id = encounter
	e.position = pos
	_enemy_layer.add_child(e)
	if tutorial_mode:
		e.visible = false
		e.set_physics_process(false)
		e.activated = false


func _process(delta: float) -> void:
	_time += delta
	if _finished:
		return
	if player == null:
		return
	if camera and backdrop:
		backdrop.set_camera_x(camera.global_position.x)
	if not tutorial_mode and not player.dead and not _boss_intro:
		_check_stage(player.global_position.x)
		_check_hints(player.global_position.x)
		_check_boss_trigger(player.global_position.x)
	if player.global_position.y > 790.0 and not _respawning and not player.dead:
		player.force_death()


func _check_stage(x: float) -> void:
	var stage := 0
	if x >= 6600.0:
		stage = 3
	elif x >= 4100.0:
		stage = 2
	elif x >= 1900.0:
		stage = 1
	if stage == _stage:
		return
	_set_stage(stage)


func _set_stage(stage: int) -> void:
	_stage = stage
	GameState.stage = stage
	if backdrop:
		backdrop.set_stage(stage)
	GameEvents.stage_changed.emit(stage, GameConfig.STAGES[stage].title,
		GameConfig.STAGES[stage].subtitle)
	if stage < 3 and not _cleared[stage]:
		var total: int = ENCOUNTERS[stage].spawns.size()
		var dead: int = total - int(_alive[stage])
		GameEvents.objective_changed.emit("清除失序音符 %d / %d" % [dead, total],
			GameConfig.STAGES[stage].goal)
	elif stage == 3 and not _boss_started:
		GameEvents.objective_changed.emit("进入指挥厅", "沿着最后的音符前进")


func _check_hints(x: float) -> void:
	if x > 340.0 and not _hints.has("move"):
		_hints["move"] = true
		GameEvents.hint.emit("K 快速斩击 · 命中瞬间才计入节拍", 5.0)
	if x > 720.0 and not _hints.has("dodge"):
		_hints["dodge"] = true
		GameEvents.hint.emit("Shift 闪避 · 无敌帧可以穿过攻击", 5.0)
	if x > 1080.0 and not _hints.has("kit"):
		_hints["kit"] = true
		GameEvents.hint.emit("J 低音重击 · L 音波突刺 · I 挑空攻击", 5.5)
	if x > 1560.0 and not _hints.has("seal"):
		_hints["seal"] = true
		GameEvents.hint.emit("清场后，在节拍上攻击共鸣封印", 5.0)


func _check_boss_trigger(x: float) -> void:
	if x > 6920.0 and not _boss_started:
		_start_boss()


func _start_boss() -> void:
	_boss_started = true
	_boss_intro = true
	_boss_gate.close_gate()
	player.set_input_enabled(false)
	player.heal(35.0)
	_checkpoint = 6900.0
	GameState.checkpoint_x = _checkpoint
	camera.set_boss_lock(false)
	camera.set_bounds(6700.0, 8420.0)
	Conductor.play_boss()
	GameEvents.stage_changed.emit(3, "第一乐章 · 终章", "IV. 失序指挥家")
	GameEvents.objective_changed.emit("失序指挥家", "观察指挥棒 · 在乐句间隙反击")
	GameEvents.hint.emit("变奏开始后，动作会比节拍更诚实", 4.5)
	GameEvents.flash.emit(Color(1.0, 0.8, 0.45, 0.14), 0.4)
	if backdrop:
		backdrop.set_mode("boss")

	boss = BOSS.new()
	boss.setup(player, fx, self)
	boss.position = Vector2(7700, 610)
	add_child(boss)

	await get_tree().create_timer(2.35).timeout
	if _finished:
		return
	_boss_intro = false
	player.set_input_enabled(true)
	boss.begin_fight()


func finish_tutorial(skipped: bool = false) -> void:
	if not tutorial_mode:
		return
	tutorial_mode = false
	# Training hits must not inflate the real run's combo/accuracy.
	GameState.reset_run()
	GameState.tutorial_mode = false
	if is_instance_valid(tutorial_dummy):
		if fx:
			fx.spawn_unlock(tutorial_dummy.get_center(), ResonantUI.TEAL)
		tutorial_dummy.queue_free()
	tutorial_dummy = null
	if is_instance_valid(tutorial_gate):
		tutorial_gate.open()
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		e.visible = true
		e.set_physics_process(true)
		e.activated = false
	player.heal(100.0)
	player.invuln = maxf(player.invuln, 0.8)
	_hints["move"] = true
	GameState.stage = 0
	GameState.tutorial_mode = false
	GameState.checkpoint_x = 150.0
	GameEvents.stage_changed.emit(0, "第一乐章 · 失序回廊",
		"I. 找回节拍")
	GameEvents.objective_changed.emit("清除失序音符 0 / 3",
		"让每一次命中落在节拍上")
	GameEvents.toast.emit("教学已跳过 · 直接进入回廊" if skipped
		else "训练完成 · 真实回廊开始", ResonantUI.TEAL)
	GameEvents.hint.emit("K 快速斩击 · 命中瞬间才计入节拍", 5.0)
	GameEvents.flash.emit(Color(0.4, 1.0, 0.85, 0.12), 0.3)


func on_enemy_killed(enemy: Node) -> void:
	if enemy == null:
		return
	var eid: int = int(enemy.encounter_id)
	if eid < 0 or eid >= _alive.size():
		return
	_alive[eid] = maxi(0, _alive[eid] - 1)
	if _alive[eid] > 0:
		var total: int = ENCOUNTERS[eid].spawns.size()
		GameEvents.objective_changed.emit(
			"清除失序音符 %d / %d" % [total - _alive[eid], total],
			GameConfig.STAGES[eid].goal)
		return
	if _cleared[eid]:
		return
	_cleared[eid] = true
	_open_seal(eid)


func _open_seal(eid: int) -> void:
	var enc: Dictionary = ENCOUNTERS[eid]
	var seal_pos: float = float(enc.gate) - 92.0
	_seal = SEAL.new()
	_seal.setup(eid, str(enc.seal), seal_pos, GameConfig.STAGES[eid].color, self)
	add_child(_seal)
	GameEvents.objective_changed.emit("共鸣封印",
		"在节拍上完成封印，找回丢失的声部")
	GameEvents.hint.emit("看准节拍，攻击共鸣封印", 5.0)
	GameEvents.toast.emit("失序音符已清除 · 共鸣封印出现", GameConfig.STAGES[eid].color)


func on_seal_progress(_index: int, current: int, target: int) -> void:
	GameEvents.objective_changed.emit("共鸣封印 %d / %d" % [current, target],
		"只有 GOOD 以上的节拍命中才有效")
	GameEvents.flash.emit(Color(0.6, 1.0, 0.9, 0.06), 0.15)


func on_seal_completed(index: int) -> void:
	if _seal_done[index]:
		return
	_seal_done[index] = true
	var enc: Dictionary = ENCOUNTERS[index]
	_gates[index].open()
	var layer := int(enc.layer)
	GameState.unlock_layer(layer)
	GameState.recover_note(1)
	_checkpoint = float(enc.gate) + 118.0
	GameState.checkpoint_x = _checkpoint
	player.heal(28.0)
	GameEvents.objective_changed.emit("前往下一区域", "跟随重新响起的声部")
	GameEvents.toast.emit(GameState.LAYER_NAMES[layer] + " 已归位",
		GameState.LAYER_COLORS[layer])
	GameEvents.flash.emit(Color(GameState.LAYER_COLORS[layer], 0.12), 0.3)
	GameEvents.shake.emit(4.0)


func spawn_enemy_projectile(origin: Vector2, target: Vector2, damage: float,
		color: Color) -> void:
	var p := PROJECTILE.new()
	p.setup(origin, target, damage, color, fx)
	_projectile_layer.add_child(p)


func _on_player_died() -> void:
	if _respawning or _finished:
		return
	_respawning = true
	GameState.deaths += 1
	GameEvents.objective_changed.emit("乐章中断", "正在从最近的检查点重新开始")
	await get_tree().create_timer(1.55).timeout
	if _finished:
		return
	player.respawn(Vector2(_checkpoint, 552))
	_respawning = false
	GameEvents.objective_changed.emit("重新开始", "失去的连击不会定义整首乐章")
	GameEvents.toast.emit("从检查点继续", ResonantUI.TEAL)


func on_boss_defeated(success: bool, hits: int) -> void:
	if _finished:
		return
	_finished = true
	player.set_input_enabled(false)
	GameState.boss_defeated = true
	GameState.finale_hits = hits
	GameState.finale_success = success
	if success:
		GameState.recover_note(1)
		GameState.coda_restored = true
		GameState.finale_success = true
		Conductor.enable_coda()
		if fx and boss:
			var core: Vector2 = boss.get_core_center()
			fx.spawn_beam(player.get_center(), core, ResonantUI.GOLD)
			fx.spawn_hit(core, 1, ResonantUI.GOLD, 2.2, Rhythm.Grade.PERFECT)
			fx.spawn_shockwave(core, ResonantUI.GOLD, 260.0)
			fx.spawn_glyph(core + Vector2(0, -110), "终 章", ResonantUI.GOLD, 42)
		GameEvents.objective_changed.emit("完美乐章", "所有声部都已归位")
		GameEvents.stage_changed.emit(3, "第一乐章 · 完", "完美乐章")
		GameEvents.flash.emit(Color(1.0, 0.92, 0.7, 0.4), 0.8)
		camera.punch_zoom(0.09)
		GameEvents.shake.emit(15.0)
	else:
		GameEvents.objective_changed.emit("乐章结束", "还有声部留在寂静里")
		GameEvents.stage_changed.emit(3, "第一乐章 · 终", "未完成的乐章")
		GameEvents.flash.emit(Color(0.7, 0.3, 0.35, 0.18), 0.5)
	GameState.finish(true)
	await get_tree().create_timer(4.2 if success else 2.6).timeout
	run_complete.emit(true, success, hits)
