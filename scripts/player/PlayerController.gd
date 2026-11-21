extends CharacterBody2D
signal respawned

const AudioSynth = preload("res://scripts/audio/AudioSynth.gd")
@export var move_speed := 240.0
@export var jump_force := -450.0
@export var gravity := 980.0
@export var dash_speed := 600.0
@export var dash_duration := 0.15
@export var dash_cooldown := 1.5
@export var shadow_blink_cooldown := 0.5
@export var max_jumps := 1
@export var attack_cooldown := 0.6
@export var attack_range := 84.0
@export var max_health := 3
@export var invulnerability_time := 0.8
@export var hurt_knockback := 300.0
@export var sword_cooldown := 2.5
@export var grenade_cooldown := 30.0
@export var grenade_self_damage := 2

@onready var power_manager: PowerManager = $PowerManager
@onready var visual_root: Node2D = $VisualRoot
@onready var body: Polygon2D = $VisualRoot/Body
@onready var head: Polygon2D = $VisualRoot/Head
@onready var cape: Polygon2D = $VisualRoot/Cape
@onready var blade: Polygon2D = $VisualRoot/Blade
@onready var character_sprite: Sprite2D = $VisualRoot/CharacterSprite
@onready var interact_area: Area2D = $InteractArea
@onready var sfx_jump: AudioStreamPlayer = $SFXJump
@onready var sfx_dash: AudioStreamPlayer = $SFXDash
@onready var sfx_attack: AudioStreamPlayer = $SFXAttack
@onready var sfx_hurt: AudioStreamPlayer = $SFXHurt
@onready var sfx_land: AudioStreamPlayer = $SFXLand
@onready var sfx_sword_throw: AudioStreamPlayer = $SFXSwordThrow
@onready var sfx_grenade_throw: AudioStreamPlayer = $SFXGrenadeThrow
@onready var sfx_kill: AudioStreamPlayer = $SFXKill
@onready var sfx_lightning: AudioStreamPlayer = $SFXLightning
const POWER_IDS = preload("res://scripts/powers/StainedGlassPower.gd").PowerId
const GREEN_BOLT_SCENE = preload("res://scenes/player/GreenBolt.tscn")
const WAVE_ARC_SCENE = preload("res://scenes/player/WaveArc.tscn")
const GRENADE_SCENE = preload("res://scenes/player/Grenade.tscn")

