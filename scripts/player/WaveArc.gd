extends Area2D

@export var speed := 220.0
@export var max_distance := 220.0
@export var damage := 2
@export var start_scale := 0.75
@export var end_scale := 1.7

var direction := Vector2.RIGHT
var owner_player: Node2D
var start_position := Vector2.ZERO
var hit_targets: Dictionary = {}
var origin_direction := Vector2.RIGHT
var reflection_cooldown := 0.0

func _ready() -> void:
	start_position = global_position
	origin_direction = direction.normalized()
	direction = origin_direction
	add_to_group("player_projectile")
	add_to_group("player_wave_arc")
	rotation = direction.angle()
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	reflection_cooldown = maxf(0.0, reflection_cooldown - delta)
	global_position += direction * speed * delta
	var traveled := global_position.distance_to(start_position)
	var t := clampf(traveled / maxf(1.0, max_distance), 0.0, 1.0)
	var growth := lerpf(start_scale, end_scale, t)
	scale = Vector2(growth, growth)
	rotation = direction.angle()
	if traveled >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		return
	if not body.has_method("apply_hit"):
		return
	if hit_targets.has(body):
		return
	hit_targets[body] = true
	var killed := false
	for _i in range(damage):
		killed = body.apply_hit(-1) or killed
	if killed and owner_player != null and owner_player.has_method("on_enemy_killed"):
		owner_player.on_enemy_killed()

func _on_area_entered(area: Area2D) -> void:
	if reflection_cooldown > 0.0:
		return
	if area == null or not area.has_method("reflect_to_origin"):
		return
	var pm := owner_player.get_node("PowerManager") as PowerManager if owner_player != null and owner_player.has_node("PowerManager") else null
	if pm == null or not pm.red_reflection_enabled():
		return
	# Pas de reflexion rouge contre le tir classique (ni autre projectile joueur).
	if not area.is_in_group("enemy_projectile"):
		return
	# Renvoyer uniquement les projectiles ennemis, pas l'onde.
	area.call("reflect_to_origin")
	reflection_cooldown = 0.08

func reflect_to_origin() -> void:
	# L'attaque de groupe ne doit pas etre deviee ; appelee par EnemyProjectile / GreenBolt
	# qui font reflect sur les deux cotes — ici no-op.
	pass
