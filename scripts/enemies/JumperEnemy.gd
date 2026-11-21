extends EnemyBase

@export var jump_force := -430.0
@export var gravity := 980.0
@export var jump_interval := 1.1
var jump_timer := 0.5

func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	super._physics_process(delta)

func _custom_behavior(delta: float, player: Node2D) -> void:
	jump_timer = maxf(0.0, jump_timer - delta)
	if jump_timer > 0.0:
		return
	if not is_on_floor():
		return
	if player == null:
		return
	if state == EnemyState.CHASE or state == EnemyState.ATTACK:
		velocity.y = jump_force
		jump_timer = jump_interval
