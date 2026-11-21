extends CanvasLayer
signal panel_visibility_changed(is_open: bool)
const POWER_IDS = preload("res://scripts/powers/StainedGlassPower.gd").PowerId
const AudioSynth = preload("res://scripts/audio/AudioSynth.gd")
const UIThemeBuilder = preload("res://scripts/ui/UITheme.gd")

@onready var panel: Panel = $Panel
@onready var backdrop: ColorRect = $Backdrop
@onready var list_label: Label = $Panel/Margin/VBox/PowerList
@onready var status_label: Label = $Panel/Margin/VBox/Status
@onready var description_list_label: Label = $Panel/Margin/VBox/DescriptionList
@onready var root_vbox: VBoxContainer = $Panel/Margin/VBox
@onready var ui_open_sfx: AudioStreamPlayer = $UIOpenSFX
@onready var ui_close_sfx: AudioStreamPlayer = $UICloseSFX
var last_reward_text := ""
var shard_texture: Texture2D
var cards_container: VBoxContainer
var feedback_label: Label

var power_names := {
	POWER_IDS.BLUE_VISION: "Bleu - Impulsion",
	POWER_IDS.RED_MIGHT: "Rouge - Reflexion",
	POWER_IDS.ORANGE_MOBILITY: "Orange - Tir Croise",
	POWER_IDS.GREEN_NATURE: "Vert - Acceleration",
	POWER_IDS.YELLOW_TIME: "Jaune - Ecrasement",
	POWER_IDS.VIOLET_SHADOW: "Violet - Dash",
	POWER_IDS.WHITE_LIGHT: "Blanc - Regeneration",
	POWER_IDS.BLACK_CORRUPTION: "Noir - Corruption"
}
var power_descriptions := {
	POWER_IDS.BLUE_VISION: "Double saut supplementaire.",
	POWER_IDS.RED_MIGHT: "Les projectiles qui se touchent repartent vers leur direction d'origine.",
	POWER_IDS.GREEN_NATURE: "Vitesse augmentee et -30% sur les cooldowns.",
	POWER_IDS.YELLOW_TIME: "Inflige 3 coeurs en ecrasant un ennemi.",
	POWER_IDS.VIOLET_SHADOW: "Debloque la capacite de dash.",
	POWER_IDS.WHITE_LIGHT: "Recupere 1 coeur tous les 2 ennemis elimines.",
	POWER_IDS.BLACK_CORRUPTION: "Vie reduite a 1 coeur mais degats x2.",
	POWER_IDS.ORANGE_MOBILITY: "Tir croise: projectile devant et derriere."
}
var power_colors := {
	POWER_IDS.BLUE_VISION: Color(0.45, 0.75, 1.0, 1.0),
	POWER_IDS.RED_MIGHT: Color(1.0, 0.35, 0.35, 1.0),
	POWER_IDS.ORANGE_MOBILITY: Color(1.0, 0.62, 0.24, 1.0),
	POWER_IDS.GREEN_NATURE: Color(0.38, 0.95, 0.45, 1.0),
	POWER_IDS.YELLOW_TIME: Color(1.0, 0.9, 0.35, 1.0),
	POWER_IDS.VIOLET_SHADOW: Color(0.75, 0.5, 1.0, 1.0),
	POWER_IDS.WHITE_LIGHT: Color(1.0, 1.0, 1.0, 1.0),
	POWER_IDS.BLACK_CORRUPTION: Color(0.45, 0.45, 0.55, 1.0)
}

