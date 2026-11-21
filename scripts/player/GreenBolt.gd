extends Area2D

@export var speed := 540.0
@export var max_distance := 280.0
@export var damage := 1

var direction := 1.0
var owner_player: Node2D
var start_position := Vector2.ZERO
var origin_direction := 1.0
var reflection_cooldown := 0.0

func _ready() -> void:
	start_position = global_position
	origin_direction = direction
	add_to_group("player_projectile")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	reflection_cooldown = maxf(0.0, reflection_cooldown - delta)
	global_position.x += speed * direction * delta
	if global_position.distance_to(start_position) >= max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		return
	if not body.has_method("apply_hit"):
		return
	var killed := false
	for _i in range(damage):
		killed = body.apply_hit(-1) or killed
	if killed and owner_player != null and owner_player.has_method("on_enemy_killed"):
		owner_player.on_enemy_killed()
	queue_free()

func _on_area_entered(area: Area2D) -> void:
	if reflection_cooldown > 0.0:
		return
	if area == null or not area.has_method("reflect_to_origin"):
		return
	var pm := owner_player.get_node("PowerManager") as PowerManager if owner_player != null and owner_player.has_node("PowerManager") else null
	if pm == null or not pm.red_reflection_enabled():
		return
	if area.is_in_group("player_wave_arc"):
		return
	reflect_to_origin()
	area.call("reflect_to_origin")
	reflection_cooldown = 0.08

func reflect_to_origin() -> void:
	var traveled := global_position.distance_to(start_position)
	var remaining := maxf(0.0, max_distance - traveled)
	max_distance = maxf(8.0, remaining * 0.5)
	start_position = global_position
	direction = -direction
	reflection_cooldown = 0.08
