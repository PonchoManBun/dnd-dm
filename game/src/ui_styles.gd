class_name UIStyles
extends RefCounted

## Shared style factories for the RPG UI theme.
## All UI panels and overlays should use these instead of creating StyleBoxFlats inline.


# --- Panel styles ---

## Gold-bordered panel used by overlay screens (CharSheet, SRD, Pause).
static func overlay_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UIColors.PANEL_BG
	s.border_color = UIColors.FRAME_GOLD
	s.set_border_width_all(2)
	s.content_margin_left = 6.0
	s.content_margin_top = 4.0
	s.content_margin_right = 6.0
	s.content_margin_bottom = 4.0
	return s


## Left-border-only panel used by the DM Panel.
static func side_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UIColors.PANEL_BG
	s.border_color = UIColors.FRAME_GOLD
	s.border_width_left = 2
	s.border_width_top = 0
	s.border_width_right = 0
	s.border_width_bottom = 0
	s.content_margin_left = 6.0
	s.content_margin_top = 4.0
	s.content_margin_right = 6.0
	s.content_margin_bottom = 4.0
	return s


## Tight 1px-bordered slot panel used by the Hotbar.
static func slot_panel() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = UIColors.PANEL_BG_LIGHT
	s.border_color = UIColors.FRAME_GOLD
	s.set_border_width_all(1)
	s.content_margin_left = 2.0
	s.content_margin_right = 2.0
	s.content_margin_top = 1.0
	s.content_margin_bottom = 1.0
	return s


# --- Button styles ---

## Apply standard button overrides (normal/hover/pressed/focus) to a Button.
static func apply_button_styles(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UIColors.BUTTON_BG
	normal.border_color = UIColors.INPUT_BORDER
	normal.set_border_width_all(1)
	normal.set_content_margin_all(4)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = UIColors.BUTTON_HOVER
	hover.border_color = UIColors.FRAME_GOLD
	hover.set_border_width_all(1)
	hover.set_content_margin_all(4)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = UIColors.BUTTON_PRESSED
	pressed.border_color = UIColors.FRAME_GOLD
	pressed.set_border_width_all(1)
	pressed.set_content_margin_all(4)
	btn.add_theme_stylebox_override("pressed", pressed)


## Apply choice/chapter button styles (DM choices, SRD chapter list).
static func apply_choice_button_styles(btn: Button) -> void:
	btn.add_theme_color_override("font_color", UIColors.CHOICE_TEXT)
	btn.add_theme_color_override("font_hover_color", UIColors.CHOICE_HOVER_TEXT)
	btn.add_theme_color_override("font_pressed_color", UIColors.CHOICE_PRESSED_TEXT)

	var normal := StyleBoxFlat.new()
	normal.bg_color = UIColors.BUTTON_BG
	normal.content_margin_left = 4.0
	normal.content_margin_right = 4.0
	normal.content_margin_top = 2.0
	normal.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = UIColors.BUTTON_HOVER
	hover.content_margin_left = 4.0
	hover.content_margin_right = 4.0
	hover.content_margin_top = 2.0
	hover.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = UIColors.BUTTON_PRESSED
	pressed.content_margin_left = 4.0
	pressed.content_margin_right = 4.0
	pressed.content_margin_top = 2.0
	pressed.content_margin_bottom = 2.0
	btn.add_theme_stylebox_override("pressed", pressed)

	var focus := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", focus)


## Apply close button styles (red X button).
static func apply_close_button_styles(btn: Button) -> void:
	btn.add_theme_color_override("font_color", UIColors.CLOSE_BTN)
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4))
	btn.add_theme_font_size_override("font_size", UIColors.FONT_BODY)
	btn.custom_minimum_size = Vector2(20, 20)

	var normal := StyleBoxFlat.new()
	normal.bg_color = UIColors.BUTTON_BG
	normal.set_content_margin_all(2.0)
	btn.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.3, 0.12, 0.10, 0.9)
	hover.set_content_margin_all(2.0)
	btn.add_theme_stylebox_override("hover", hover)

	var focus := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", focus)


# --- Input styles ---

## Apply styled background to a LineEdit (normal + focus).
static func apply_input_styles(input: LineEdit) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = UIColors.INPUT_BG
	normal.border_color = UIColors.INPUT_BORDER
	normal.border_width_bottom = 1
	normal.content_margin_left = 4.0
	normal.content_margin_right = 4.0
	normal.content_margin_top = 2.0
	normal.content_margin_bottom = 2.0
	input.add_theme_stylebox_override("normal", normal)

	var focus := StyleBoxFlat.new()
	focus.bg_color = UIColors.INPUT_BG
	focus.border_color = UIColors.FRAME_GOLD
	focus.border_width_bottom = 1
	focus.content_margin_left = 4.0
	focus.content_margin_right = 4.0
	focus.content_margin_top = 2.0
	focus.content_margin_bottom = 2.0
	input.add_theme_stylebox_override("focus", focus)


# --- Separators ---

## Create a themed horizontal separator.
static func h_separator(separation: int = 2) -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxLine.new()
	style.color = UIColors.SEPARATOR
	style.thickness = 1
	sep.add_theme_stylebox_override("separator", style)
	sep.add_theme_constant_override("separation", separation)
	return sep


## Create a themed vertical separator.
static func v_separator() -> VSeparator:
	var sep := VSeparator.new()
	var style := StyleBoxLine.new()
	style.color = UIColors.SEPARATOR
	style.thickness = 1
	sep.add_theme_stylebox_override("separator", style)
	return sep


# --- Labels ---

## Create a header label (gold, FONT_HEADER size).
static func make_header(text: String, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_color_override("font_color", UIColors.TEXT_HEADER)
	label.add_theme_font_size_override("font_size", UIColors.FONT_HEADER)
	return label


## Create a standard label with custom color.
static func make_label(text: String, color: Color = UIColors.TEXT_PRIMARY, font_size: int = UIColors.FONT_BODY) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	return label


## Create a dim/secondary label (small, muted color).
static func make_dim_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	return label
