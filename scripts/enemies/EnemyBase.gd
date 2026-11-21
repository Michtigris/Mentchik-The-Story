class_name EnemyBase
extends CharacterBody2D

const AudioSynth = preload("res://scripts/audio/AudioSynth.gd")
const GARGOYLE_FRAMES := [
	"res://animation/gargouille/gargouille1.webp",
	"res://animation/gargouille/gargouille2.webp",
	"res://animation/gargouille/gargouille3.webp",
	"res://animation/gargouille/gargouille4.webp"
]
enum EnemyState { PATROL, ALERT, CHASE, ATTACK, RECOVER }

@export var speed := 90.0
@export var chase_speed := 145.0
@export var health := 3
@export var patrol_distance := 120.0
@export var vision_range := 260.0
@export var vision_height := 90.0
@export var aggro_detection_range := 1400.0
@export var max_simultaneous_aggro := 3
@export var aggro_start_delay := 2.0
@export var attack_range := 34.0
@export var attack_damage := 1
@export var attack_cooldown := 0.9
@export var alert_duration := 0.45
@export var recover_duration := 0.35
@export var hit_stun_duration := 0.18
@export var hit_knockback := 230.0
@export var hit_hop_force := -160.0
@export var min_turn_interval := 0.5

var start_x := 0.0
var direction := 1.0
var attack_timer := 0.0
var state_timer := 0.0
var hit_stun_timer := 0.0
var state := EnemyState.PATROL
var visual_ref: Polygon2D
var eyes_ref: Polygon2D
var aura_ref: Polygon2D
var gargoyle_sprite: Sprite2D
var gargoyle_frames: Array[Texture2D] = []
var visual_time := 0.0
var hit_flash_timer := 0.0
var aggro_lock_timer := 0.0
var turn_timer := 0.0

func _ready() -> void:
	add_to_group("enemy")
	aggro_lock_timer = aggro_start_delay
	start_x = global_position.x
	if has_node("VisualRoot/Body"):
		visual_ref = $VisualRoot/Body
	if has_node("VisualRoot/Eyes"):
		eyes_ref = $VisualRoot/Eyes
	if has_node("VisualRoot/Aura"):
		aura_ref = $VisualRoot/Aura
	_setup_gargoyle_skin()

func _physics_process(delta: float) -> void:
	var time_scale := 1.0
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_node("PowerManager"):
		var pm: PowerManager = player.get_node("PowerManager")
		time_scale = pm.yellow_time_scale()
	var scaled_delta := delta * time_scale
	visual_time += delta
	attack_timer = maxf(0.0, attack_timer - scaled_delta)
	state_timer = maxf(0.0, state_timer - scaled_delta)
	hit_stun_timer = maxf(0.0, hit_stun_timer - scaled_delta)
	hit_flash_timer = maxf(0.0, hit_flash_timer - scaled_delta)
	aggro_lock_timer = maxf(0.0, aggro_lock_timer - scaled_delta)
	turn_timer = maxf(0.0, turn_timer - scaled_delta)
	if not is_on_floor():
		velocity.y += 980.0 * scaled_delta
	if aggro_lock_timer > 0.0:
		state = EnemyState.PATROL
	else:
		_update_state_machine(player)
	if hit_stun_timer <= 0.0:
		_apply_state_movement(player)
	_custom_behavior(scaled_delta, player)
	velocity.x *= time_scale
	_update_visuals(state == EnemyState.CHASE or state == EnemyState.ATTACK)
	move_and_slide()

func apply_hit(power_id: int, force_kill: bool = false) -> bool:
	_play_hit_animation()
	if force_kill:
		health = 0
	elif _is_weak_to(power_id):
		health -= 2
	else:
		health -= 1
	var knock := 1.0
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		knock = sign(global_position.x - player.global_position.x)
	if knock == 0:
		knock = 1.0
	velocity.x = knock * hit_knockback
	velocity.y = hit_hop_force
	hit_stun_timer = hit_stun_duration
	if health <= 0:
		_play_death_sound()
		queue_free()
		return true
	return false

func _is_weak_to(_power_id: int) -> bool:
	return false

func _patrol() -> void:
	velocity.x = speed * direction
	if abs(global_position.x - start_x) > patrol_distance:
		_try_set_direction(-direction)

