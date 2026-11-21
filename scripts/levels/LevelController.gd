extends Node2D

signal request_next_level(next_level_id: String)
const UIThemeBuilder = preload("res://scripts/ui/UITheme.gd")
const AudioSynth = preload("res://scripts/audio/AudioSynth.gd")

@onready var hint_label: Label = $UILayer/Hint
@onready var hud_panel: Panel = $UILayer/HudPanel
@onready var hp_text_label: Label = $UILayer/HudPanel/HudMargin/HudVBox/HpText
@onready var hp_bar_fill: ColorRect = $UILayer/HudPanel/HudMargin/HudVBox/HpBarBg/HpBarFill
@onready var progress_text_label: Label = $UILayer/HudPanel/HudMargin/HudVBox/ProgressText
@onready var owned_list_label: Label = $UILayer/OwnedPanel/OwnedMargin/OwnedVBox/OwnedList
@onready var victory_panel: Panel = $UILayer/VictoryPanel
@onready var victory_title_label: Label = $UILayer/VictoryPanel/VBox/Title
@onready var victory_label: Label = $UILayer/VictoryPanel/VBox/VictoryText

var player_ref: Node2D
var time_accum := 0.0
var level_index := 1
var level_id := "niveau_1"
var level_completed := false
var transition_timer := 0.0
var pending_next_level_id := ""
var frozen_nodes: Array[Node] = []
var ui_theme: Theme
var intro_timer := 0.0
var level_number_label: Label

var ranged_enemy_scene := preload("res://scenes/enemies/RangedEnemy.tscn")
var ranged_kiter_scene := preload("res://scenes/enemies/RangedEnemyKiter.tscn")
var jumper_enemy_scene := preload("res://scenes/enemies/JumperEnemy.tscn")
var shadow_enemy_scene := preload("res://scenes/enemies/ShadowEnemy.tscn")
var breakable_wall_scene := preload("res://scenes/interactables/BreakableWall.tscn")
var fragment_scene := preload("res://scenes/interactables/FragmentPickup.tscn")
var boss_boz_scene := preload("res://scenes/enemies/BossBOZ.tscn")

const BACK_TEXTURE = preload("res://img/back.png")
const GROUND_TEXTURE = preload("res://img/sol.png")
const LEVEL_LENGTH := 5000.0
const BG_PARALLAX_Y_OFFSET := -103.0
## Echelle des tuiles sol.png (plus grand que viewport/3).
const GROUND_SPRITE_VIEWPORT_FRACTION := 0.44
var bg_sprites: Array[Sprite2D] = []
var ground_sprites: Array[Sprite2D] = []
var bg_layer: Node2D
var ground_layer: Node2D
var bg_tile_width := 0.0
var ground_tile_width := 0.0
var bg_built := false
var camera_ref: Camera2D
var locked_camera_y := 0.0
var viewport_half_y := 360.0
var parallax_anchor_ready := false
var parallax_anchor_screen := Vector2.ZERO
var parallax_anchor_layer := Vector2.ZERO
var enemy_spawn_defs: Array[Dictionary] = []
var danger_vignette: ColorRect
var vignette_top: ColorRect
var vignette_bottom: ColorRect
var vignette_left: ColorRect
var vignette_right: ColorRect
var bridge_nodes: Array[CanvasItem] = []
var enemy_upgrade_stacks := {
	"health": 0,
	"move_speed": 0,
	"attack_speed": 0,
	"extra_projectile": 0,
	"double_shot": 0
}
var owned_shard_texture: Texture2D
var owned_shard_container: HFlowContainer
var power_shard_colors := {
	GameState.POWER_IDS.BLUE_VISION: Color(0.45, 0.75, 1.0, 1.0),
	GameState.POWER_IDS.RED_MIGHT: Color(1.0, 0.35, 0.35, 1.0),
	GameState.POWER_IDS.ORANGE_MOBILITY: Color(1.0, 0.62, 0.24, 1.0),
	GameState.POWER_IDS.GREEN_NATURE: Color(0.38, 0.95, 0.45, 1.0),
	GameState.POWER_IDS.YELLOW_TIME: Color(1.0, 0.9, 0.35, 1.0),
	GameState.POWER_IDS.VIOLET_SHADOW: Color(0.75, 0.5, 1.0, 1.0),
	GameState.POWER_IDS.WHITE_LIGHT: Color(1.0, 1.0, 1.0, 1.0),
	GameState.POWER_IDS.BLACK_CORRUPTION: Color(0.45, 0.45, 0.55, 1.0)
}
var heart_texture: Texture2D
var heart_icons: Array[TextureRect] = []
var heart_row: HBoxContainer
var final_boss_spawned := false
var final_boss_defeated := false
var final_fragment_spawned := false
var death_message_timer := 0.0

