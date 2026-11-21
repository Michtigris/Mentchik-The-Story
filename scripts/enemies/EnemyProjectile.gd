extends Area2D

@export var speed := 340.0
@export var life_time := 2.2
@export var damage := 1
var direction := Vector2.RIGHT
var origin_direction := Vector2.RIGHT
var reflection_cooldown := 0.0

func _ready() -> void:
	add_to_group("enemy_projectile")
	origin_direction = direction
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	reflection_cooldown = maxf(0.0, reflection_cooldown - delta)
	var time_scale := 1.0
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_node("PowerManager"):
		var pm: PowerManager = player.get_node("PowerManager")
		time_scale = pm.yellow_time_scale()
	position += direction * speed * delta * time_scale
	life_time -= delta * time_scale
	if life_time <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position.x)
	queue_free()

func deflect(player_facing: float) -> void:
	direction = Vector2(player_facing, -0.1).normalized()

func _on_area_entered(area: Area2D) -> void:
	if reflection_cooldown > 0.0:
		return
	if area == null or not area.has_method("reflect_to_origin"):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_node("PowerManager"):
		return
	var pm: PowerManager = player.get_node("PowerManager")
	if pm == null or not pm.red_reflection_enabled():
		return
	reflect_to_origin()
	area.call("reflect_to_origin")
	reflection_cooldown = 0.08

func reflect_to_origin() -> void:
	life_time = maxf(0.06, life_time * 0.5)
	direction = -direction
	reflection_cooldown = 0.08
