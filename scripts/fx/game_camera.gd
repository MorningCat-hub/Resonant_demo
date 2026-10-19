extends Camera2D
## Follows the player horizontally, locks down for boss framing and turns
## GameEvents.shake into a decaying camera offset.

var target: Node2D
var follow_y := 392.0
var min_x := 0.0
var max_x := 8400.0
var boss_lock := false
var boss_center := Vector2(7620, 390)
var _shake := 0.0
var _shake_seed := 0.0
var _zoom_target := Vector2.ONE


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	position_smoothing_enabled = false
	GameEvents.shake.connect(add_shake)


func setup(t: Node2D) -> void:
	target = t


func set_bounds(left: float, right: float) -> void:
	min_x = left
	max_x = right


func set_boss_lock(enabled: bool, center: Vector2 = Vector2(7620, 390)) -> void:
	boss_lock = enabled
	boss_center = center


func add_shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


func punch_zoom(amount: float = 0.04) -> void:
	_zoom_target = Vector2(1.0 + amount, 1.0 + amount)
	var tween := create_tween()
	tween.tween_interval(0.28)
	tween.tween_property(self, "_zoom_target", Vector2.ONE, 0.55)


func _process(delta: float) -> void:
	if target == null:
		return
	var desired := Vector2(
		clampf(target.global_position.x + 30.0, min_x + 640.0, max_x - 640.0),
		follow_y
	)
	if boss_lock:
		desired = boss_center
	global_position = global_position.lerp(desired, 1.0 - pow(0.001, delta))
	_shake = maxf(0.0, _shake - delta * 22.0)
	_shake_seed += delta * 60.0
	var strength := _shake * _shake
	offset = Vector2(
		sin(_shake_seed * 2.3) * strength * 1.4,
		cos(_shake_seed * 3.1) * strength
	)
	zoom = zoom.lerp(_zoom_target, 1.0 - pow(0.005, delta))