var power_names := {
	GameState.POWER_IDS.BLUE_VISION: "Bleu",
	GameState.POWER_IDS.RED_MIGHT: "Rouge",
	GameState.POWER_IDS.GREEN_NATURE: "Vert",
	GameState.POWER_IDS.YELLOW_TIME: "Jaune",
	GameState.POWER_IDS.VIOLET_SHADOW: "Violet",
	GameState.POWER_IDS.WHITE_LIGHT: "Blanc",
	GameState.POWER_IDS.BLACK_CORRUPTION: "Noir",
	GameState.POWER_IDS.ORANGE_MOBILITY: "Orange"
}

var level_names := {
	1: "La Vieille Ville",
	2: "Les Remparts",
	3: "Les Catacombes",
	4: "Le Cloitre",
	5: "Les Combles",
	6: "Le Labyrinthe",
	7: "Le Sanctuaire",
	8: "La Fleche"
}

func _ready() -> void:
	victory_panel.visible = false
	hud_panel.visible = true
	ui_theme = UIThemeBuilder.build_theme()
	var transparent_hud_style := UIThemeBuilder.build_hud_panel_style()
	transparent_hud_style.bg_color = Color(0, 0, 0, 0)
	transparent_hud_style.border_color = Color(0, 0, 0, 0)
	transparent_hud_style.shadow_color = Color(0, 0, 0, 0)
	transparent_hud_style.border_width_left = 0
	transparent_hud_style.border_width_top = 0
	transparent_hud_style.border_width_right = 0
	transparent_hud_style.border_width_bottom = 0
	hud_panel.add_theme_stylebox_override("panel", transparent_hud_style)
	hud_panel.theme = ui_theme
	$UILayer/OwnedPanel.add_theme_stylebox_override("panel", transparent_hud_style)
	$UILayer/OwnedPanel.theme = ui_theme
	victory_panel.add_theme_stylebox_override("panel", UIThemeBuilder.build_victory_panel_style())
	victory_panel.theme = ui_theme
	GameState.powers_changed.connect(_update_owned_vitraux)
	GameState.progression_changed.connect(_update_owned_vitraux)
	_setup_owned_shard_ui()
	if has_node("UILayer/OwnedPanel/OwnedMargin/OwnedVBox/OwnedTitle"):
		$UILayer/OwnedPanel/OwnedMargin/OwnedVBox/OwnedTitle.visible = false
	_update_owned_vitraux()
	_prepare_bg_layers()
	_prepare_danger_overlays()
	_setup_heart_hud()
	if has_node("UILayer/HudPanel/HudMargin/HudVBox/HpBarBg"):
		$UILayer/HudPanel/HudMargin/HudVBox/HpBarBg.visible = false
	progress_text_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	if has_node("Ground/GroundVisual"):
		$Ground/GroundVisual.visible = false

func setup_for_player(player: Node2D, requested_level_index: int = 1) -> void:
	player_ref = player
	level_index = clampi(requested_level_index, 1, GameState.MAX_LEVEL)
	level_id = "niveau_%d" % level_index
	ground_sprites.clear()
	bg_sprites.clear()
	enemy_spawn_defs.clear()
	bridge_nodes.clear()
	final_boss_spawned = false
	final_boss_defeated = false
	final_fragment_spawned = false
	enemy_upgrade_stacks = _compute_enemy_upgrade_stacks(level_index)

	if not player.has_node("Camera2D"):
		return
	var camera: Camera2D = player.get_node("Camera2D")
	camera_ref = camera
	camera.enabled = true
	camera.limit_left = -120
	camera.limit_top = 0
	camera.limit_right = 5200
	camera.limit_bottom = 720
	locked_camera_y = camera.global_position.y
	parallax_anchor_ready = false

	_build_bg_tiles()
	_apply_level_visual_intensity()
	_build_fixed_level_layout()
	_show_level_intro()
	if player_ref != null and player_ref.has_signal("respawned"):
		player_ref.respawned.connect(_on_player_respawned)

