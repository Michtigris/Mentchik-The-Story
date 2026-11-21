extends RefCounted
class_name UITheme

const UI_FONT_PATH := "res://fonts/NotoSans-Regular.ttf"
const MENU_TITLE_FONT_PATH := "res://fonts/PressStart2P-Regular.ttf"


static func make_menu_title_font() -> Font:
	var font := _load_bundled_font(MENU_TITLE_FONT_PATH)
	if font != null:
		return font
	return _make_ui_font()


static func _make_ui_font() -> Font:
	var font := _load_bundled_font(UI_FONT_PATH)
	if font != null:
		return font
	# SystemFont is unreliable on HTML5 (shows hex "tofu" boxes). Prefer Godot's built-in.
	if ThemeDB.fallback_font != null:
		return ThemeDB.fallback_font
	if not OS.has_feature("web"):
		var fallback := SystemFont.new()
		fallback.font_names = PackedStringArray(["Segoe UI", "Arial", "Helvetica", "Liberation Sans", "sans-serif"])
		return fallback
	return FontFile.new()


static func _load_bundled_font(path: String) -> Font:
	# Prefer ResourceLoader: works in exported PCK/web. load_dynamic_font often fails on HTML5.
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if loaded is Font:
			return loaded as Font
	if not OS.has_feature("web"):
		var file := FontFile.new()
		if file.load_dynamic_font(path) == OK:
			return file
	return null


static func build_theme() -> Theme:
	var theme := Theme.new()
	var ui_font := _make_ui_font()
	theme.default_font = ui_font
	theme.default_font_size = 17
	theme.set_font("font", "Label", ui_font)
	theme.set_font("font", "Button", ui_font)
	theme.set_font("font", "LineEdit", ui_font)

	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color(0.06, 0.07, 0.13, 0.92)
	panel_box.corner_radius_top_left = 12
	panel_box.corner_radius_top_right = 12
	panel_box.corner_radius_bottom_left = 12
	panel_box.corner_radius_bottom_right = 12
	panel_box.border_width_left = 2
	panel_box.border_width_top = 2
	panel_box.border_width_right = 2
	panel_box.border_width_bottom = 2
	panel_box.border_color = Color(0.38, 0.55, 0.85, 0.7)
	panel_box.content_margin_left = 14
	panel_box.content_margin_top = 14
	panel_box.content_margin_right = 14
	panel_box.content_margin_bottom = 14
	panel_box.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	panel_box.shadow_size = 6
	theme.set_stylebox("panel", "Panel", panel_box)

	theme.set_color("font_color", "Label", Color(0.88, 0.92, 1.0, 1.0))
	theme.set_constant("line_spacing", "Label", 4)
	theme.set_font_size("font_size", "Label", 17)

	return theme

static func build_hub_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.12, 0.88)
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.5, 0.72, 1.0, 0.6)
	box.content_margin_left = 28
	box.content_margin_top = 24
	box.content_margin_right = 28
	box.content_margin_bottom = 24
	box.shadow_color = Color(0.15, 0.25, 0.5, 0.3)
	box.shadow_size = 10
	return box

static func build_hud_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.05, 0.1, 0.82)
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.border_color = Color(0.35, 0.5, 0.8, 0.5)
	box.content_margin_left = 10
	box.content_margin_top = 8
	box.content_margin_right = 10
	box.content_margin_bottom = 8
	return box

static func build_victory_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.06, 0.14, 0.94)
	box.corner_radius_top_left = 14
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_left = 14
	box.corner_radius_bottom_right = 14
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = 3
	box.border_color = Color(1.0, 0.85, 0.35, 0.8)
	box.content_margin_left = 20
	box.content_margin_top = 20
	box.content_margin_right = 20
	box.content_margin_bottom = 20
	box.shadow_color = Color(0.6, 0.5, 0.1, 0.25)
	box.shadow_size = 12
	return box

static func build_equipment_panel_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.06, 0.12, 0.94)
	box.corner_radius_top_left = 14
	box.corner_radius_top_right = 14
	box.corner_radius_bottom_left = 14
	box.corner_radius_bottom_right = 14
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_color = Color(0.5, 0.65, 1.0, 0.7)
	box.content_margin_left = 22
	box.content_margin_top = 22
	box.content_margin_right = 22
	box.content_margin_bottom = 22
	box.shadow_color = Color(0.1, 0.15, 0.35, 0.35)
	box.shadow_size = 8
	return box

static func build_menu_button_style(bg: Color, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.border_width_left = 0 if border.a <= 0.0 else 1
	box.border_width_top = 0 if border.a <= 0.0 else 1
	box.border_width_right = 0 if border.a <= 0.0 else 1
	box.border_width_bottom = 0 if border.a <= 0.0 else 1
	box.border_color = border
	box.content_margin_left = 14
	box.content_margin_top = 8
	box.content_margin_right = 14
	box.content_margin_bottom = 8
	return box
