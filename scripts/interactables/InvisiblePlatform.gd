extends StaticBody2D

@onready var visual: ColorRect = $Visual
var shimmer_time := 0.0

func _ready() -> void:
	_build_platform_fx()

func _process(delta: float) -> void:
	shimmer_time += delta
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		visual.visible = false
		return

	var power_manager: PowerManager = player.get_node("PowerManager")
	var revealed := power_manager.blue_reveals_hidden()
	visual.visible = revealed
	if revealed:
		visual.color = Color(0.3, 0.72 + 0.12 * sin(shimmer_time * 4.0), 1.0, 0.5 + 0.2 * absf(sin(shimmer_time * 3.0)))

func _build_platform_fx() -> void:
	var edge := ColorRect.new()
	edge.name = "Edge"
	edge.offset_left = -60.0
	edge.offset_right = 60.0
	edge.offset_top = -9.0
	edge.offset_bottom = -5.0
	edge.color = Color(0.8, 0.95, 1.0, 0.7)
	add_child(edge)

	var glow := ColorRect.new()
	glow.name = "Glow"
	glow.offset_left = -58.0
	glow.offset_right = 58.0
	glow.offset_top = -2.0
	glow.offset_bottom = 10.0
	glow.color = Color(0.35, 0.7, 1.0, 0.25)
	add_child(glow)
