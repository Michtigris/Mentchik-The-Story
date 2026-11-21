extends Area2D

@export var speed := 420.0
@export var return_delay := 2.0
var direction := 1.0
var owner_player: Node2D
var hit_targets: Dictionary = {}
var returning := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if owner_player == null:
		queue_free()
		return

	if not returning:
		global_position.x += speed * direction * delta
		return_delay -= delta
		if return_delay <= 0.0:
			returning = true
	else:
		var to_player := owner_player.global_position - global_position
		if to_player.length() < 24.0:
			queue_free()
			return
		global_position += to_player.normalized() * speed * 1.2 * delta

	rotation += 12.0 * delta

func _on_body_entered(body: Node) -> void:
	if body == owner_player:
		return
	if not body.has_method("apply_hit"):
		return
	if hit_targets.has(body):
		return
	hit_targets[body] = true
	var killed: bool = body.apply_hit(-1)
	if killed and owner_player != null and owner_player.has_method("on_enemy_killed"):
		owner_player.on_enemy_killed()
