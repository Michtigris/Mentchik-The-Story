extends Node2D

const UIThemeBuilder = preload("res://scripts/ui/UITheme.gd")
const AudioSynth = preload("res://scripts/audio/AudioSynth.gd")
const MENU_BACKGROUND_TEXTURE = preload("res://img/menu principal.png")

@onready var menu_ui_layer: CanvasLayer = $MenuUILayer
@onready var menu_ui_root: Control = $MenuUILayer/MenuUIRoot
@onready var level_container: Node2D = $LevelContainer
@onready var fade_rect: ColorRect = $FadeRect
@onready var transition_title_label: Label = $FadeRect/TransitionTitle
@onready var sky_glow: ColorRect = $SkyGlow
@onready var menu_music: AudioStreamPlayer = $MenuMusic
@onready var level_music: AudioStreamPlayer = $LevelMusic
@onready var ui_click_sfx: AudioStreamPlayer = $UIClickSFX
@onready var transition_sfx: AudioStreamPlayer = $TransitionSFX

var level_scene := preload("res://scenes/levels/Level_VieilleVille.tscn")
var player_scene := preload("res://scenes/player/Player.tscn")
var current_level: Node2D
var menu_anim_time := 0.0
var ui_theme: Theme
var music_volume_linear := 0.55
var sfx_volume_linear := 0.65
var menu_background_texture: TextureRect
var options_info_label: Label
var sound_info_label: Label
var credits_info_label: Label
var options_panel: Panel
var sound_panel: Panel
var credits_panel: Panel
var menu_panel_ref: Panel
var menu_title_font: Font
var menu_buttons: Array[Button] = []
var continue_button_ref: Button
var continue_stats_label: Label
var dev_level_select: OptionButton

func _ready() -> void:
	GameState.progression_changed.connect(_refresh_hub_text)
	GameState.stats_changed.connect(_refresh_hub_text)
	if $EquipmentUI.has_signal("panel_visibility_changed"):
		$EquipmentUI.panel_visibility_changed.connect(_on_equipment_panel_visibility_changed)
	_ensure_default_ui_input()
	_load_volume_settings()
	_apply_theme()
	_setup_menu_background()
	_build_main_menu_buttons()
	fade_rect.visible = false
	fade_rect.modulate.a = 0.0
	transition_title_label.visible = false
	_configure_audio_streams()
	_play_menu_music()
	_refresh_hub_text()
	call_deferred("_release_menu_focus")


func _ensure_default_ui_input() -> void:
	if not InputMap.has_action("ui_accept"):
		InputMap.add_action("ui_accept")
	var accept_events := InputMap.action_get_events("ui_accept")
	var has_enter := false
	var has_space := false
	for ev in accept_events:
		if ev is InputEventKey:
			var k := ev as InputEventKey
			if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
				has_enter = true
			if k.keycode == KEY_SPACE:
				has_space = true
	if not has_enter:
		var e1 := InputEventKey.new()
		e1.keycode = KEY_ENTER
		InputMap.action_add_event("ui_accept", e1)
		var e2 := InputEventKey.new()
		e2.keycode = KEY_KP_ENTER
		InputMap.action_add_event("ui_accept", e2)
	if not has_space:
		var e3 := InputEventKey.new()
		e3.keycode = KEY_SPACE
		InputMap.action_add_event("ui_accept", e3)
	if not InputMap.has_action("ui_cancel"):
		InputMap.add_action("ui_cancel")
	var cancel_events := InputMap.action_get_events("ui_cancel")
	var has_esc := false
	for ev in cancel_events:
		if ev is InputEventKey and (ev as InputEventKey).keycode == KEY_ESCAPE:
			has_esc = true
			break
	if not has_esc:
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		InputMap.action_add_event("ui_cancel", esc)


func _release_menu_focus() -> void:
	if is_inside_tree():
		get_viewport().gui_release_focus()


