extends CharacterBody2D

signal boss_defeated

const BOZ_FRAMES := [
	"res://animation/BOZ/eyes1.webp",
	"res://animation/BOZ/eyes2.webp",
	"res://animation/BOZ/eyes3.webp",
	"res://animation/BOZ/eyes4.webp",
	"res://animation/BOZ/eyes5.webp",
	"res://animation/BOZ/eyes6.webp",
	"res://animation/BOZ/eyes7.webp",
	"res://animation/BOZ/eyes8.webp",
	"res://animation/BOZ/eyes9.webp",
	"res://animation/BOZ/eyes10.webp",
	"res://animation/BOZ/eyes11.webp",
	"res://animation/BOZ/eyes12.webp",
	"res://animation/BOZ/eyes13.webp",
	"res://animation/BOZ/eyes14.webp"
]

@export var health := 30
@export var move_speed := 190.0
@export var stop_interval := 2.1
@export var stop_duration := 0.55
@export var laser_duration := 0.45
@export var laser_warning_duration := 0.12
@export var laser_damage := 2
@export var aimed_ray_damage := 1
@export var aimed_ray_speed := 260.0
@export var aimed_ray_max_distance := 650.0
@export var aimed_ray_length := 220.0

@onready var sprite: Sprite2D = $VisualRoot/BossSprite
@onready var laser_node: Area2D = $Laser
@onready var laser_shape: CollisionShape2D = $Laser/CollisionShape2D
@onready var laser_visual: ColorRect = $Laser/LaserVisual
@onready var aimed_ray_node: Area2D = $AimedRay
@onready var aimed_ray_shape: CollisionShape2D = $AimedRay/CollisionShape2D
@onready var aimed_ray_visual: ColorRect = $AimedRay/RayVisual
@onready var aimed_ray_core_visual: ColorRect = $AimedRay/RayVisual/Core
@onready var on_screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var player_ref: Node2D
var frames: Array[Texture2D] = []
var anim_time := 0.0
var base_x := 0.0
var min_y := 200.0
var max_y := 500.0
var moving_down := true
var stop_timer := 0.0
var stop_cooldown := 1.8
var laser_timer := 0.0
var laser_active := false
var laser_hit_this_burst := false
var aimed_ray_active := false
var aimed_ray_direction := Vector2.ZERO
var aimed_ray_traveled := 0.0
var aimed_ray_hit_this_burst := false
var next_attack_is_laser := true
var hit_flash_timer := 0.0
var laser_warning_visual: ColorRect
var laser_warmup_active := false

func _ready() -> void:
	add_to_group("enemy")
	base_x = global_position.x
	min_y = global_position.y - 120.0
	max_y = global_position.y + 120.0
	_load_frames()
	laser_node.body_entered.connect(_on_laser_body_entered)
	laser_node.monitoring = false
	laser_visual.visible = false
	_ensure_laser_warning_visual()
	aimed_ray_node.top_level = true
	_configure_aimed_ray_geometry()
	aimed_ray_node.body_entered.connect(_on_aimed_ray_body_entered)
	aimed_ray_node.monitoring = false
	aimed_ray_visual.visible = false

func _physics_process(delta: float) -> void:
	if player_ref == null or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player") as Node2D
	anim_time += delta
	hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
	if hit_flash_timer > 0.0:
		sprite.modulate = Color(1.0, 0.25, 0.25, 1.0)
	else:
		sprite.modulate = Color(1, 1, 1, 1)
	_update_sprite_animation()
	if laser_active:
		laser_timer -= delta
		if laser_timer <= 0.0:
			_set_laser_active(false)
	if aimed_ray_active:
		_update_aimed_ray(delta)
	if stop_timer > 0.0:
		stop_timer -= delta
		if stop_timer <= 0.0:
			_perform_next_attack()
		return
	stop_cooldown -= delta
	if stop_cooldown <= 0.0:
		stop_timer = stop_duration
		stop_cooldown = stop_interval
		return
	_move_pattern(delta)

func apply_hit(_power_id: int, force_kill: bool = false) -> bool:
	hit_flash_timer = 0.3
	if force_kill:
		health = 0
	else:
		health -= 1
	if health <= 0:
		boss_defeated.emit()
		queue_free()
		return true
	return false

func _load_frames() -> void:
	for p in BOZ_FRAMES:
		if not ResourceLoader.exists(p):
			continue
		var tex := load(p)
		if tex is Texture2D:
			frames.append(tex)
	if not frames.is_empty():
		sprite.texture = frames[0]

