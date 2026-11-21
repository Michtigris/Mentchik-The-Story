extends Area2D

const AudioSynth = preload("res://scripts/audio/AudioSynth.gd")

@export var speed := 260.0
@export var max_range := 360.0
@export var blast_radius := 96.0
@export var damage := 3
var direction := 1.0
var owner_player: Node2D
var self_damage := 2
var traveled := 0.0
var exploded := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if exploded:
		return
	var step := speed * delta
	global_position.x += direction * step
	traveled += step
	if traveled >= max_range:
		_explode()

func _on_body_entered(body: Node) -> void:
	if exploded:
		return
	if body == owner_player:
		return
	_explode()

func _explode() -> void:
	exploded = true
	_play_explosion_sound()
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node2D and node.has_method("apply_hit"):
			if node.global_position.distance_to(global_position) <= blast_radius:
				var killed := false
				for _i in range(maxi(1, damage)):
					killed = node.apply_hit(-1) or killed
				if killed and owner_player != null and owner_player.has_method("on_enemy_killed"):
					owner_player.on_enemy_killed()
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node2D and node.has_method("take_damage"):
			if node.global_position.distance_to(global_position) <= blast_radius:
				node.take_damage(self_damage, global_position.x)
	var timer := get_tree().create_timer(0.5)
	timer.timeout.connect(queue_free)

func _play_explosion_sound() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = AudioSynth.make_explosion_sfx()
	sfx.volume_db = -4.0
	get_tree().root.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