func _menu_start_pressed(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE
	return false


func _input(event: InputEvent) -> void:
	if not menu_ui_layer.visible:
		return


func _process(delta: float) -> void:
	menu_anim_time += delta
	if menu_ui_layer.visible and sky_glow.visible:
		sky_glow.modulate.a = 0.24 + 0.28 * absf(sin(menu_anim_time * 0.9))
	if menu_ui_layer.visible and menu_panel_ref != null:
		menu_panel_ref.modulate.a = 0.72 + absf(sin(menu_anim_time * 1.1)) * 0.18
		menu_panel_ref.scale = Vector2.ONE * (0.995 + absf(sin(menu_anim_time * 0.75)) * 0.01)
		for btn in menu_buttons:
			var focus_boost := 0.0
			if btn.has_focus() or btn.is_hovered():
				focus_boost = 0.08 + absf(sin(menu_anim_time * 5.0)) * 0.08
			btn.modulate = Color(1.0 + focus_boost, 1.0 + focus_boost, 1.0 + focus_boost, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		_toggle_fullscreen()
		_play_ui_click(0.95)
		get_viewport().set_input_as_handled()
		return

	if not menu_ui_layer.visible and event.is_action_pressed("ui_cancel"):
		if $EquipmentUI.has_method("is_panel_open") and $EquipmentUI.is_panel_open():
			return
		_play_ui_click(0.9)
		_return_to_hub()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_MINUS:
			_set_music_volume(music_volume_linear - 0.05)
		elif event.keycode == KEY_EQUAL:
			_set_music_volume(music_volume_linear + 0.05)
		elif event.keycode == KEY_BRACKETLEFT:
			_set_sfx_volume(sfx_volume_linear - 0.05)
		elif event.keycode == KEY_BRACKETRIGHT:
			_set_sfx_volume(sfx_volume_linear + 0.05)

func _load_vieille_ville() -> void:
	GameState.ensure_valid_progression()
	_start_level(GameState.current_level_id)

func _start_level(level_id: String) -> void:
	GameState.clear_dev_combat_modifiers()
	_start_level_with_mode(level_id, true)

func _start_level_with_mode(level_id: String, enforce_unlock: bool) -> void:
	GameState.ensure_valid_progression()
	if enforce_unlock:
		if not GameState.unlocked_levels.has(level_id):
			level_id = GameState.current_level_id
		if not GameState.unlocked_levels.has(level_id):
			return
	else:
		if not level_id.begins_with("niveau_"):
			return
	_clear_level()
	$Hub.visible = false
	menu_ui_layer.visible = false
	_hide_all_menu_panels()
	if menu_background_texture != null:
		menu_background_texture.visible = false
	$Background.visible = false
	sky_glow.visible = false
	_stop_menu_music()
	current_level = level_scene.instantiate()
	level_container.add_child(current_level)
	var player := player_scene.instantiate()
	player.global_position = Vector2(80, 391)
	current_level.add_child(player)
	if current_level.has_method("setup_for_player"):
		var level_index := _level_id_to_index(level_id)
		current_level.setup_for_player(player, level_index)
	if current_level.has_signal("request_next_level"):
		current_level.request_next_level.connect(_on_request_next_level)
	_play_level_music()

func _return_to_hub() -> void:
	_clear_level()
	$Hub.visible = false
	menu_ui_layer.visible = true
	_hide_all_menu_panels()
	call_deferred("_release_menu_focus")
	if menu_background_texture != null:
		menu_background_texture.visible = true
	$Background.visible = false
	sky_glow.visible = true
	_stop_level_music()
	_play_menu_music()
	_refresh_hub_text()

func _clear_level() -> void:
	for child in level_container.get_children():
		child.queue_free()
	current_level = null

func _refresh_hub_text() -> void:
	var progression_text := "Progression: Fragments %d | Cathedrale %d/4 | Vitraux %d/8 | Niveaux %d/%d" % [
		GameState.fragments_collected,
		GameState.cathedral_restoration_stage,
		GameState.unlocked_powers.size(),
		GameState.completed_levels.size(),
		GameState.MAX_LEVEL
	]
	if options_info_label != null:
		options_info_label.text = "TOUCHES COMPLETES:\n\nMENU\n[ENTREE] Lancer partie\n[ESC] Retour menu\n[F11] Basculer plein ecran\n\nDEPLACEMENT\n[Q / A / <-] Aller a gauche\n[D / ->] Aller a droite\n[ESPACE] Sauter\n[SHIFT] Dash\n\nACTIONS\n[J] Attaque primaire\n[L] Pouvoir secondaire\n[K] Lancer epee\n[H] Lancer grenade\n[I] Ouvrir equipement\n\nOBJETS\nRecuperation automatique au contact\n\nRACCOURCIS\n[1..8] Equiper vitrail\n[- / +] Volume musique\n[[ / ]] Volume SFX"
	if sound_info_label != null:
		sound_info_label.text = ""
	if credits_info_label != null:
		credits_info_label.text = "LES ECLATS DE CHARTRES\n\n%s\n\nCreateurs: Benjamin, Erwan, Raphael, Ange\nPrototype Godot 4.2" % progression_text
	_refresh_continue_button_state()

func _on_request_next_level(next_level_id: String) -> void:
	if next_level_id == "":
		return
	transition_title_label.visible = true
	transition_title_label.text = "Transition vers %s..." % next_level_id
	await _play_fade(1.0, 0.4)
	_start_level(next_level_id)
	transition_title_label.text = "Prepare-toi..."
	await _play_fade(0.0, 0.4)
	transition_title_label.visible = false

func _on_equipment_panel_visibility_changed(is_open: bool) -> void:
	if current_level == null or not is_instance_valid(current_level):
		return
	if current_level.has_method("set_combat_pause_from_ui"):
		current_level.set_combat_pause_from_ui(is_open)

func _level_id_to_index(level_id: String) -> int:
	var parts := level_id.split("_")
	if parts.size() >= 2:
		return clampi(int(parts[1]), 1, GameState.MAX_LEVEL)
	return 1

func _play_fade(target_alpha: float, duration: float) -> void:
	fade_rect.visible = true
	transition_sfx.pitch_scale = 0.8 if target_alpha > 0.5 else 1.2
	transition_sfx.play()
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", target_alpha, duration)
	await tween.finished
	if target_alpha <= 0.01:
		fade_rect.visible = false

func _toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_theme() -> void:
	ui_theme = UIThemeBuilder.build_theme()
	menu_title_font = UIThemeBuilder.make_menu_title_font()
	var menu_panel: Panel = $MenuUILayer/MenuUIRoot/MenuPanel
	var menu_box := StyleBoxFlat.new()
	menu_box.bg_color = Color(0.03, 0.05, 0.12, 0.56)
	menu_box.corner_radius_top_left = 18
	menu_box.corner_radius_top_right = 18
	menu_box.corner_radius_bottom_left = 18
	menu_box.corner_radius_bottom_right = 18
	menu_box.border_width_left = 0
	menu_box.border_width_top = 0
	menu_box.border_width_right = 0
	menu_box.border_width_bottom = 0
	menu_box.content_margin_left = 22
	menu_box.content_margin_top = 22
	menu_box.content_margin_right = 22
	menu_box.content_margin_bottom = 22
	menu_box.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	menu_box.shadow_size = 12
	menu_panel.add_theme_stylebox_override("panel", menu_box)
	menu_panel.theme = ui_theme
	$EquipmentUI.apply_theme(ui_theme)

func _setup_menu_background() -> void:
	$Hub.visible = false
	$Background.visible = false
	$Background.color = Color(0.03, 0.04, 0.08, 1.0)
	if menu_ui_root.has_node("MenuBackgroundTexture"):
		menu_background_texture = menu_ui_root.get_node("MenuBackgroundTexture") as TextureRect
		_configure_menu_background_texture(menu_background_texture)
		menu_background_texture.visible = true
		return
	var tex_rect := TextureRect.new()
	tex_rect.name = "MenuBackgroundTexture"
	_configure_menu_background_texture(tex_rect)
	menu_ui_root.add_child(tex_rect)
	menu_background_texture = tex_rect
	menu_ui_root.move_child(tex_rect, 0)

func _configure_menu_background_texture(tex_rect: TextureRect) -> void:
	if tex_rect == null:
		return
	tex_rect.texture = MENU_BACKGROUND_TEXTURE
	tex_rect.anchors_preset = Control.PRESET_FULL_RECT
	tex_rect.anchor_left = 0.0
	tex_rect.anchor_top = 0.0
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	tex_rect.offset_left = 0.0
	tex_rect.offset_top = 0.0
	tex_rect.offset_right = 0.0
	tex_rect.offset_bottom = 0.0
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex_rect.modulate = Color(1, 1, 1, 1)
	tex_rect.z_index = -100

func _build_main_menu_buttons() -> void:
	menu_panel_ref = $MenuUILayer/MenuUIRoot/MenuPanel
	var vbox: VBoxContainer = $MenuUILayer/MenuUIRoot/MenuPanel/Margin/VBox
	for child in vbox.get_children():
		child.queue_free()
	menu_buttons.clear()

	var button_new_game := Button.new()
	button_new_game.text = "Nouvelle aventure"
	button_new_game.custom_minimum_size = Vector2(0, 52)
	_style_menu_button(button_new_game)
	button_new_game.pressed.connect(func() -> void:
		_start_new_adventure()
	)
	vbox.add_child(button_new_game)
	menu_buttons.append(button_new_game)
	button_new_game.grab_focus()

	continue_button_ref = Button.new()
	continue_button_ref.custom_minimum_size = Vector2(0, 52)
	_style_menu_button(continue_button_ref)
	continue_button_ref.pressed.connect(func() -> void:
		_start_continue_adventure()
	)
	vbox.add_child(continue_button_ref)
	menu_buttons.append(continue_button_ref)
	continue_stats_label = Label.new()
	continue_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	continue_stats_label.add_theme_font_size_override("font_size", 15)
	continue_stats_label.add_theme_color_override("font_color", Color(0.8, 0.86, 0.96, 0.9))
	continue_stats_label.custom_minimum_size = Vector2(0, 22)
	vbox.add_child(continue_stats_label)
	_refresh_continue_button_state()

	var button_options := Button.new()
	button_options.text = "Options"
	button_options.custom_minimum_size = Vector2(0, 52)
	_style_menu_button(button_options)
	button_options.pressed.connect(func() -> void:
		_toggle_menu_panel(options_panel)
	)
	vbox.add_child(button_options)
	menu_buttons.append(button_options)

	var button_son := Button.new()
	button_son.text = "Son"
	button_son.custom_minimum_size = Vector2(0, 52)
	_style_menu_button(button_son)
	button_son.pressed.connect(func() -> void:
		_toggle_menu_panel(sound_panel)
	)
	vbox.add_child(button_son)
	menu_buttons.append(button_son)

	var button_credits := Button.new()
	button_credits.text = "Credits"
	button_credits.custom_minimum_size = Vector2(0, 52)
	_style_menu_button(button_credits)
	button_credits.pressed.connect(func() -> void:
		_toggle_menu_panel(credits_panel)
	)
	vbox.add_child(button_credits)
	menu_buttons.append(button_credits)

	var button_quit := Button.new()
	button_quit.text = "Quitter"
	button_quit.custom_minimum_size = Vector2(0, 52)
	_style_menu_button(button_quit)
	button_quit.pressed.connect(func() -> void:
		_play_ui_click(0.92)
		get_tree().quit()
	)
	vbox.add_child(button_quit)
	menu_buttons.append(button_quit)

	options_panel = _create_info_panel("Options", Vector2(980, 60))
	options_panel.anchor_left = 1.0
	options_panel.anchor_right = 1.0
	options_panel.offset_left = -620.0
	options_panel.offset_right = -20.0
	options_panel.offset_top = 60.0
	options_panel.offset_bottom = 580.0
	options_panel.clip_contents = true
	options_info_label = options_panel.find_child("InfoLabel", true, false) as Label
	if options_info_label != null:
		options_info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		options_info_label.custom_minimum_size = Vector2(560, 0)
	menu_ui_root.add_child(options_panel)

	sound_panel = _create_info_panel("Son", Vector2(980, 270))
	sound_panel.anchor_left = 1.0
	sound_panel.anchor_right = 1.0
	sound_panel.offset_left = -470.0
	sound_panel.offset_right = -20.0
	sound_panel.offset_top = 270.0
	sound_panel.offset_bottom = 520.0
	sound_info_label = sound_panel.find_child("InfoLabel", true, false) as Label
	_add_sound_controls(sound_panel)
	menu_ui_root.add_child(sound_panel)

	credits_panel = _create_info_panel("Credits", Vector2(980, 450))
	credits_panel.anchor_left = 1.0
	credits_panel.anchor_right = 1.0
	credits_panel.offset_left = -540.0
	credits_panel.offset_right = -20.0
	credits_panel.offset_top = 360.0
	credits_panel.offset_bottom = 700.0
	credits_info_label = credits_panel.find_child("InfoLabel", true, false) as Label
	_add_dev_level_launcher(credits_panel)
	menu_ui_root.add_child(credits_panel)

	_refresh_hub_text()
	_hide_all_menu_panels()

func _add_sound_controls(panel: Panel) -> void:
	var margin := panel.get_child(0) as MarginContainer
	if margin == null:
		return
	var box := margin.get_child(0) as VBoxContainer
	if box == null:
		return

	var music_label := Label.new()
	music_label.text = "Volume musique"
	box.add_child(music_label)
	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.01
	music_slider.value = music_volume_linear
	music_slider.value_changed.connect(func(v: float) -> void:
		_set_music_volume(v)
	)
	box.add_child(music_slider)

	var sfx_label := Label.new()
	sfx_label.text = "Volume SFX"
	box.add_child(sfx_label)
	var sfx_slider := HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.01
	sfx_slider.value = sfx_volume_linear
	sfx_slider.value_changed.connect(func(v: float) -> void:
		_set_sfx_volume(v)
	)
	box.add_child(sfx_slider)

	var test_row := HBoxContainer.new()
	box.add_child(test_row)
	var test_music := Button.new()
	test_music.text = "Tester musique"
	_style_menu_button(test_music)
	test_music.pressed.connect(func() -> void:
		if menu_music.playing:
			menu_music.stop()
		else:
			menu_music.play()
	)
	test_row.add_child(test_music)

	var test_sfx := Button.new()
	test_sfx.text = "Tester SFX"
	_style_menu_button(test_sfx)
	test_sfx.pressed.connect(func() -> void:
		_play_ui_click(1.0)
	)
	test_row.add_child(test_sfx)

func _add_dev_level_launcher(panel: Panel) -> void:
	var margin := panel.get_child(0) as MarginContainer
	if margin == null:
		return
	var box := margin.get_child(0) as VBoxContainer
	if box == null:
		return
	var separator := ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.color = Color(0.35, 0.5, 0.8, 0.25)
	box.add_child(separator)
	var dev_title := Label.new()
	dev_title.text = "DEV TEST - LANCER NIVEAU"
	dev_title.add_theme_font_size_override("font_size", 14)
	dev_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45, 1.0))
	box.add_child(dev_title)
	dev_level_select = OptionButton.new()
	dev_level_select.custom_minimum_size = Vector2(0, 36)
	for i in range(1, GameState.MAX_LEVEL + 1):
		dev_level_select.add_item("Niveau %d" % i, i)
	box.add_child(dev_level_select)
	var launch_button := Button.new()
	launch_button.text = "Lancer niveau selectionne"
	launch_button.custom_minimum_size = Vector2(0, 44)
	_style_menu_button(launch_button)
	launch_button.pressed.connect(func() -> void:
		if dev_level_select == null:
			return
		var selected_idx := dev_level_select.get_selected_id()
		if selected_idx <= 0:
			selected_idx = 1
		GameState.prepare_dev_vitraux_selection()
		GameState.activate_dev_combat_modifiers()
		_play_ui_click(1.04)
		_start_level_with_mode("niveau_%d" % selected_idx, false)
	)
	box.add_child(launch_button)