func _chase_player(player: Node2D) -> void:
	var target_dir: float = sign(player.global_position.x - global_position.x)
	if target_dir != 0.0:
		_try_set_direction(target_dir)
	velocity.x = direction * chase_speed

func _try_set_direction(target_dir: float) -> void:
	if target_dir == 0.0:
		return
	target_dir = 1.0 if target_dir > 0.0 else -1.0
	var current_dir := 1.0 if direction >= 0.0 else -1.0
	if target_dir == current_dir:
		return
	if turn_timer > 0.0:
		return
	direction = target_dir
	turn_timer = min_turn_interval

func _can_see_player(player: Node2D) -> bool:
	var delta := player.global_position - global_position
	return absf(delta.x) <= vision_range and absf(delta.y) <= vision_height

func _is_player_within_aggro_range(player: Node2D) -> bool:
	return global_position.distance_to(player.global_position) <= aggro_detection_range

## True si cet ennemi est dans le cadre visible de la camera (hors ecran = pas d'aggro).
func _is_enemy_in_camera_frame() -> bool:
	var vp := get_viewport()
	if vp == null:
		return true
	var cam := vp.get_camera_2d()
	if cam == null:
		return true
	var half_size := vp.get_visible_rect().size * 0.5
	var z := cam.zoom
	if z.x <= 0.0001:
		z.x = 1.0
	if z.y <= 0.0001:
		z.y = 1.0
	half_size.x /= z.x
	half_size.y /= z.y
	var center := cam.get_screen_center_position()
	var pad := 40.0
	return absf(global_position.x - center.x) <= half_size.x + pad and absf(global_position.y - center.y) <= half_size.y + pad

func _has_aggro_slot(player: Node2D) -> bool:
	if aggro_lock_timer > 0.0:
		return false
	var ranked: Array[Dictionary] = []
	for enemy_node in get_tree().get_nodes_in_group("enemy"):
		if not (enemy_node is EnemyBase):
			continue
		var enemy := enemy_node as EnemyBase
		if enemy == null:
			continue
		if player.global_position.distance_to(enemy.global_position) > enemy.aggro_detection_range:
			continue
		if not enemy._is_enemy_in_camera_frame():
			continue
		ranked.append({
			"enemy": enemy,
			"dist": player.global_position.distance_to(enemy.global_position)
		})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("dist", 999999.0)) < float(b.get("dist", 999999.0))
	)
	var limit := maxi(1, max_simultaneous_aggro)
	for i in range(mini(limit, ranked.size())):
		var e: EnemyBase = ranked[i].get("enemy")
		if e == self:
			return true
	return false

func _try_attack_player(player: Node2D) -> void:
	if attack_timer > 0.0:
		return
	if not _has_aggro_slot(player):
		return
	if player.global_position.distance_to(global_position) > attack_range:
		return
	if player.has_method("take_damage"):
		_play_attack_animation()
		player.take_damage(attack_damage, global_position.x)
		attack_timer = attack_cooldown
		state = EnemyState.ATTACK
		state_timer = 0.16

func _play_attack_animation() -> void:
	if visual_ref == null:
		if gargoyle_sprite != null:
			gargoyle_sprite.modulate = Color(0.9, 0.35, 0.35, 1.0)
		return
	var original_scale := visual_ref.scale
	visual_ref.color = Color(0.9, 0.35, 0.35, 1.0)
	if gargoyle_sprite != null:
		gargoyle_sprite.modulate = Color(0.9, 0.35, 0.35, 1.0)
	var tween := create_tween()
	tween.tween_property(visual_ref, "scale", Vector2(1.2, 0.9), 0.07)
	tween.tween_property(visual_ref, "scale", original_scale, 0.07)
	tween.finished.connect(func() -> void:
		visual_ref.color = Color(0.3, 0.2, 0.45, 1.0)
		if gargoyle_sprite != null:
			gargoyle_sprite.modulate = Color(1, 1, 1, 1)
	)

func _play_hit_animation() -> void:
	hit_flash_timer = 0.12
	if visual_ref != null:
		visual_ref.color = Color(1.0, 0.25, 0.25, 1.0)
	if gargoyle_sprite != null:
		gargoyle_sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)