func _ready() -> void:
	panel.visible = false
	backdrop.visible = false
	backdrop.modulate.a = 0.0
	panel.scale = Vector2(0.96, 0.96)
	panel.modulate.a = 0.0
	panel.add_theme_stylebox_override("panel", UIThemeBuilder.build_equipment_panel_style())
	if panel.has_node("Margin/VBox/Spacer1"):
		panel.get_node("Margin/VBox/Spacer1").visible = false
	if panel.has_node("Margin/VBox/PowerList"):
		panel.get_node("Margin/VBox/PowerList").visible = false
	if panel.has_node("Margin/VBox/Spacer3"):
		panel.get_node("Margin/VBox/Spacer3").visible = false
	if panel.has_node("Margin/VBox/Separator2"):
		panel.get_node("Margin/VBox/Separator2").visible = false
	if panel.has_node("Margin/VBox/DescriptionTitle"):
		panel.get_node("Margin/VBox/DescriptionTitle").visible = false
	if panel.has_node("Margin/VBox/DescriptionList"):
		panel.get_node("Margin/VBox/DescriptionList").visible = false
	shard_texture = _load_shard_texture()
	_setup_cards_ui()
	ui_open_sfx.stream = AudioSynth.make_ui_open()
	ui_close_sfx.stream = AudioSynth.make_ui_close()
	GameState.powers_changed.connect(_refresh)
	GameState.progression_changed.connect(_refresh)
	GameState.level_reward_granted.connect(_on_level_reward_granted)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_equipment"):
		var opening := not panel.visible
		if opening:
			panel.visible = true
			backdrop.visible = true
		_play_panel_transition(opening)
		_refresh()
		panel_visibility_changed.emit(opening)
		get_viewport().set_input_as_handled()

	if not panel.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		_play_panel_transition(false)
		panel_visibility_changed.emit(false)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		var number: int = int(event.keycode - KEY_1)
		if number >= 0 and number <= 7:
			_toggle_by_index(number)

func _toggle_by_index(index: int) -> void:
	if index >= GameState.unlocked_powers.size():
		return
	var power_id: int = GameState.unlocked_powers[index]
	_toggle_power(power_id)
	_refresh()

func _refresh() -> void:
	list_label.visible = false
	description_list_label.visible = false
	status_label.text = "Equipes: %d/%d  |  Fragments: %d" % [
		GameState.equipped_powers.size(),
		GameState.max_power_slots,
		GameState.fragments_collected
	]
	if last_reward_text != "":
		status_label.text += "\n" + last_reward_text

	_refresh_cards()

func _on_level_reward_granted(reward_data: Dictionary) -> void:
	var power_id: int = reward_data.get("new_power_id", -1)
	if power_id == -1:
		last_reward_text = "Collection complete !"
	else:
		last_reward_text = "Nouveau: %s" % power_names.get(power_id, "Inconnu")
	_refresh()

func _play_panel_transition(opening: bool) -> void:
	var tween := create_tween()
	if opening:
		panel.scale = Vector2(0.94, 0.94)
		panel.modulate.a = 0.0
		backdrop.modulate.a = 0.0
		ui_open_sfx.play()
		tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(panel, "modulate:a", 1.0, 0.18)
		tween.parallel().tween_property(backdrop, "modulate:a", 0.9, 0.18)
	else:
		ui_close_sfx.play()
		tween.parallel().tween_property(panel, "scale", Vector2(0.94, 0.94), 0.14)
		tween.parallel().tween_property(panel, "modulate:a", 0.0, 0.14)
		tween.parallel().tween_property(backdrop, "modulate:a", 0.0, 0.14)
		tween.finished.connect(func() -> void:
			panel.visible = false
			backdrop.visible = false
		)

func apply_theme(theme: Theme) -> void:
	panel.theme = theme

func set_sfx_volume_linear(value: float) -> void:
	var vol := clampf(value, 0.0, 1.0)
	var db := linear_to_db(maxf(0.001, vol))
	ui_open_sfx.volume_db = db
	ui_close_sfx.volume_db = db

func is_panel_open() -> bool:
	return panel.visible