func _style_menu_button(btn: Button) -> void:
	btn.flat = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", UIThemeBuilder.build_menu_button_style(Color(0.08, 0.16, 0.34, 0.78)))
	btn.add_theme_stylebox_override("hover", UIThemeBuilder.build_menu_button_style(Color(0.15, 0.28, 0.58, 0.9)))
	btn.add_theme_stylebox_override("pressed", UIThemeBuilder.build_menu_button_style(Color(0.07, 0.22, 0.52, 0.95)))
	btn.add_theme_stylebox_override("focus", UIThemeBuilder.build_menu_button_style(Color(0.2, 0.36, 0.72, 0.92)))
	if menu_title_font != null:
		btn.add_theme_font_override("font", menu_title_font)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_constant_override("outline_size", 3)
	btn.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.0, 1.0))
	btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.22, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.98, 0.55, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.95, 0.82, 0.2, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(1.0, 0.96, 0.45, 1.0))

func _create_info_panel(title: String, pos: Vector2) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = Vector2(450, 160)
	panel.visible = false
	panel.theme = ui_theme
	panel.add_theme_stylebox_override("panel", UIThemeBuilder.build_hub_panel_style())

	var margin := MarginContainer.new()
	margin.anchors_preset = Control.PRESET_FULL_RECT
	margin.offset_left = 10
	margin.offset_top = 10
	margin.offset_right = -10
	margin.offset_bottom = -10
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.anchors_preset = Control.PRESET_FULL_RECT
	box.anchor_left = 0.0
	box.anchor_top = 0.0
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 0.0
	box.offset_top = 0.0
	box.offset_right = 0.0
	box.offset_bottom = 0.0
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(box)

	var title_label := Label.new()
	title_label.text = title
	if menu_title_font != null:
		title_label.add_theme_font_override("font", menu_title_font)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.0, 1.0))
	title_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.2, 1.0))
	box.add_child(title_label)

	var info := Label.new()
	info.name = "InfoLabel"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(info)

	return panel