var jumps_left := 1
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_trail_timer := 0.0
var shadow_blink_cooldown_timer := 0.0
var stomp_cooldown_timer := 0.0
var white_kill_counter := 0
var is_dashing := false
var facing := 1.0
var attack_timer := 0.0
var current_health := 0
var invulnerability_timer := 0.0
var spawn_position := Vector2.ZERO
var visual_time := 0.0
var lightning_timer := 0.0
var sword_timer := 0.0
var grenade_timer := 0.0
var is_attacking := false
var attack_anim_timer := 0.0
var was_in_air := false
var anim_time := 0.0
var current_anim_key := ""
var animation_frames := {
	"idle": [],
	"walk_right": [],
	"walk_left": [],
	"jump_right": [],
	"jump_left": [],
	"shot_right": [],
	"shot_left": []
}
var animation_fps := {
	"idle": 8.0,
	"walk_right": 10.0,
	"walk_left": 10.0,
	"jump_right": 8.0,
	"jump_left": 8.0,
	"shot_right": 18.0,
	"shot_left": 18.0
}
var animation_offsets := {
	"idle": [],
	"walk_right": [],
	"walk_left": [],
	"jump_right": [],
	"jump_left": [],
	"shot_right": [],
	"shot_left": []
}
const IDLE_PATHS := [
	"res://animation/mench_wait/courir_hero_right_1.png",
	"res://animation/mench_wait/courir_hero_right_2.png"
]
const WALK_RIGHT_PATHS := [
	"res://animation/mench_wald_right/courir_hero_right_1.png",
	"res://animation/mench_wald_right/courir_hero_right_2.png",
	"res://animation/mench_wald_right/courir_hero_right_3.png",
	"res://animation/mench_wald_right/courir_hero_right_4.png",
	"res://animation/mench_wald_right/courir_hero_right_5.png",
	"res://animation/mench_wald_right/courir_hero_right_6.png"
]
const WALK_LEFT_PATHS := [
	"res://animation/mench_walk_left/courir_hero_left_1.png",
	"res://animation/mench_walk_left/courir_hero_left_2.png",
	"res://animation/mench_walk_left/courir_hero_left_3.png",
	"res://animation/mench_walk_left/courir_hero_left_4.png",
	"res://animation/mench_walk_left/courir_hero_left_5.png",
	"res://animation/mench_walk_left/courir_hero_left_6.png"
]
const JUMP_RIGHT_PATHS := [
	"res://animation/mench_jump_right/saut_hero1.webp",
	"res://animation/mench_jump_right/saut_hero2.webp",
	"res://animation/mench_jump_right/saut_hero3.webp",
	"res://animation/mench_jump_right/saut_hero4.webp",
	"res://animation/mench_jump_right/saut_hero5.webp",
	"res://animation/mench_jump_right/saut_hero6.webp",
	"res://animation/mench_jump_right/saut_hero7.webp"
]
const JUMP_LEFT_PATHS := []
const SHOT_RIGHT_PATHS := [
	"res://animation/mench_shot_right/tir_hero_right_1.png",
	"res://animation/mench_shot_right/tir_hero_right_2.png",
	"res://animation/mench_shot_right/tir_hero_right_3.png",
	"res://animation/mench_shot_right/tir_hero_right_4.png",
	"res://animation/mench_shot_right/tir_hero_right_5.png",
	"res://animation/mench_shot_right/tir_hero_right_6.png",
	"res://animation/mench_shot_right/tir_hero_right_7.png",
	"res://animation/mench_shot_right/tir_hero_right_8.png"
]
const SHOT_LEFT_PATHS := [
	"res://animation/mench_shot_left/tir_hero_left_1.png",
	"res://animation/mench_shot_left/tir_hero_left_2.png",
	"res://animation/mench_shot_left/tir_hero_left_3.png",
	"res://animation/mench_shot_left/tir_hero_left_4.png",
	"res://animation/mench_shot_left/tir_hero_left_5.png",
	"res://animation/mench_shot_left/tir_hero_left_6.png",
	"res://animation/mench_shot_left/tir_hero_left_7.png",
	"res://animation/mench_shot_left/tir_hero_left_8.png"
]

func _ready() -> void:
	add_to_group("player")
	jumps_left = max_jumps
	current_health = GameState.get_level_start_health()
	max_health = maxi(max_health, current_health)
	spawn_position = global_position
	body.visible = false
	head.visible = false
	cape.visible = false
	blade.visible = false
	sfx_jump.stream = AudioSynth.make_jump_sfx()
	sfx_dash.stream = AudioSynth.make_dash_sfx()
	sfx_attack.stream = AudioSynth.make_attack_sfx()
	sfx_hurt.stream = AudioSynth.make_hurt_sfx()
	sfx_land.stream = AudioSynth.make_land_sfx()
	sfx_sword_throw.stream = AudioSynth.make_sword_throw_sfx()
	sfx_grenade_throw.stream = AudioSynth.make_grenade_throw_sfx()
	sfx_kill.stream = AudioSynth.make_enemy_death_sfx()
	sfx_lightning.stream = AudioSynth.make_lightning_sfx()
	_load_character_animation_folders()

func _physics_process(delta: float) -> void:
	visual_time += delta
	attack_timer = maxf(0.0, attack_timer - delta)
	attack_anim_timer = maxf(0.0, attack_anim_timer - delta)
	invulnerability_timer = maxf(0.0, invulnerability_timer - delta)
	sword_timer = maxf(0.0, sword_timer - delta)
	grenade_timer = maxf(0.0, grenade_timer - delta)
	dash_cooldown_timer = maxf(0.0, dash_cooldown_timer - delta)
	shadow_blink_cooldown_timer = maxf(0.0, shadow_blink_cooldown_timer - delta)
	stomp_cooldown_timer = maxf(0.0, stomp_cooldown_timer - delta)
	var in_air := not is_on_floor()
	_apply_vitrail_passives(delta)
	_handle_gravity(delta)
	_handle_move()
	_handle_jump()
	_handle_dash(delta)
	_handle_power_cast()
	_handle_tools()
	move_and_slide()
	_try_yellow_stomp()
	if was_in_air and is_on_floor():
		sfx_land.play()
	was_in_air = not is_on_floor()
	_update_interactions()
	_update_visuals(delta)

