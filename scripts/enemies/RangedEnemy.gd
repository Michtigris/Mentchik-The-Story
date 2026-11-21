extends EnemyBase

@export var shooting_range := 300.0
## Se rapproche puis se tient a la portee max ; trop pres = arret + tir uniquement.
@export var prefers_distance_combat := false
@export var projectile_scene: PackedScene = preload("res://scenes/enemies/EnemyProjectile.tscn")
@export var fire_interval := 1.4
var fire_timer := 0.2
var extra_projectiles := 0
var fire_interval_multiplier := 1.0
var projectile_speed_multiplier := 1.0
var spread_step_radians := 0.12
var burst_enabled := false
var burst_gap := 0.3
var burst_pending_shots := 0
var burst_timer := 0.0

func _chase_player(player: Node2D) -> void:
	if not prefers_distance_combat:
		super._chase_player(player)
		return
	var dx := player.global_position.x - global_position.x
	var adx := absf(dx)
	var toward := signf(dx)
	if toward == 0.0:
		toward = direction
	# Trop loin pour toucher au tir : avancer
	if adx > shooting_range * 0.97:
		_try_set_direction(toward)
		velocity.x = direction * chase_speed
		return
	# Trop pres : ne plus avancer, tirer sur place
	if adx < shooting_range * 0.30:
		_try_set_direction(toward)
		velocity.x = 0.0
		return
	# Autour de la portee max confort (~toucher au limite)
	var ideal := shooting_range * 0.86
	if adx > ideal + 28.0:
		_try_set_direction(toward)
		velocity.x = direction * chase_speed * 0.58
	elif adx < ideal - 32.0:
		_try_set_direction(-toward)
		velocity.x = direction * chase_speed * 0.42
	else:
		_try_set_direction(toward)
		velocity.x = 0.0

func _custom_behavior(delta: float, player: Node2D) -> void:
	if burst_pending_shots > 0:
		burst_timer = maxf(0.0, burst_timer - delta)
		if burst_timer <= 0.0 and player != null:
			_fire_projectile(player)
			burst_pending_shots -= 1
			if burst_pending_shots > 0:
				burst_timer = burst_gap
	fire_timer = maxf(0.0, fire_timer - delta)
	if player == null:
		return
	if state != EnemyState.CHASE and state != EnemyState.ATTACK:
		return
	var dist := global_position.distance_to(player.global_position)
	if dist > shooting_range:
		return
	if fire_timer > 0.0:
		return
	_fire_projectile(player)
	if burst_enabled:
		burst_pending_shots = 1
		burst_timer = burst_gap
	fire_timer = fire_interval * fire_interval_multiplier

func _fire_projectile(player: Node2D) -> void:
	var dir := (player.global_position - global_position).normalized()
	var total_projectiles := 1 + maxi(0, extra_projectiles)
	var middle := float(total_projectiles - 1) * 0.5
	for i in range(total_projectiles):
		var offset := (float(i) - middle) * spread_step_radians
		_spawn_projectile(dir.rotated(offset))
	_play_attack_animation()

func _spawn_projectile(dir: Vector2) -> void:
	var proj := projectile_scene.instantiate()
	proj.global_position = global_position + Vector2(20.0 * sign(dir.x), -6.0)
	proj.direction = dir.normalized()
	if "speed" in proj:
		proj.speed *= projectile_speed_multiplier
	get_parent().add_child(proj)

func apply_level_scaling(upgrades: Dictionary) -> void:
	var attack_speed_stacks := int(upgrades.get("attack_speed_stacks", 0))
	var extra_projectile_stacks := int(upgrades.get("extra_projectile_stacks", 0))
	var double_shot_stacks := int(upgrades.get("double_shot_stacks", 0))
	extra_projectiles = maxi(0, extra_projectile_stacks)
	fire_interval_multiplier = 1.0 / pow(1.5, float(attack_speed_stacks))
	projectile_speed_multiplier = pow(1.4, float(attack_speed_stacks))
	spread_step_radians = lerpf(0.12, 0.08, clampf(float(extra_projectile_stacks) / 7.0, 0.0, 1.0))
	burst_enabled = double_shot_stacks > 0
	burst_gap = maxf(0.22, 0.3 - float(double_shot_stacks - 1) * 0.03) if burst_enabled else 0.3