func _hide_all_menu_panels() -> void:
	if options_panel != null:
		options_panel.visible = false
	if sound_panel != null:
		sound_panel.visible = false
	if credits_panel != null:
		credits_panel.visible = false

func _can_continue_adventure() -> bool:
	GameState.ensure_valid_progression()
	return GameState.get_current_level_index() > 1

func _refresh_continue_button_state() -> void:
	if continue_button_ref == null:
		return
	var level_index := GameState.get_current_level_index()
	continue_button_ref.text = "Continuer (Niveau %d)" % level_index
	if continue_stats_label != null:
		continue_stats_label.text = "(niveau: %d, mort: %d, score: %d)" % [
			level_index,
			GameState.total_deaths,
			GameState.total_score
		]
	var can_continue := _can_continue_adventure()
	continue_button_ref.disabled = not can_continue
	continue_button_ref.modulate = Color(1, 1, 1, 1) if can_continue else Color(0.62, 0.62, 0.62, 0.9)
	if continue_stats_label != null:
		continue_stats_label.modulate = Color(1, 1, 1, 1) if can_continue else Color(0.72, 0.72, 0.72, 0.85)

func _start_new_adventure() -> void:
	_play_ui_click(1.05)
	GameState.reset_for_new_adventure()
	_refresh_continue_button_state()
	_start_level("niveau_1")