func _handle_gravity(delta: float) -> void:
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta
	if is_on_floor():
		jumps_left = _get_allowed_jump_count()

func _handle_move() -> void:
	if is_dashing:
		return
	var input_direction := _get_horizontal_input()
	if input_direction != 0:
		facing = sign(input_direction)
	velocity.x = input_direction * move_speed * power_manager.green_speed_multiplier()
	if has_meta("wind_force"):
		velocity.x += float(get_meta("wind_force"))

func _get_horizontal_input() -> float:
	var axis := Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		return axis
	var left_pressed := Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right_pressed := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	if left_pressed and not right_pressed:
		return -1.0
	if right_pressed and not left_pressed:
		return 1.0
	return 0.0

func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and jumps_left > 0:
		velocity.y = jump_force
		jumps_left -= 1
		sfx_jump.play()

func _handle_dash(delta: float) -> void:
	if Input.is_action_just_pressed("dash") and not is_dashing and dash_cooldown_timer <= 0.0 and power_manager.can_dash_ability():
		is_dashing = true
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown * power_manager.green_cooldown_multiplier()
		dash_trail_timer = 0.0
		var speed_multiplier := power_manager.orange_dash_speed_multiplier()
		velocity = Vector2(facing * dash_speed * speed_multiplier, 0.0)
		sfx_dash.play()
	if is_dashing:
		dash_trail_timer -= delta
		if dash_trail_timer <= 0.0:
			dash_trail_timer = 0.045
			_spawn_dash_trail(Color(0.55, 0.8, 1.0, 0.45))
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false

func _spawn_dash_trail(trail_color: Color) -> void:
	if character_sprite.texture == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = character_sprite.texture
	ghost.global_position = character_sprite.global_position
	ghost.global_rotation = character_sprite.global_rotation
	ghost.flip_h = character_sprite.flip_h
	ghost.scale = character_sprite.global_scale
	ghost.offset = character_sprite.offset
	ghost.z_index = character_sprite.z_index - 1
	ghost.modulate = trail_color
	get_tree().current_scene.add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ghost.queue_free)

func _get_allowed_jump_count() -> int:
	return max_jumps + power_manager.blue_extra_jump_count()

func _handle_power_cast() -> void:
	if Input.is_action_just_pressed("power_primary") and attack_timer <= 0.0:
		attack_timer = attack_cooldown * power_manager.green_cooldown_multiplier() * power_manager.orange_attack_cooldown_multiplier()
		_play_attack_animation()
		sfx_attack.play()
		_fire_green_bolt()
	if Input.is_action_just_pressed("power_secondary"):
		_use_secondary_power()

func _attack_nearby_enemies() -> void:
	var attack_power_id := _get_attack_power_id()
	var attack_multiplier := power_manager.black_corruption_attack_bonus()
	attack_multiplier *= GameState.get_dev_damage_multiplier()
	for body in interact_area.get_overlapping_bodies():
		if body.has_method("apply_hit") and global_position.distance_to(body.global_position) <= attack_range:
			var killed := false
			if power_manager.black_forced_one_heart():
				killed = body.apply_hit(attack_power_id, true)
			else:
				var attack_hits := maxi(1, int(round(attack_multiplier)))
				for _i in range(attack_hits):
					killed = body.apply_hit(attack_power_id) or killed
			if killed:
				on_enemy_killed()

func _get_attack_power_id() -> int:
	if power_manager.has_power(POWER_IDS.RED_MIGHT):
		return POWER_IDS.RED_MIGHT
	if GameState.equipped_powers.size() > 0:
		return int(GameState.equipped_powers[0])
	return -1

## Degats vers les ennemis : vitrail Noir (x2) et multiplicateur dev test.
func _outgoing_damage_multiplier() -> float:
	return power_manager.black_corruption_attack_bonus() * GameState.get_dev_damage_multiplier()

