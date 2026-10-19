extends Node2D
## A visible note with a small hitbox.  Can be cut out of the air.

var velocity := Vector2.ZERO
var damage := 9.0
var color := Color("b28dff")
var life := 4.0
var dead := false
var fx: Node
var age := 0.0


func setup(origin: Vector2, target: Vector2, p_damage: float, p_color: Color,
		p_fx: Node) -> void:
	global_position = origin
	var dir := (target - origin).normalized()
	if dir.length_squared() < 0.1:
		dir = Vector2.RIGHT
	velocity = dir * 340.0
	damage = p_damage
	color = p_color
	fx = p_fx
	add_to_group("hurtable")
	add_to_group("enemy_projectiles")
	z_index = 12


func _ready() -> void:
	if fx == null:
		fx = get_tree().get_first_node_in_group("fx")


func _physics_process(delta: float) -> void:
	if dead:
		return
	age += delta
	life -= delta
	global_position += velocity * delta
	velocity.y += 50.0 * delta
	if life <= 0.0 or global_position.y > 660.0 \
			or global_position.x < -300.0 or global_position.x > 9000.0:
		_destroy(false)
		return
	var player := get_tree().get_first_node_in_group("player")
	if player and not player.dead:
		if global_position.distance_to(player.get_center()) < 32.0:
			player.receive_hit(damage, global_position, 200.0)
			_destroy(true)


func receive_attack(info: Dictionary) -> Dictionary:
	if dead:
		return {"hit": false}
	_destroy(true, info.get("direction", 1))
	return {
		"hit": true,
		"blocked": false,
		"damage": 0.0,
		"killed": true,
		"count_rhythm": false,
		"fx_pos": global_position,
		"color": color,
	}


func get_hurtbox() -> Rect2:
	return Rect2(global_position - Vector2(17, 17), Vector2(34, 34))


func _destroy(show_fx: bool, direction: int = 1) -> void:
	if dead:
		return
	dead = true
	if show_fx and fx:
		fx.spawn_hit(global_position, direction, color, 0.5)
		AudioBank.play("hit_light", 1.6, -14.0)
	queue_free()


func _draw() -> void:
	var pulse := 1.0 + sin(age * 14.0) * 0.12
	draw_circle(Vector2.ZERO, 12.0 * pulse, Color(color, 0.1), true)
	draw_circle(Vector2.ZERO, 7.0 * pulse, Color(0.05, 0.03, 0.08, 0.9), true)
	draw_arc(Vector2.ZERO, 8.0 * pulse, 0, TAU, 20, Color(color, 0.9), 1.4, true)
	draw_line(Vector2(3, -5), Vector2(3, -19), Color(color, 0.9), 1.5, true)
	draw_line(Vector2(3, -19), Vector2(10, -15), Color(color, 0.9), 1.2, true)
	# trail
	for i in 3:
		draw_circle(-velocity.normalized() * (8.0 + i * 7.0), 3.0 - i * 0.7,
			Color(color, 0.18 - i * 0.05), true)