func _update_sprite_animation() -> void:
	if frames.is_empty():
		return
	var idx := int(floor(anim_time * 10.0)) % frames.size()
	sprite.texture = frames[idx]

func _move_pattern(delta: float) -> void:
	global_position.x = base_x
	var dir := 1.0 if moving_down else -1.0
	global_position.y += move_speed * dir * delta
	if global_position.y >= max_y:
		global_position.y = max_y
		moving_down = false
	elif global_position.y <= min_y:
		global_position.y = min_y
		moving_down = true

func _fire_laser() -> void:
	if laser_active or laser_warmup_active:
		return
	laser_warmup_active = true
	await _play_laser_warning()
	if not is_inside_tree():
		return
	laser_warmup_active = false
	_set_laser_active(true)
	laser_timer = laser_duration
	laser_hit_this_burst = false
	next_attack_is_laser = false

func _ensure_laser_warning_visual() -> void:
	laser_warning_visual = ColorRect.new()
	laser_warning_visual.name = "LaserWarningVisual"
	laser_warning_visual.visible = false
	laser_warning_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	laser_warning_visual.offset_left = -5000.0
	laser_warning_visual.offset_top = -2.0
	laser_warning_visual.offset_right = 0.0
	laser_warning_visual.offset_bottom = 2.0
	laser_warning_visual.color = Color(1.0, 0.1, 0.1, 0.95)
	laser_node.add_child(laser_warning_visual)

func _play_laser_warning() -> void:
	if laser_warning_visual == null:
		return
	laser_warning_visual.visible = true
	await get_tree().create_timer(laser_warning_duration).timeout
	if laser_warning_visual != null:
		laser_warning_visual.visible = false

func _configure_aimed_ray_geometry() -> void:
	var ray_shape := aimed_ray_shape.shape as RectangleShape2D
	if ray_shape != null:
		ray_shape.size = Vector2(aimed_ray_length, ray_shape.size.y)
	aimed_ray_shape.position.x = aimed_ray_length * 0.5
	aimed_ray_visual.offset_left = 0.0
	aimed_ray_visual.offset_right = aimed_ray_length
	aimed_ray_core_visual.offset_left = 0.0
	aimed_ray_core_visual.offset_right = aimed_ray_length

func _fire_aimed_ray() -> void:
	if player_ref == null:
		_fire_laser()
		return
	var dir := (player_ref.global_position - global_position).normalized()
	if dir.length() <= 0.01:
		dir = Vector2(-1.0, 0.0)
	aimed_ray_direction = dir
	aimed_ray_traveled = 0.0
	aimed_ray_hit_this_burst = false
	aimed_ray_active = true
	aimed_ray_node.global_position = global_position
	aimed_ray_node.rotation = dir.angle()
	aimed_ray_node.monitoring = true
	aimed_ray_visual.visible = true
	next_attack_is_laser = true

func _perform_next_attack() -> void:
	if next_attack_is_laser:
		_fire_laser()
		return
	if _can_fire_aimed_ray():
		_fire_aimed_ray()
	else:
		_fire_laser()

func _can_fire_aimed_ray() -> bool:
	return on_screen_notifier != null and on_screen_notifier.is_on_screen()

func _set_laser_active(active: bool) -> void:
	laser_active = active
	laser_node.monitoring = active
	laser_visual.visible = active

func _on_laser_body_entered(body: Node) -> void:
	if not laser_active or laser_hit_this_burst:
		return
	if body == null or not body.has_method("take_damage"):
		return
	body.take_damage(laser_damage, global_position.x)
	laser_hit_this_burst = true

func _update_aimed_ray(delta: float) -> void:
	if not aimed_ray_active:
		return
	var step := aimed_ray_speed * delta
	aimed_ray_node.global_position += aimed_ray_direction * step
	aimed_ray_traveled += step
	if aimed_ray_traveled >= aimed_ray_max_distance:
		_stop_aimed_ray()

func _stop_aimed_ray() -> void:
	aimed_ray_active = false
	aimed_ray_node.monitoring = false
	aimed_ray_visual.visible = false

func _on_aimed_ray_body_entered(body: Node) -> void:
	if not aimed_ray_active or aimed_ray_hit_this_burst:
		return
	if body == null or not body.has_method("take_damage"):
		return
	body.take_damage(aimed_ray_damage, global_position.x)
	aimed_ray_hit_this_burst = true
	_stop_aimed_ray()