func _update_visuals(is_chasing: bool) -> void:
	if has_node("VisualRoot"):
		$VisualRoot.scale.x = direction
		$VisualRoot.position.y = sin(visual_time * 5.5) * 1.5
	if gargoyle_sprite != null and not gargoyle_frames.is_empty():
		var frame_idx := int(floor(visual_time * 8.0)) % gargoyle_frames.size()
		gargoyle_sprite.texture = gargoyle_frames[frame_idx]
		if hit_flash_timer <= 0.0:
			gargoyle_sprite.modulate = Color(1, 1, 1, 1)
	if visual_ref != null:
		visual_ref.rotation = sin(visual_time * 8.0) * 0.05
		if hit_flash_timer > 0.0:
			visual_ref.color = Color(1.0, 0.25, 0.25, 1.0)
		elif is_chasing:
			visual_ref.color = Color(0.55, 0.25, 0.32, 1.0)
		elif attack_timer <= 0.0:
			visual_ref.color = Color(0.3, 0.2, 0.45, 1.0)
	if eyes_ref != null:
		if state == EnemyState.ALERT:
			eyes_ref.color = Color(1.0, 0.75, 0.35, 1.0)
		elif is_chasing:
			eyes_ref.color = Color(1.0, 0.35, 0.35, 1.0)
		else:
			eyes_ref.color = Color(0.6, 0.85, 1.0, 1.0)
	if aura_ref != null:
		aura_ref.scale = Vector2.ONE * (1.0 + 0.1 * sin(visual_time * 3.0))
		if state == EnemyState.ALERT:
			aura_ref.color = Color(1.0, 0.65, 0.25, 0.2)
		elif is_chasing:
			aura_ref.color = Color(0.8, 0.22, 0.3, 0.2)
		else:
			aura_ref.color = Color(0.35, 0.45, 0.9, 0.16)

func _update_state_machine(player: Node2D) -> void:
	var can_see := false
	if player != null:
		var has_slot := _has_aggro_slot(player)
		can_see = has_slot and _is_enemy_in_camera_frame() and (_can_see_player(player) or _is_player_within_aggro_range(player))
	match state:
		EnemyState.PATROL:
			if can_see:
				state = EnemyState.ALERT
				state_timer = alert_duration
		EnemyState.ALERT:
			if not can_see:
				state = EnemyState.PATROL
			elif state_timer <= 0.0:
				state = EnemyState.CHASE
		EnemyState.CHASE:
			if not can_see:
				state = EnemyState.RECOVER
				state_timer = recover_duration
		EnemyState.ATTACK:
			if state_timer <= 0.0:
				state = EnemyState.CHASE
		EnemyState.RECOVER:
			if can_see:
				state = EnemyState.CHASE
			elif state_timer <= 0.0:
				state = EnemyState.PATROL

func _apply_state_movement(player: Node2D) -> void:
	match state:
		EnemyState.PATROL:
			_patrol()
		EnemyState.ALERT:
			velocity.x = 0.0
		EnemyState.CHASE, EnemyState.ATTACK:
			if player != null:
				if _has_aggro_slot(player):
					_chase_player(player)
					_try_attack_player(player)
				else:
					velocity.x = 0.0
		EnemyState.RECOVER:
			velocity.x = speed * direction * 0.5

func _play_death_sound() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = AudioSynth.make_enemy_death_sfx()
	sfx.volume_db = -6.0
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _custom_behavior(_delta: float, _player: Node2D) -> void:
	pass

func _setup_gargoyle_skin() -> void:
	if not has_node("VisualRoot"):
		return
	for p in GARGOYLE_FRAMES:
		if not ResourceLoader.exists(p):
			continue
		var tex := load(p)
		if tex is Texture2D:
			gargoyle_frames.append(tex)
	if gargoyle_frames.is_empty():
		return
	if visual_ref != null:
		visual_ref.visible = false
	if eyes_ref != null:
		eyes_ref.visible = false
	gargoyle_sprite = Sprite2D.new()
	gargoyle_sprite.name = "GargoyleSprite"
	gargoyle_sprite.texture = gargoyle_frames[0]
	gargoyle_sprite.centered = true
	gargoyle_sprite.position = Vector2(0, -3)
	gargoyle_sprite.scale = Vector2(1.8, 1.8)
	$VisualRoot.add_child(gargoyle_sprite)
