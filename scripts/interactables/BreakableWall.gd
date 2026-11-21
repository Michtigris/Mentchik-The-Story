extends StaticBody2D

@export var required_force := 1.2
@onready var visual: ColorRect = $Visual
var crack_lines: Array[Line2D] = []
var time_accum := 0.0

func _ready() -> void:
	_build_wall_details()

func _process(delta: float) -> void:
	time_accum += delta
	visual.color = Color(0.4 + 0.03 * sin(time_accum * 1.8), 0.34, 0.28, 1.0)
	for i in range(crack_lines.size()):
		crack_lines[i].default_color.a = 0.25 + 0.2 * absf(sin(time_accum * 2.5 + i))

func break_with_force(force_strength: float) -> void:
	if force_strength >= required_force:
		queue_free()

func _build_wall_details() -> void:
	for i in range(4):
		var crack := Line2D.new()
		crack.width = 2.0
		crack.default_color = Color(0.14, 0.09, 0.08, 0.35)
		var offset := -14.0 + i * 8.0
		crack.points = PackedVector2Array([
			Vector2(-20 + i * 6, -18),
			Vector2(-8 + i * 4, -6 + offset * 0.1),
			Vector2(6 + i * 2, 4 - offset * 0.1),
			Vector2(18 - i * 3, 18)
		])
		add_child(crack)
		crack_lines.append(crack)