func _start_continue_adventure() -> void:
	if not _can_continue_adventure():
		return
	_play_ui_click(1.02)
	GameState.ensure_valid_progression()
	_start_level(GameState.current_level_id)

func _toggle_menu_panel(target_panel: Panel) -> void:
	if target_panel == null:
		return
	var should_open := not target_panel.visible
	_hide_all_menu_panels()
	target_panel.visible = should_open

func _configure_audio_streams() -> void:
	menu_music.stream = AudioSynth.make_menu_music()
	level_music.stream = AudioSynth.make_level_music()
	menu_music.pitch_scale = 1.0
	level_music.pitch_scale = 1.0
	ui_click_sfx.stream = AudioSynth.make_ui_open()
	transition_sfx.stream = AudioSynth.make_ui_close()
	_set_music_volume(music_volume_linear)
	_set_sfx_volume(sfx_volume_linear)

func _play_menu_music() -> void:
	if menu_music.playing:
		return
	menu_music.play()

func _stop_menu_music() -> void:
	if menu_music.playing:
		menu_music.stop()

func _play_level_music() -> void:
	if level_music.playing:
		return
	level_music.play()

func _stop_level_music() -> void:
	if level_music.playing:
		level_music.stop()

func _play_ui_click(pitch: float) -> void:
	ui_click_sfx.pitch_scale = pitch
	ui_click_sfx.play()