func _process(delta: float) -> void:
	time_accum += delta
	if camera_ref != null:
		camera_ref.global_position.y = locked_camera_y
	_update_bg_parallax()

	if intro_timer > 0.0:
		intro_timer -= delta
		if intro_timer <= 0.0:
			hint_label.text = ""
	if death_message_timer > 0.0:
		death_message_timer -= delta
		hint_label.text = "VOUS ETES MORT !"
		hint_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))

	if level_number_label != null:
		level_number_label.modulate.a = maxf(0.0, level_number_label.modulate.a - delta * 0.15)

	if level_completed and transition_timer > 0.0:
		transition_timer -= delta
		if transition_timer <= 0.0 and pending_next_level_id != "":
			request_next_level.emit(pending_next_level_id)

	if player_ref == null or not is_instance_valid(player_ref):
		return
	var hp: int = int(player_ref.get("current_health"))
	var max_hp: int = int(player_ref.get("max_health"))
	if intro_timer <= 0.0 and death_message_timer <= 0.0:
		hint_label.text = "J attaque | K aura | H grenade | Shift dash | I vitraux | ESC retour"
		hint_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95, 0.8))
	_update_hud(hp, max_hp)

func _build_fixed_level_layout() -> void:
	var floor_top := float($Ground.global_position.y) - 40.0
	_add_boundary_wall(-100.0)
	_add_boundary_wall(LEVEL_LENGTH + 160.0)
	# Plateformes au-dessus du joueur debout (tete ~ floor_top - 62), pas au niveau pieds/tete : Y plus petit = plus haut.
	_add_platform(Vector2(420, 392), 320.0)
	_add_platform(Vector2(1350, 376), 320.0)
	_add_platform(Vector2(2450, 400), 320.0)
	_add_platform(Vector2(3500, 382), 320.0)
	_add_platform(Vector2(4550, 388), 320.0)

	_add_breakable_wall(Vector2(700, floor_top - 2.0))
	_add_breakable_wall(Vector2(2800, floor_top - 2.0))

	_register_enemy_spawn(shadow_enemy_scene, Vector2(560, floor_top + 6.0))
	_register_enemy_spawn(shadow_enemy_scene, Vector2(1520, floor_top + 6.0))
	_register_enemy_spawn(ranged_enemy_scene, Vector2(2320, floor_top + 6.0))
	_register_enemy_spawn(ranged_kiter_scene, Vector2(3720, floor_top + 6.0))
	_register_enemy_spawn(jumper_enemy_scene, Vector2(4420, floor_top + 6.0))
	_add_progressive_enemy_spawns(floor_top)
	_respawn_all_enemies()

	if level_index >= GameState.MAX_LEVEL:
		_spawn_final_boss()
	else:
		_spawn_level_fragment()

func _add_platform(pos: Vector2, width: float) -> void:
	var platform := StaticBody2D.new()
	platform.position = pos
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, 20.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	platform.add_child(collision)
	var visual := ColorRect.new()
	visual.offset_left = -width * 0.5
	visual.offset_right = width * 0.5
	visual.offset_top = -10.0
	visual.offset_bottom = 10.0
	var danger := _danger_intensity()
	var accent := _level_accent_color()
	visual.color = Color(lerpf(accent.r * 0.45, 0.8, danger), lerpf(accent.g * 0.45, 0.12, danger), lerpf(accent.b * 0.45, 0.12, danger), 0.85)
	platform.add_child(visual)
	bridge_nodes.append(visual)
	var glow := ColorRect.new()
	glow.offset_left = -width * 0.5
	glow.offset_right = width * 0.5
	glow.offset_top = -10.0
	glow.offset_bottom = -6.0
	glow.color = Color(lerpf(accent.r, 1.0, danger), lerpf(accent.g, 0.2, danger), lerpf(accent.b, 0.2, danger), lerpf(0.22, 0.45, danger))
	platform.add_child(glow)
	bridge_nodes.append(glow)
	add_child(platform)

func _add_boundary_wall(x_pos: float) -> void:
	var wall := StaticBody2D.new()
	wall.position = Vector2(x_pos, 360.0)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40.0, 1600.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	wall.add_child(collision)
	add_child(wall)

func _add_breakable_wall(pos: Vector2) -> void:
	var wall := breakable_wall_scene.instantiate()
	wall.position = pos
	add_child(wall)

func _spawn_enemy(scene: PackedScene, pos: Vector2) -> Node:
	var enemy := scene.instantiate()
	enemy.position = pos
	add_child(enemy)
	call_deferred("_scale_enemy", enemy)
	return enemy