func _load_shard_texture() -> Texture2D:
	var candidates := [
		"res://img/shard.png",
		"res://img/white_shard.png"
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			var tex := load(p)
			if tex is Texture2D:
				return tex
	return null

func _setup_cards_ui() -> void:
	feedback_label = Label.new()
	feedback_label.name = "FeedbackLabel"
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 14)
	feedback_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42, 1.0))
	feedback_label.text = ""
	root_vbox.add_child(feedback_label)
	root_vbox.move_child(feedback_label, 4)

	cards_container = VBoxContainer.new()
	cards_container.name = "CardsContainer"
	cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_container.add_theme_constant_override("separation", 6)
	root_vbox.add_child(cards_container)
	root_vbox.move_child(cards_container, 6)

func _refresh_cards() -> void:
	if cards_container == null:
		return
	for child in cards_container.get_children():
		child.queue_free()
	if GameState.unlocked_powers.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucun vitrail debloque pour le moment.\nTermine un niveau pour en gagner un."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.98, 0.95))
		cards_container.add_child(empty_label)
		return
	for i in GameState.unlocked_powers.size():
		var power_id: int = GameState.unlocked_powers[i]
		cards_container.add_child(_build_power_card(power_id, i))

func _build_power_card(power_id: int, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.1, 0.2, 0.9)
	card_style.border_color = Color(0.4, 0.55, 0.85, 0.45)
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 8
	card_style.corner_radius_top_right = 8
	card_style.corner_radius_bottom_left = 8
	card_style.corner_radius_bottom_right = 8
	card_style.content_margin_left = 8
	card_style.content_margin_top = 5
	card_style.content_margin_right = 8
	card_style.content_margin_bottom = 5
	card.add_theme_stylebox_override("panel", card_style)

	var root := VBoxContainer.new()
	card.add_child(root)

	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(24, 24)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = shard_texture
	icon.modulate = power_colors.get(power_id, Color(1, 1, 1, 1))
	top.add_child(icon)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text_col)

	var name_label := Label.new()
	name_label.text = "%d. %s" % [index + 1, power_names.get(power_id, "Inconnu")]
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	text_col.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = power_descriptions.get(power_id, "Aucune description.")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.96, 0.95))
	text_col.add_child(desc_label)

	var action_button := Button.new()
	action_button.custom_minimum_size = Vector2(104, 28)
	_style_power_button(action_button, GameState.is_power_equipped(power_id))
	action_button.pressed.connect(func() -> void:
		_toggle_power(power_id)
		_refresh()
	)
	top.add_child(action_button)
	return card

func _style_power_button(button: Button, equipped: bool) -> void:
	button.flat = true
	if equipped:
		button.text = "Equipe"
		button.add_theme_stylebox_override("normal", UIThemeBuilder.build_menu_button_style(Color(0.06, 0.55, 0.12, 1.0)))
		button.add_theme_stylebox_override("hover", UIThemeBuilder.build_menu_button_style(Color(0.1, 0.7, 0.18, 1.0)))
		button.add_theme_stylebox_override("pressed", UIThemeBuilder.build_menu_button_style(Color(0.08, 0.45, 0.12, 1.0)))
		button.add_theme_color_override("font_color", Color(0.92, 1.0, 0.92, 1.0))
	else:
		button.text = "Desequipe"
		button.add_theme_stylebox_override("normal", UIThemeBuilder.build_menu_button_style(Color(0.03, 0.03, 0.04, 1.0)))
		button.add_theme_stylebox_override("hover", UIThemeBuilder.build_menu_button_style(Color(0.1, 0.1, 0.12, 1.0)))
		button.add_theme_stylebox_override("pressed", UIThemeBuilder.build_menu_button_style(Color(0.0, 0.0, 0.0, 1.0)))
		button.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96, 1.0))

func _toggle_power(power_id: int) -> void:
	if GameState.is_power_equipped(power_id):
		GameState.unequip_power(power_id)
		_set_feedback("")
		return
	if GameState.can_equip_more():
		GameState.equip_power(power_id)
		_set_feedback("")
	else:
		_set_feedback("Nombre de vitraux active max atteint")

func _set_feedback(message: String) -> void:
	if feedback_label == null:
		return
	feedback_label.text = message