func _set_music_volume(value: float) -> void:
	music_volume_linear = clampf(value, 0.0, 1.0)
	var db := linear_to_db(maxf(0.001, music_volume_linear))
	menu_music.volume_db = db
	level_music.volume_db = db - 1.2
	_save_volume_settings()
	if menu_ui_layer.visible:
		_refresh_hub_text()

func _set_sfx_volume(value: float) -> void:
	sfx_volume_linear = clampf(value, 0.0, 1.0)
	var db := linear_to_db(maxf(0.001, sfx_volume_linear))
	ui_click_sfx.volume_db = db
	transition_sfx.volume_db = db
	$EquipmentUI.set_sfx_volume_linear(sfx_volume_linear)
	_save_volume_settings()
	if menu_ui_layer.visible:
		_refresh_hub_text()

func _load_volume_settings() -> void:
	if not FileAccess.file_exists("user://audio_settings.json"):
		return
	var file := FileAccess.open("user://audio_settings.json", FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		music_volume_linear = float(parsed.get("music", music_volume_linear))
		sfx_volume_linear = float(parsed.get("sfx", sfx_volume_linear))

func _save_volume_settings() -> void:
	var file := FileAccess.open("user://audio_settings.json", FileAccess.WRITE)
	if file == null:
		return
	var data := {
		"music": music_volume_linear,
		"sfx": sfx_volume_linear
	}
	file.store_string(JSON.stringify(data))