func _scale_enemy(enemy: Node) -> void:
	if not is_instance_valid(enemy):
		return
	var hp_stack := int(enemy_upgrade_stacks.get("health", 0))
	var move_stack := int(enemy_upgrade_stacks.get("move_speed", 0))
	var attack_speed_stack := int(enemy_upgrade_stacks.get("attack_speed", 0))
	var extra_projectile_stack := int(enemy_upgrade_stacks.get("extra_projectile", 0))
	var double_shot_stack := int(enemy_upgrade_stacks.get("double_shot", 0))
	if "health" in enemy:
		enemy.health += hp_stack * 3
	if "chase_speed" in enemy:
		enemy.chase_speed *= pow(1.35, float(move_stack))
	if "speed" in enemy:
		enemy.speed *= pow(1.35, float(move_stack))
	if "vision_range" in enemy:
		enemy.vision_range += float(move_stack) * 30.0
	if "attack_cooldown" in enemy:
		enemy.attack_cooldown = maxf(0.18, float(enemy.attack_cooldown) / pow(1.5, float(attack_speed_stack)))
	if "jump_interval" in enemy:
		enemy.jump_interval = maxf(0.28, float(enemy.jump_interval) / pow(1.4, float(attack_speed_stack)))
	if "jump_force" in enemy:
		enemy.jump_force = float(enemy.jump_force) * pow(1.12, float(move_stack))
	if enemy.has_method("apply_level_scaling"):
		enemy.apply_level_scaling({
			"attack_speed_stacks": attack_speed_stack,
			"extra_projectile_stacks": extra_projectile_stack,
			"double_shot_stacks": double_shot_stack
		})

func _register_enemy_spawn(scene: PackedScene, pos: Vector2) -> void:
	enemy_spawn_defs.append({"scene": scene, "pos": pos})

func _respawn_all_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy != null and enemy.get_parent() == self:
			enemy.queue_free()
	if level_index >= GameState.MAX_LEVEL and not final_boss_defeated:
		final_boss_spawned = false
	for spawn_def in enemy_spawn_defs:
		_spawn_enemy(spawn_def["scene"], spawn_def["pos"])
	if level_index >= GameState.MAX_LEVEL and not final_boss_defeated:
		_spawn_final_boss()

func _on_player_respawned() -> void:
	_respawn_all_enemies()
	death_message_timer = 1.4

func set_combat_pause_from_ui(paused: bool) -> void:
	for player in get_tree().get_nodes_in_group("player"):
		if player != null and player.get_parent() == self:
			if player.has_method("set_physics_process"):
				player.set_physics_process(not paused)
			if player.has_method("set_process"):
				player.set_process(not paused)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy != null and enemy.get_parent() == self:
			if enemy.has_method("set_physics_process"):
				enemy.set_physics_process(not paused)
			if enemy.has_method("set_process"):
				enemy.set_process(not paused)
	for projectile in get_tree().get_nodes_in_group("enemy_projectile"):
		if projectile != null and projectile.get_parent() == self:
			if projectile.has_method("set_physics_process"):
				projectile.set_physics_process(not paused)
			if projectile.has_method("set_process"):
				projectile.set_process(not paused)

func _spawn_level_fragment() -> void:
	if final_fragment_spawned:
		return
	final_fragment_spawned = true
	var frag := fragment_scene.instantiate()
	frag.position = Vector2(4920, 365.0)
	add_child(frag)

func _spawn_final_boss() -> void:
	if final_boss_spawned:
		return
	final_boss_spawned = true
	var boss := boss_boz_scene.instantiate()
	boss.position = Vector2(4870, 320)
	add_child(boss)
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_final_boss_defeated)

func _on_final_boss_defeated() -> void:
	final_boss_defeated = true
	_spawn_level_fragment()

