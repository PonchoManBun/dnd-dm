class_name UIColors
extends RefCounted

## Central color palette for the RPG UI theme.
## All UI panels and overlays should reference these instead of hardcoding colors.

# Panel chrome
const FRAME_DARK := Color(0.24, 0.17, 0.12)
const FRAME_GOLD := Color(0.77, 0.64, 0.31)
const PANEL_BG := Color(0.12, 0.09, 0.07, 0.92)
const PANEL_BG_LIGHT := Color(0.18, 0.14, 0.10, 0.88)

# Text
const TEXT_PRIMARY := Color(0.93, 0.88, 0.78)
const TEXT_HEADER := Color(0.95, 0.85, 0.60)
const TEXT_DIM := Color(0.60, 0.55, 0.45)

# Buttons
const BUTTON_BG := Color(0.18, 0.14, 0.10, 0.85)
const BUTTON_HOVER := Color(0.24, 0.19, 0.14, 0.9)
const BUTTON_PRESSED := Color(0.10, 0.08, 0.06, 0.9)
const BUTTON_DISABLED := Color(0.14, 0.11, 0.08, 0.5)

# Choice / interactive elements
const CHOICE_TEXT := Color(0.95, 0.85, 0.60)
const CHOICE_HOVER_TEXT := Color(1.0, 0.95, 0.80)
const CHOICE_PRESSED_TEXT := Color(0.75, 0.65, 0.40)

# Input fields
const INPUT_BG := Color(0.08, 0.06, 0.04, 0.9)
const INPUT_BORDER := Color(0.35, 0.28, 0.20, 0.6)

# Separators
const SEPARATOR := Color(0.30, 0.24, 0.16, 0.5)

# Close / danger
const CLOSE_BTN := Color(0.827, 0.271, 0.286)

# Scrollbar
const SCROLLBAR_BG := Color(0.12, 0.09, 0.07, 0.5)
const SCROLLBAR_GRABBER := Color(0.40, 0.33, 0.22, 0.7)
const SCROLLBAR_GRABBER_HOVER := Color(0.50, 0.42, 0.28, 0.8)
const SCROLLBAR_GRABBER_PRESSED := Color(0.30, 0.24, 0.16, 0.8)

# Tab bar
const TAB_SELECTED_BG := Color(0.20, 0.16, 0.11, 0.9)
const TAB_UNSELECTED_BG := Color(0.14, 0.11, 0.08, 0.7)
const TAB_HOVER_BG := Color(0.24, 0.19, 0.14, 0.85)

# Progress bar
const PROGRESS_BG := Color(0.12, 0.09, 0.07, 0.7)
const PROGRESS_FILL := Color(0.30, 0.55, 0.25, 1.0)

# Focus outline
const FOCUS_BORDER := Color(0.77, 0.64, 0.31, 0.8)


## Create a standard panel StyleBoxFlat with gold border.
static func make_panel_style(bg: Color = PANEL_BG, border: Color = FRAME_GOLD, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.content_margin_left = 4.0
	style.content_margin_top = 4.0
	style.content_margin_right = 4.0
	style.content_margin_bottom = 4.0
	return style


## Create a button StyleBoxFlat.
static func make_button_style(bg: Color, border_w: int = 0, border_c: Color = FRAME_GOLD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border_c
	style.set_border_width_all(border_w)
	style.content_margin_left = 5.0
	style.content_margin_top = 5.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 5.0
	return style