func _break_nearby_walls() -> void:
	for body in interact_area.get_overlapping_bodies():
		if body.has_method("break_with_force") and global_position.distance_to(body.global_position) <= attack_range:
			body.break_with_force(power_manager.black_corruption_attack_bonus())

func _update_interactions() -> void:
	for area in interact_area.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact(self)

func take_damage(amount: int, source_x: float) -> void:
	if GameState.dev_infinite_health:
		return
	if invulnerability_timer > 0.0:
		return
	current_health -= amount
	invulnerability_timer = invulnerability_time
	var knockback_direction := -1.0 if source_x > global_position.x else 1.0
	velocity.x = knockback_direction * hurt_knockback
	velocity.y = jump_force * 0.4
	_play_hurt_animation()
	sfx_hurt.play()
	if current_health <= 0:
		_respawn()

func _respawn() -> void:
	GameState.register_death()
	current_health = mini(max_health, 3)
	if power_manager.black_forced_one_heart():
		current_health = 1
	global_position = spawn_position
	velocity = Vector2.ZERO
	invulnerability_timer = invulnerability_time
	respawned.emit()

func _play_attack_animation(force_left: bool = facing < 0.0) -> void:
	facing = -1.0 if force_left else 1.0
	attack_anim_timer = 0.48
	is_attacking = true
	character_sprite.modulate = Color(1.0, 0.75, 0.75, 1.0)
	var tween := create_tween()
	tween.tween_interval(0.18)
	tween.finished.connect(func() -> void:
		character_sprite.modulate = Color(1, 1, 1, 1)
	)

func _update_visuals(_delta: float) -> void:
	visual_root.scale.x = 1.0
	_update_sprite_animation(_delta)
	if invulnerability_timer > 0.0:
		character_sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)

func _play_hurt_animation() -> void:
	character_sprite.modulate = Color(1.0, 0.4, 0.4, 1.0)
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.finished.connect(func() -> void:
		character_sprite.modulate = Color(1, 1, 1, 1)
	)

func _use_secondary_power() -> void:
	if power_manager.has_power(POWER_IDS.GREEN_NATURE):
		current_health = mini(max_health, current_health + 1)

var corruption_tick := 0.0

func _apply_vitrail_passives(delta: float) -> void:
	if power_manager.has_power(POWER_IDS.BLACK_CORRUPTION):
		current_health = mini(current_health, 1)
	if has_meta("in_corruption"):
		corruption_tick += delta
		if corruption_tick >= 1.0:
			corruption_tick = 0.0
			take_damage(1, global_position.x)

func _parry_nearby_projectiles() -> void:
	for area in interact_area.get_overlapping_areas():
		if area.has_method("deflect"):
			area.deflect(facing)

func _handle_tools() -> void:
	if Input.is_action_just_pressed("sword_throw") and sword_timer <= 0.0:
		var wave_dir := _get_group_attack_direction()
		_play_attack_animation(wave_dir.x < 0.0)
		_cast_wave_arc(wave_dir)
		sword_timer = sword_cooldown * power_manager.green_cooldown_multiplier() * power_manager.orange_attack_cooldown_multiplier()
	if Input.is_action_just_pressed("grenade_throw") and grenade_timer <= 0.0:
		_throw_grenade()
		grenade_timer = grenade_cooldown * power_manager.green_cooldown_multiplier() * power_manager.orange_attack_cooldown_multiplier()

func _fire_green_bolt() -> void:
	var bolt := GREEN_BOLT_SCENE.instantiate()
	bolt.global_position = global_position + Vector2(26.0 * facing, -8.0)
	bolt.direction = facing
	bolt.owner_player = self
	bolt.damage = maxi(1, int(round(float(bolt.damage) * _outgoing_damage_multiplier())))
	get_parent().add_child(bolt)
	if power_manager.has_power(POWER_IDS.ORANGE_MOBILITY):
		var bolt_back := GREEN_BOLT_SCENE.instantiate()
		bolt_back.global_position = global_position + Vector2(-26.0 * facing, -8.0)
		bolt_back.direction = -facing
		bolt_back.owner_player = self
		bolt_back.damage = bolt.damage
		get_parent().add_child(bolt_back)
	sfx_sword_throw.pitch_scale = 1.2
	sfx_sword_throw.play()