func _compute_enemy_upgrade_stacks(current_level: int) -> Dictionary:
	var stacks := {
		"health": 0,
		"move_speed": 0,
		"attack_speed": 0,
		"extra_projectile": 0,
		"double_shot": 0
	}
	if current_level <= 1:
		return stacks
	var keys: PackedStringArray = ["health", "move_speed", "attack_speed", "extra_projectile", "double_shot"]
	for lvl in range(2, current_level + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(4242 + lvl * 1337)
		var choice: String = keys[rng.randi_range(0, keys.size() - 1)]
		stacks[choice] = int(stacks.get(choice, 0)) + 1
	return stacks

func _show_level_intro() -> void:
	var level_name: String = level_names.get(level_index, "Niveau %d" % level_index)
	hint_label.text = "NIVEAU %d  —  %s" % [level_index, level_name]
	intro_timer = 4.0
	_create_level_number_overlay()

func _create_level_number_overlay() -> void:
	level_number_label = Label.new()
	level_number_label.text = str(level_index)
	level_number_label.add_theme_font_size_override("font_size", 320)
	level_number_label.add_theme_color_override("font_color", _level_accent_color())
	level_number_label.modulate.a = 0.35
	level_number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	level_number_label.anchors_preset = Control.PRESET_FULL_RECT
	level_number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UILayer.add_child(level_number_label)
	$UILayer.move_child(level_number_label, 0)

func _level_accent_color() -> Color:
	var colors := [
		Color(0.4, 0.7, 1.0),
		Color(0.5, 0.8, 0.4),
		Color(0.9, 0.6, 0.2),
		Color(0.7, 0.4, 0.9),
		Color(0.3, 0.9, 0.85),
		Color(0.85, 0.2, 0.3),
		Color(0.95, 0.85, 0.3),
		Color(0.9, 0.9, 0.95)
	]
	return colors[clampi(level_index - 1, 0, colors.size() - 1)]

func on_fragment_collected(fragment_name: String) -> void:
	if level_completed:
		return
	level_completed = true
	if player_ref != null and is_instance_valid(player_ref):
		GameState.register_level_completed_health(int(player_ref.get("current_health")))
	GameState.register_level_time_bonus(time_accum)
	_set_combat_frozen(true)
	victory_panel.visible = true
	_play_vitrail_reward_sound()
	var reward_data := GameState.grant_level_completion_rewards(level_id)
	var new_power_id: int = reward_data.get("new_power_id", -1)
	var reward_text := "Aucun nouveau vitrail" if new_power_id == -1 else _power_name(new_power_id)
	var reward_desc := _power_description(new_power_id)
	var auto_equipped: bool = reward_data.get("auto_equipped", false)
	var already_completed: bool = reward_data.get("already_completed", false)
	var equip_text := "Auto-equipe: OUI" if auto_equipped else "Auto-equipe: NON (I pour equiper)"
	var next_level_id: String = reward_data.get("next_level_id", "")
	var campaign_complete: bool = reward_data.get("is_campaign_complete", false)

	victory_title_label.text = "VITRAIL OBTENU"
	hud_panel.visible = false
	victory_panel.modulate.a = 0.0
	var show_tween := create_tween()
	show_tween.tween_property(victory_panel, "modulate:a", 1.0, 0.25)
	if already_completed:
		victory_title_label.text = "NIVEAU DEJA TERMINE"
		victory_label.text = "Deja complete.\nESC pour retour hub."
		pending_next_level_id = ""
		transition_timer = 0.0
		return
	if campaign_complete:
		victory_label.text = "Niveau %d termine !\nFragment: %s\nRecompense: %s\n%s\n%s\nCampagne terminee ! ESC pour hub." % [level_index, fragment_name, reward_text, reward_desc, equip_text]
		pending_next_level_id = ""
		transition_timer = 0.0
	else:
		victory_label.text = "Niveau %d termine !\nFragment: %s\nRecompense: %s\n%s\n%s\nTransition vers %s..." % [level_index, fragment_name, reward_text, reward_desc, equip_text, next_level_id]
		pending_next_level_id = next_level_id
		transition_timer = 3.2

func _update_hud(hp: int, max_hp: int) -> void:
	var shown_max := clampi(maxi(hp, max_hp), 1, 16)
	_ensure_heart_icon_count(shown_max)
	var safe_hp := clampi(hp, 0, shown_max)
	hp_text_label.text = ""
	if not heart_icons.is_empty():
		for i in range(heart_icons.size()):
			heart_icons[i].visible = i < safe_hp
	if player_ref != null:
		var progress := clampf(player_ref.global_position.x / LEVEL_LENGTH, 0.0, 1.0)
		progress_text_label.text = "Niv.%d | Progression: %d%% | Temps: %ds | Morts: %d | Score: %d" % [
			level_index,
			int(progress * 100.0),
			int(time_accum),
			GameState.total_deaths,
			GameState.total_score
		]

func _setup_heart_hud() -> void:
	heart_texture = _resolve_heart_texture()
	if heart_texture == null:
		return
	var hud_vbox := $UILayer/HudPanel/HudMargin/HudVBox
	heart_row = HBoxContainer.new()
	heart_row.name = "HeartRow"
	heart_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	heart_row.add_theme_constant_override("separation", 6)
	hud_vbox.add_child(heart_row)
	hud_vbox.move_child(heart_row, 1)
	heart_icons.clear()
	_ensure_heart_icon_count(3)

func _ensure_heart_icon_count(required_count: int) -> void:
	if heart_row == null or heart_texture == null:
		return
	required_count = clampi(required_count, 1, 16)
	while heart_icons.size() < required_count:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = heart_texture
		heart_row.add_child(icon)
		heart_icons.append(icon)
	for i in range(heart_icons.size()):
		heart_icons[i].visible = i < required_count

func _resolve_heart_texture() -> Texture2D:
	var candidates := [
		"res://img/coeur.png",
		"res://img/heart.png",
		"res://img/coeur_full.png",
		"res://img/heart_full.png"
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			var t := load(p)
			if t is Texture2D:
				return t
	var files := DirAccess.get_files_at("res://img")
	for f in files:
		var lower := f.to_lower()
		if not lower.ends_with(".png"):
			continue
		if lower.contains("coeur") or lower.contains("heart"):
			var path := "res://img/%s" % f
			if ResourceLoader.exists(path):
				var tex := load(path)
				if tex is Texture2D:
					return tex
	return null

func _update_owned_vitraux() -> void:
	if owned_shard_container == null:
		owned_list_label.text = ""
		return
	for child in owned_shard_container.get_children():
		child.queue_free()
	if GameState.unlocked_powers.is_empty():
		owned_list_label.visible = false
		return
	owned_list_label.visible = false
	for power_id in GameState.unlocked_powers:
		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(34, 34)
		icon.texture = owned_shard_texture
		var pid := int(power_id)
		icon.modulate = power_shard_colors.get(pid, Color(1, 1, 1, 1))
		if GameState.is_power_equipped(pid):
			icon.modulate.a = 1.0
			icon.scale = Vector2(1.18, 1.18)
		else:
			icon.modulate.a = 0.65
		owned_shard_container.add_child(icon)

func _setup_owned_shard_ui() -> void:
	if not ResourceLoader.exists("res://img/shard.png"):
		return
	owned_shard_texture = load("res://img/shard.png") as Texture2D
	if owned_shard_texture == null:
		return
	owned_shard_container = HFlowContainer.new()
	owned_shard_container.name = "OwnedShardContainer"
	owned_shard_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	owned_shard_container.alignment = FlowContainer.ALIGNMENT_END
	owned_shard_container.add_theme_constant_override("h_separation", 10)
	owned_shard_container.add_theme_constant_override("v_separation", 6)
	$UILayer/OwnedPanel/OwnedMargin/OwnedVBox.add_child(owned_shard_container)

func _set_combat_frozen(should_freeze: bool) -> void:
	if should_freeze:
		frozen_nodes.clear()
		_collect_freezable_nodes(self)
		for node in frozen_nodes:
			if node.has_method("set_physics_process"):
				node.set_physics_process(false)
			if node.has_method("set_process") and node != self:
				node.set_process(false)
		return
	for node in frozen_nodes:
		if node.has_method("set_physics_process"):
			node.set_physics_process(true)
		if node.has_method("set_process") and node != self:
			node.set_process(true)
	frozen_nodes.clear()

func _collect_freezable_nodes(root: Node) -> void:
	for child in root.get_children():
		if child is CharacterBody2D or child is Area2D:
			frozen_nodes.append(child)
		_collect_freezable_nodes(child)

func _prepare_bg_layers() -> void:
	if has_node("Background"):
		$Background.visible = false
	bg_layer = Node2D.new()
	bg_layer.name = "BgLayer"
	bg_layer.z_index = -30
	add_child(bg_layer)
	ground_layer = Node2D.new()
	ground_layer.name = "GroundLayer"
	ground_layer.z_index = -10
	add_child(ground_layer)

func _build_bg_tiles() -> void:
	if bg_built:
		return
	bg_built = true
	# Utilise la taille de viewport reelle pour garantir que le fond couvre tout l'ecran
	# (haut -> bas) quel que soit le mode fenetre/plein ecran.
	var vp_size := get_viewport_rect().size
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		vp_size = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
		)
	viewport_half_y = float(vp_size.y) * 0.5

	var tex_h := maxf(1.0, float(BACK_TEXTURE.get_height()))
	var tex_w := maxf(1.0, float(BACK_TEXTURE.get_width()))
	# +2 px d'overscan evite un filet vide en bas sur certains ratios/echelles.
	var scale_y := (float(vp_size.y) + 2.0) / tex_h
	bg_tile_width = tex_w * scale_y
	var total_w := LEVEL_LENGTH + 1200.0
	var count := int(ceil(total_w / bg_tile_width)) + 4
	for i in range(-2, count):
		var spr := Sprite2D.new()
		spr.texture = BACK_TEXTURE
		spr.scale = Vector2(scale_y, scale_y)
		spr.position.x = float(i) * bg_tile_width + bg_tile_width * 0.5
		spr.position.y = viewport_half_y + 105
		bg_layer.add_child(spr)
		bg_sprites.append(spr)

	if not has_node("Ground"):
		return
	var ground_node := $Ground
	var ground_h := float(vp_size.y) * GROUND_SPRITE_VIEWPORT_FRACTION
	var g_tex_h := maxf(1.0, float(GROUND_TEXTURE.get_height()))
	var g_tex_w := maxf(1.0, float(GROUND_TEXTURE.get_width()))
	var g_scale := ground_h / g_tex_h
	ground_tile_width = g_tex_w * g_scale
	var g_count := int(ceil(total_w / ground_tile_width)) + 4
	var ground_y := float(ground_node.global_position.y)
	var sol_y := ground_y + ground_h * 0.22 - ground_h / 3.0 + 60.0
	for i in range(-2, g_count):
		var spr := Sprite2D.new()
		spr.texture = GROUND_TEXTURE
		spr.scale = Vector2(g_scale, g_scale)
		spr.position.x = float(i) * ground_tile_width + ground_tile_width * 0.5
		spr.position.y = sol_y
		ground_layer.add_child(spr)
		ground_sprites.append(spr)

func _danger_intensity() -> float:
	return clampf(float(level_index - 1) / float(GameState.MAX_LEVEL - 1), 0.0, 1.0)

func _prepare_danger_overlays() -> void:
	danger_vignette = ColorRect.new()
	danger_vignette.name = "DangerVignette"
	danger_vignette.anchors_preset = Control.PRESET_FULL_RECT
	danger_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	danger_vignette.color = Color(0.35, 0.0, 0.0, 0.0)
	$UILayer.add_child(danger_vignette)
	$UILayer.move_child(danger_vignette, 0)

	vignette_top = ColorRect.new()
	vignette_top.anchors_preset = Control.PRESET_TOP_WIDE
	vignette_top.offset_bottom = 190.0
	vignette_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_top.color = Color(0.0, 0.0, 0.0, 0.0)
	$UILayer.add_child(vignette_top)
	$UILayer.move_child(vignette_top, 1)

	vignette_bottom = ColorRect.new()
	vignette_bottom.anchors_preset = Control.PRESET_BOTTOM_WIDE
	vignette_bottom.offset_top = -190.0
	vignette_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_bottom.color = Color(0.0, 0.0, 0.0, 0.0)
	$UILayer.add_child(vignette_bottom)
	$UILayer.move_child(vignette_bottom, 1)

	vignette_left = ColorRect.new()
	vignette_left.anchors_preset = Control.PRESET_LEFT_WIDE
	vignette_left.offset_right = 160.0
	vignette_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_left.color = Color(0.0, 0.0, 0.0, 0.0)
	$UILayer.add_child(vignette_left)
	$UILayer.move_child(vignette_left, 1)

	vignette_right = ColorRect.new()
	vignette_right.anchors_preset = Control.PRESET_RIGHT_WIDE
	vignette_right.offset_left = -160.0
	vignette_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette_right.color = Color(0.0, 0.0, 0.0, 0.0)
	$UILayer.add_child(vignette_right)
	$UILayer.move_child(vignette_right, 1)

func _apply_level_visual_intensity() -> void:
	var danger := _danger_intensity()
	if danger_vignette != null:
		danger_vignette.color = Color(0.3, 0.02, 0.02, lerpf(0.0, 0.5, danger))
	if vignette_top != null:
		vignette_top.color = Color(0.35, 0.0, 0.0, lerpf(0.0, 0.55, danger))
	if vignette_bottom != null:
		vignette_bottom.color = Color(0.35, 0.0, 0.0, lerpf(0.0, 0.55, danger))
	if vignette_left != null:
		vignette_left.color = Color(0.3, 0.0, 0.0, lerpf(0.0, 0.5, danger))
	if vignette_right != null:
		vignette_right.color = Color(0.3, 0.0, 0.0, lerpf(0.0, 0.5, danger))
	if has_node("Background"):
		var base := Color(0.06, 0.08, 0.16, 1)
		$Background.color = Color(lerpf(base.r, 0.16, danger), lerpf(base.g, 0.03, danger), lerpf(base.b, 0.05, danger), 1.0)
	for spr in ground_sprites:
		spr.modulate = Color(lerpf(1.0, 1.2, danger), lerpf(1.0, 0.55, danger), lerpf(1.0, 0.55, danger), 1.0)

func _add_progressive_enemy_spawns(floor_top: float) -> void:
	var extra_ground_positions: Array[Vector2] = [
		Vector2(980, floor_top + 6.0),
		Vector2(1880, floor_top + 6.0),
		Vector2(2980, floor_top + 6.0),
		Vector2(4100, floor_top + 6.0),
		Vector2(4700, floor_top + 6.0)
	]
	var platform_positions: Array[Vector2] = [
		Vector2(420, 348),
		Vector2(1350, 332),
		Vector2(2450, 356),
		Vector2(3500, 338),
		Vector2(4550, 344)
	]
	var extra_count := maxi(0, level_index - 1)
	for i in range(extra_count):
		var ground_pos: Vector2 = extra_ground_positions[i % extra_ground_positions.size()]
		var ground_scene := ranged_enemy_scene if i % 2 == 0 else shadow_enemy_scene
		_register_enemy_spawn(ground_scene, ground_pos)
		var plat_pos: Vector2 = platform_positions[i % platform_positions.size()]
		var platform_scene := jumper_enemy_scene if i % 2 == 0 else (ranged_kiter_scene if i % 3 == 0 else ranged_enemy_scene)
		_register_enemy_spawn(platform_scene, plat_pos)

func _update_bg_parallax() -> void:
	if camera_ref == null or bg_sprites.is_empty():
		return
	var screen_center := camera_ref.get_screen_center_position()
	# La cam verticale est verrouillee sur locked_camera_y ; ne pas ancrer Y avec
	# get_screen_center_position() (souvent faux sur la 1re frame apres transition),
	# sinon le decalage reste faux pour tout le niveau.
	var cam_y := locked_camera_y
	if not parallax_anchor_ready:
		parallax_anchor_ready = true
		parallax_anchor_screen = Vector2(screen_center.x, cam_y)
		parallax_anchor_layer = bg_layer.position
	var start_lock_x := 320.0
	var end_lock_x := LEVEL_LENGTH - 320.0
	var anchor_x := clampf(parallax_anchor_screen.x, start_lock_x, end_lock_x)
	var parallax_source_x := clampf(screen_center.x, start_lock_x, end_lock_x)
	bg_layer.position.x = parallax_anchor_layer.x + (parallax_source_x - anchor_x) * 0.6
	bg_layer.position.y = parallax_anchor_layer.y + (cam_y - parallax_anchor_screen.y) + BG_PARALLAX_Y_OFFSET

func _power_name(power_id: int) -> String:
	var names := {
		GameState.POWER_IDS.BLUE_VISION: "Bleu - Impulsion",
		GameState.POWER_IDS.RED_MIGHT: "Rouge - Reflexion",
		GameState.POWER_IDS.GREEN_NATURE: "Vert - Acceleration",
		GameState.POWER_IDS.YELLOW_TIME: "Jaune - Ecrasement",
		GameState.POWER_IDS.VIOLET_SHADOW: "Violet - Dash",
		GameState.POWER_IDS.WHITE_LIGHT: "Blanc - Regeneration",
		GameState.POWER_IDS.BLACK_CORRUPTION: "Noir - Corruption",
		GameState.POWER_IDS.ORANGE_MOBILITY: "Orange - Tir Croise"
	}
	return names.get(power_id, "Inconnu")

func _power_description(power_id: int) -> String:
	var descriptions := {
		GameState.POWER_IDS.BLUE_VISION: "Double saut supplementaire.",
		GameState.POWER_IDS.RED_MIGHT: "Reflexion des projectiles qui se croisent.",
		GameState.POWER_IDS.GREEN_NATURE: "Vitesse + cooldowns reduits de 30%.",
		GameState.POWER_IDS.YELLOW_TIME: "Stomp: 3 coeurs en marchant sur un ennemi.",
		GameState.POWER_IDS.VIOLET_SHADOW: "Debloque le dash.",
		GameState.POWER_IDS.WHITE_LIGHT: "1 coeur rendu tous les 2 ennemis elimines.",
		GameState.POWER_IDS.BLACK_CORRUPTION: "1 coeur max, degats doubles.",
		GameState.POWER_IDS.ORANGE_MOBILITY: "Tir croise devant + derriere."
	}
	return descriptions.get(power_id, "Pouvoir inconnu.")

func _play_vitrail_reward_sound() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = AudioSynth.make_vitrail_reward_sfx()
	sfx.volume_db = -3.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
