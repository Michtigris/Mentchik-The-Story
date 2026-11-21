extends Area2D

@export var fragment_name := "Eclat principal"
@onready var visual: Polygon2D = $Visual
var glow_nodes: Array[Polygon2D] = []
var time_accum := 0.0

func _ready() -> void:
	for i in range(3):
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -6),
			Vector2(4, 0),
			Vector2(0, 6),
			Vector2(-4, 0)
		])
		shard.color = Color(0.5, 0.85, 1.0, 0.65)
		add_child(shard)
		glow_nodes.append(shard)

func _process(delta: float) -> void:
	time_accum += delta
	visual.rotation = time_accum * 1.8
	visual.scale = Vector2.ONE * (1.0 + 0.1 * sin(time_accum * 3.2))
	for i in range(glow_nodes.size()):
		var angle := time_accum * 1.7 + i * TAU / glow_nodes.size()
		glow_nodes[i].position = Vector2(cos(angle), sin(angle)) * 22.0
		glow_nodes[i].rotation = -time_accum * 2.2
		glow_nodes[i].color.a = 0.35 + 0.3 * absf(sin(time_accum * 2.5 + i))

func interact(player: Node) -> void:
	var level := player.get_parent()
	if level != null and level.has_method("on_fragment_collected"):
		level.on_fragment_collected(fragment_name)
	queue_free()
