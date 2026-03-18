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

# Font sizes
const FONT_TITLE := 20
const FONT_HEADER := 16
const FONT_BODY := 16
const FONT_SMALL := 14
const FONT_TINY := 12

# Combat / initiative colors
const COMBAT_PLAYER_ACTIVE := Color(0.0, 1.0, 0.0)      # lime — active player
const COMBAT_ENEMY_ACTIVE := Color(1.0, 0.0, 0.0)        # red — active enemy
const COMBAT_PLAYER := Color(0.0, 1.0, 1.0)              # cyan — player (not active)
const COMBAT_ENEMY := Color(1.0, 1.0, 1.0)               # white — enemy (not active)
const COMBAT_DEAD := Color(0.5, 0.5, 0.5)                # gray — dead combatant

# HP bar colors
const HP_HIGH := Color(0.30, 0.75, 0.25)    # green
const HP_MID := Color(0.85, 0.75, 0.20)     # yellow
const HP_LOW := Color(0.85, 0.25, 0.20)     # red