func _cast_wave_arc(aim_dir: Vector2) -> void:
	var use_dir := aim_dir.normalized()
	if use_dir.length() <= 0.01:
		use_dir = Vector2(facing, 0.0)
	var wave := WAVE_ARC_SCENE.instantiate()
	wave.global_position = global_position + Vector2(36.0 * use_dir.x, -6.0 + 18.0 * use_dir.y)
	wave.direction = use_dir
	wave.owner_player = self
	wave.damage = maxi(1, int(round(float(wave.damage) * _outgoing_damage_multiplier())))
	get_parent().add_child(wave)
	if power_manager.has_power(POWER_IDS.ORANGE_MOBILITY):
		var wave_back := WAVE_ARC_SCENE.instantiate()
		wave_back.global_position = global_position + Vector2(-36.0 * use_dir.x, -6.0 - 18.0 * use_dir.y)
		wave_back.direction = -use_dir
		wave_back.owner_player = self
		wave_back.damage = wave.damage
		get_parent().add_child(wave_back)
	sfx_sword_throw.pitch_scale = 0.9
	sfx_sword_throw.play()

func _get_group_attack_direction() -> Vector2:
	var left := Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var up := Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP)
	if up and left and right:
		return Vector2.UP
	if up and left:
		return Vector2(-1.0, -1.0).normalized()
	if up and right:
		return Vector2(1.0, -1.0).normalized()
	if up:
		return Vector2.UP
	if left and not right:
		return Vector2.LEFT
	if right and not left:
		return Vector2.RIGHT
	return Vector2(facing, 0.0)

func _throw_grenade() -> void:
	var grenade := GRENADE_SCENE.instantiate()
	grenade.global_position = global_position + Vector2(20.0 * facing, -6.0)
	grenade.direction = facing
	grenade.owner_player = self
	grenade.self_damage = grenade_self_damage
	grenade.damage = maxi(1, int(round(float(grenade.damage) * _outgoing_damage_multiplier())))
	get_parent().add_child(grenade)
	if power_manager.has_power(POWER_IDS.ORANGE_MOBILITY):
		var grenade_back := GRENADE_SCENE.instantiate()
		grenade_back.global_position = global_position + Vector2(-20.0 * facing, -6.0)
		grenade_back.direction = -facing
		grenade_back.owner_player = self
		grenade_back.self_damage = grenade_self_damage
		grenade_back.damage = grenade.damage
		get_parent().add_child(grenade_back)
	sfx_grenade_throw.play()

func _strike_nearest_enemy() -> void:
	var nearest: Node2D
	var nearest_dist := 999999.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var d := global_position.distance_to(enemy.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = enemy
	if nearest != null and nearest.has_method("apply_hit"):
		sfx_lightning.play()
		var hit_count := maxi(1, int(round(GameState.get_dev_damage_multiplier())))
		var killed := false
		for _i in range(hit_count):
			killed = nearest.apply_hit(POWER_IDS.YELLOW_TIME) or killed
		if killed:
			on_enemy_killed()

func heal(amount: int) -> void:
	current_health = mini(max_health, current_health + amount)

func on_enemy_killed() -> void:
	sfx_kill.play()
	GameState.register_enemy_kill()
	var threshold := power_manager.white_heal_kill_threshold()
	if threshold > 0:
		white_kill_counter += 1
		if white_kill_counter >= threshold:
			white_kill_counter = 0
			current_health = mini(3, current_health + 1)
	else:
		white_kill_counter = 0

func _try_yellow_stomp() -> void:
	if not power_manager.yellow_stomp_enabled():
		return
	if stomp_cooldown_timer > 0.0 or velocity.y <= 0.0:
		return
	for body in interact_area.get_overlapping_bodies():
		if not body.has_method("apply_hit"):
			continue
		if not (body is Node2D):
			continue
		var enemy := body as Node2D
		if enemy == null:
			continue
		var vertical_gap := enemy.global_position.y - global_position.y
		if vertical_gap < 18.0 or vertical_gap > 52.0:
			continue
		if absf(global_position.x - enemy.global_position.x) > 36.0:
			continue
		var killed := false
		for _i in range(3):
			killed = body.apply_hit(POWER_IDS.YELLOW_TIME) or killed
		if killed:
			on_enemy_killed()
		_spawn_stomp_explosion(enemy.global_position + Vector2(0, -10))
		velocity.y = jump_force * 0.55
		stomp_cooldown_timer = 2.0
		break

func _spawn_stomp_explosion(at_position: Vector2) -> void:
	var blast := ColorRect.new()
	blast.color = Color(1.0, 0.15, 0.15, 0.85)
	blast.size = Vector2(18, 18)
	blast.pivot_offset = blast.size * 0.5
	blast.global_position = at_position - blast.size * 0.5
	blast.z_index = 120
	get_tree().current_scene.add_child(blast)
	var tween := blast.create_tween()
	tween.parallel().tween_property(blast, "scale", Vector2(3.2, 3.2), 0.16)
	tween.parallel().tween_property(blast, "modulate:a", 0.0, 0.16)
	tween.tween_callback(blast.queue_free)

func _update_sprite_animation(delta: float) -> void:
	var key := _pick_animation_key()
	if key != current_anim_key:
		current_anim_key = key
		anim_time = 0.0
	var frames: Array = animation_frames.get(current_anim_key, [])
	if frames.is_empty():
		return
	var fps := float(animation_fps.get(current_anim_key, 8.0))
	anim_time += delta
	var idx := int(floor(anim_time * fps)) % frames.size()
	var tex: Texture2D = frames[idx]
	character_sprite.flip_h = _should_flip_animation(current_anim_key)
	if tex != null:
		character_sprite.texture = tex
	if current_anim_key == "shot_right":
		character_sprite.offset = Vector2(19.0, -16.0)
	elif current_anim_key == "shot_left":
		character_sprite.offset = Vector2(-19.0, -16.0)
	else:
		character_sprite.offset = Vector2.ZERO

func _pick_animation_key() -> String:
	if attack_anim_timer > 0.0:
		if facing < 0.0 and (animation_frames["shot_left"] as Array).size() > 0:
			return "shot_left"
		if (animation_frames["shot_right"] as Array).size() > 0:
			return "shot_right"
	if not is_on_floor():
		if facing < 0.0 and (animation_frames["jump_left"] as Array).size() > 0:
			return "jump_left"
		if (animation_frames["jump_right"] as Array).size() > 0:
			return "jump_right"
	if absf(velocity.x) > 8.0:
		if facing < 0.0 and (animation_frames["walk_left"] as Array).size() > 0:
			return "walk_left"
		if (animation_frames["walk_right"] as Array).size() > 0:
			return "walk_right"
	return "idle"

func _load_character_animation_folders() -> void:
	_load_known_animation_sets()
	var anim_dir := DirAccess.open("res://animation")
	if anim_dir == null:
		return
	var dirs := DirAccess.get_directories_at("res://animation")
	for d in dirs:
		var lower := d.to_lower()
		var key := ""
		if lower.contains("wait"):
			key = "idle"
		elif lower.contains("wald_right") or lower.contains("walk_right"):
			key = "walk_right"
		elif lower.contains("walk_left"):
			key = "walk_left"
		elif lower.contains("jump_right"):
			key = "jump_right"
		elif lower.contains("jump_left"):
			key = "jump_left"
		elif lower.contains("shot_left"):
			key = "shot_left"
		elif lower.contains("shot_right") or lower.contains("shot"):
			key = "shot_right"
		if key == "":
			continue
		var files: Array = Array(DirAccess.get_files_at("res://animation/%s" % d))
		files.sort_custom(_frame_name_sort)
		var frames: Array[Texture2D] = []
		for f: String in files:
			var lf: String = f.to_lower()
			if not (lf.ends_with(".png") or lf.ends_with(".webp")):
				continue
			var p := "res://animation/%s/%s" % [d, f]
			if not ResourceLoader.exists(p):
				continue
			var tex := load(p)
			if tex is Texture2D:
				frames.append(tex)
		if not frames.is_empty():
			animation_frames[key] = frames
	# fallback miroir gauche si absent
	if (animation_frames["walk_left"] as Array).is_empty() and (animation_frames["walk_right"] as Array).size() > 0:
		animation_frames["walk_left"] = animation_frames["walk_right"]
	if (animation_frames["jump_left"] as Array).is_empty() and (animation_frames["jump_right"] as Array).size() > 0:
		animation_frames["jump_left"] = animation_frames["jump_right"]
	if (animation_frames["shot_left"] as Array).is_empty() and (animation_frames["shot_right"] as Array).size() > 0:
		animation_frames["shot_left"] = animation_frames["shot_right"]
	if (animation_frames["idle"] as Array).size() > 0:
		character_sprite.texture = (animation_frames["idle"] as Array)[0]
	_finalize_animation_offsets()

func _load_known_animation_sets() -> void:
	_apply_animation_paths("idle", IDLE_PATHS)
	_apply_animation_paths("walk_right", WALK_RIGHT_PATHS)
	_apply_animation_paths("walk_left", WALK_LEFT_PATHS)
	_apply_animation_paths("jump_right", JUMP_RIGHT_PATHS)
	_apply_animation_paths("jump_left", JUMP_LEFT_PATHS)
	_apply_animation_paths("shot_right", SHOT_RIGHT_PATHS)
	_apply_animation_paths("shot_left", SHOT_LEFT_PATHS)

func _apply_animation_paths(key: String, paths: Array) -> void:
	var frames: Array[Texture2D] = []
	for p: String in paths:
		if not ResourceLoader.exists(p):
			continue
		var tex := load(p)
		if tex is Texture2D:
			frames.append(tex)
	if not frames.is_empty():
		animation_frames[key] = frames

func _finalize_animation_offsets() -> void:
	var reference := Vector2.ZERO
	var idle_frames: Array = animation_frames.get("idle", [])
	if not idle_frames.is_empty():
		reference = _compute_anchor(idle_frames[0])
	else:
		for key in animation_frames.keys():
			var frames: Array = animation_frames[key]
			if not frames.is_empty():
				reference = _compute_anchor(frames[0])
				break
	for key in animation_frames.keys():
		var frames: Array = animation_frames[key]
		var offsets: Array[Vector2] = []
		for tex: Texture2D in frames:
			var anchor := _compute_anchor(tex)
			offsets.append(reference - anchor)
		animation_offsets[key] = offsets

func _compute_anchor(tex: Texture2D) -> Vector2:
	if tex == null:
		return Vector2.ZERO
	var img := tex.get_image()
	if img == null or img.is_empty():
		return Vector2(tex.get_width() * 0.5, tex.get_height())
	var width := img.get_width()
	var height := img.get_height()
	var min_x := width
	var max_x := -1
	var max_y := -1
	var band_start := int(height * 0.65)
	var band_sum_x := 0.0
	var band_count := 0
	for y in range(height):
		for x in range(width):
			if img.get_pixel(x, y).a <= 0.05:
				continue
			min_x = mini(min_x, x)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
			if y >= band_start:
				band_sum_x += float(x)
				band_count += 1
	if max_x < 0 or max_y < 0:
		return Vector2(tex.get_width() * 0.5, tex.get_height())
	var anchor_x := (band_sum_x / float(band_count)) if band_count > 0 else (float(min_x + max_x) * 0.5)
	return Vector2(anchor_x, float(max_y))

static func _frame_name_sort(a: String, b: String) -> bool:
	return _extract_frame_index(a) < _extract_frame_index(b)

static func _extract_frame_index(name: String) -> int:
	var base := name.get_basename()
	var tokens := base.split("_", false)
	if tokens.is_empty():
		return 0
	var last := tokens[tokens.size() - 1]
	if last.is_valid_int():
		return int(last)
	return 0

func _should_flip_animation(anim_key: String) -> bool:
	if anim_key == "idle":
		return facing < 0.0
	if not anim_key.ends_with("_left"):
		return false
	if anim_key == "walk_left":
		return (animation_frames["walk_left"] as Array) == (animation_frames["walk_right"] as Array)
	if anim_key == "jump_left":
		return (animation_frames["jump_left"] as Array) == (animation_frames["jump_right"] as Array)
	if anim_key == "shot_left":
		return (animation_frames["shot_left"] as Array) == (animation_frames["shot_right"] as Array)
	return false
