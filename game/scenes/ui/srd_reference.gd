class_name SrdReference
extends PanelContainer

## SRD Reference panel — toggleable overlay for looking up D&D 5e SRD rules.
## Built entirely in code (same pattern as DMPanel).
## Press '?' to toggle visibility.

## Chapter list width as a fraction of panel width
const CHAPTER_LIST_RATIO := 0.30

var _chapters: Array[Dictionary] = []  # [{filename, title}]
var _selected_index: int = -1

var _hbox: HBoxContainer
var _chapter_scroll: ScrollContainer
var _chapter_list: VBoxContainer
var _content_scroll: ScrollContainer
var _content_label: RichTextLabel
var _header_label: Label
var _close_button: Button
var _vbox: VBoxContainer
var _rules_dir: String = ""


func _ready() -> void:
	_resolve_rules_dir()
	_scan_chapters()
	_build_ui()
	# Select the first chapter by default
	if _chapters.size() > 0:
		_select_chapter(0)


func _resolve_rules_dir() -> void:
	# The rules directory is one level above the Godot project directory.
	# ProjectSettings.globalize_path("res://") gives us the absolute project dir.
	var project_dir := ProjectSettings.globalize_path("res://")
	# Go up one directory and into rules/
	_rules_dir = project_dir.path_join("../rules").simplify_path()


func _scan_chapters() -> void:
	_chapters.clear()
	var dir := DirAccess.open(_rules_dir)
	if not dir:
		Log.w("SrdReference: could not open rules dir: %s" % _rules_dir)
		return

	dir.list_dir_begin()
	var files: Array[String] = []
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".md"):
			files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()

	# Sort alphabetically so numbered prefixes give correct order
	files.sort()

	for f in files:
		# Extract a readable title from the filename:
		# "07 combat.md" -> "Combat"
		var title := f.get_basename()  # "07 combat"
		# Strip leading digits and space
		var idx := 0
		while idx < title.length() and (title[idx].is_valid_int() or title[idx] == " "):
			idx += 1
		title = title.substr(idx).strip_edges()
		if title.is_empty():
			title = f.get_basename()
		# Capitalize first letter of each word
		title = title.capitalize()
		_chapters.append({"filename": f, "title": title})


func _build_ui() -> void:
	# Panel style
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UIColors.PANEL_BG
	panel_style.border_color = UIColors.FRAME_GOLD
	panel_style.set_border_width_all(2)
	panel_style.content_margin_left = 6.0
	panel_style.content_margin_top = 4.0
	panel_style.content_margin_right = 6.0
	panel_style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", panel_style)

	# Main vertical layout (header row + body)
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)

	# -- Header row (title + close button) --
	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_child(header_row)

	_header_label = Label.new()
	_header_label.text = "SRD Reference"
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.add_theme_color_override("font_color", UIColors.TEXT_HEADER)
	_header_label.add_theme_font_size_override("font_size", 16)
	header_row.add_child(_header_label)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.add_theme_color_override("font_color", UIColors.CLOSE_BTN)
	_close_button.add_theme_color_override("font_hover_color", Color(1.0, 0.4, 0.4))
	_close_button.add_theme_font_size_override("font_size", 16)
	_close_button.custom_minimum_size = Vector2(20, 20)

	var close_normal := StyleBoxFlat.new()
	close_normal.bg_color = UIColors.BUTTON_BG
	close_normal.content_margin_left = 4.0
	close_normal.content_margin_right = 4.0
	close_normal.content_margin_top = 1.0
	close_normal.content_margin_bottom = 1.0
	_close_button.add_theme_stylebox_override("normal", close_normal)

	var close_hover := StyleBoxFlat.new()
	close_hover.bg_color = Color(0.3, 0.12, 0.10, 0.9)
	close_hover.content_margin_left = 4.0
	close_hover.content_margin_right = 4.0
	close_hover.content_margin_top = 1.0
	close_hover.content_margin_bottom = 1.0
	_close_button.add_theme_stylebox_override("hover", close_hover)

	var close_focus := StyleBoxEmpty.new()
	_close_button.add_theme_stylebox_override("focus", close_focus)

	_close_button.pressed.connect(_on_close_pressed)
	header_row.add_child(_close_button)

	# Header separator
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = UIColors.SEPARATOR
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 2)
	_vbox.add_child(sep)

	# -- Body: chapter list (left) + content (right) --
	_hbox = HBoxContainer.new()
	_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hbox.add_theme_constant_override("separation", 4)
	_vbox.add_child(_hbox)

	# Chapter list scroll
	_chapter_scroll = ScrollContainer.new()
	_chapter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chapter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chapter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_chapter_scroll.custom_minimum_size.x = 120
	# Let it take ~30% of horizontal space
	_chapter_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_scroll.size_flags_stretch_ratio = CHAPTER_LIST_RATIO
	_hbox.add_child(_chapter_scroll)

	_chapter_list = VBoxContainer.new()
	_chapter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_list.add_theme_constant_override("separation", 2)
	_chapter_scroll.add_child(_chapter_list)

	# Build chapter buttons
	for i in range(_chapters.size()):
		var btn := Button.new()
		btn.text = _chapters[i].title
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", UIColors.CHOICE_TEXT)
		btn.add_theme_color_override("font_hover_color", UIColors.CHOICE_HOVER_TEXT)

		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = UIColors.BUTTON_BG
		btn_normal.content_margin_left = 4.0
		btn_normal.content_margin_right = 4.0
		btn_normal.content_margin_top = 2.0
		btn_normal.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("normal", btn_normal)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = UIColors.BUTTON_HOVER
		btn_hover.content_margin_left = 4.0
		btn_hover.content_margin_right = 4.0
		btn_hover.content_margin_top = 2.0
		btn_hover.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = UIColors.BUTTON_PRESSED
		btn_pressed.content_margin_left = 4.0
		btn_pressed.content_margin_right = 4.0
		btn_pressed.content_margin_top = 2.0
		btn_pressed.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		var btn_focus := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("focus", btn_focus)

		var chapter_idx := i
		btn.pressed.connect(func() -> void: _select_chapter(chapter_idx))
		_chapter_list.add_child(btn)

	# Vertical separator between list and content
	var vsep := VSeparator.new()
	var vsep_style := StyleBoxLine.new()
	vsep_style.color = UIColors.SEPARATOR
	vsep_style.thickness = 1
	vsep.add_theme_stylebox_override("separator", vsep_style)
	_hbox.add_child(vsep)

	# Content area
	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.size_flags_stretch_ratio = 1.0 - CHAPTER_LIST_RATIO
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_hbox.add_child(_content_scroll)

	_content_label = RichTextLabel.new()
	_content_label.bbcode_enabled = true
	_content_label.fit_content = true
	_content_label.scroll_active = false
	_content_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content_label.add_theme_color_override("default_color", UIColors.TEXT_PRIMARY)
	_content_label.add_theme_font_size_override("normal_font_size", 16)
	_content_label.add_theme_font_size_override("bold_font_size", 16)
	_content_label.add_theme_font_size_override("italics_font_size", 16)
	_content_label.add_theme_font_size_override("bold_italics_font_size", 16)
	_content_label.add_theme_constant_override("line_separation", 2)
	_content_scroll.add_child(_content_label)


func _select_chapter(index: int) -> void:
	if index < 0 or index >= _chapters.size():
		return

	_selected_index = index

	# Update button highlighting
	for i in range(_chapter_list.get_child_count()):
		var btn := _chapter_list.get_child(i) as Button
		if not btn:
			continue
		var style := StyleBoxFlat.new()
		if i == index:
			style.bg_color = UIColors.TAB_SELECTED_BG
		else:
			style.bg_color = UIColors.BUTTON_BG
		style.content_margin_left = 4.0
		style.content_margin_right = 4.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0
		btn.add_theme_stylebox_override("normal", style)

	# Load and display the chapter content
	var filepath := _rules_dir.path_join(_chapters[index].filename)
	var file := FileAccess.open(filepath, FileAccess.READ)
	if not file:
		_content_label.text = "[color=red]Could not open: %s[/color]" % filepath
		return

	var md_text := file.get_as_text()
	file.close()

	_content_label.text = _markdown_to_bbcode(md_text)

	# Scroll content back to top
	await get_tree().process_frame
	_content_scroll.scroll_vertical = 0


func _markdown_to_bbcode(md: String) -> String:
	var lines := md.split("\n")
	var result := ""
	var i := 0
	var header_color := UIColors.TEXT_HEADER.to_html()

	while i < lines.size():
		var line := lines[i]

		# Check if the NEXT line is a setext-style header underline
		if i + 1 < lines.size():
			var next_line := lines[i + 1].strip_edges()
			if next_line.length() >= 3:
				var all_equals := true
				var all_dashes := true
				for ch in next_line:
					if ch != "=":
						all_equals = false
					if ch != "-":
						all_dashes = false
				if all_equals and line.strip_edges().length() > 0:
					# H1: setext style with ====
					result += "[b][font_size=18][color=#%s]%s[/color][/font_size][/b]\n\n" % [header_color, _inline_format(line.strip_edges())]
					i += 2
					continue
				if all_dashes and line.strip_edges().length() > 0:
					# H2: setext style with ----
					result += "[b][font_size=16][color=#%s]%s[/color][/font_size][/b]\n\n" % [header_color, _inline_format(line.strip_edges())]
					i += 2
					continue

		var stripped := line.strip_edges()

		# ATX headers
		if stripped.begins_with("#####"):
			var text := stripped.substr(5).strip_edges()
			result += "[b][color=#%s]%s[/color][/b]\n" % [header_color, _inline_format(text)]
		elif stripped.begins_with("####"):
			var text := stripped.substr(4).strip_edges()
			result += "[b][color=#%s]%s[/color][/b]\n" % [header_color, _inline_format(text)]
		elif stripped.begins_with("###"):
			var text := stripped.substr(3).strip_edges()
			result += "[b][color=#%s]%s[/color][/b]\n" % [header_color, _inline_format(text)]
		elif stripped.begins_with("##"):
			var text := stripped.substr(2).strip_edges()
			result += "[b][font_size=16][color=#%s]%s[/color][/font_size][/b]\n" % [header_color, _inline_format(text)]
		elif stripped.begins_with("#"):
			var text := stripped.substr(1).strip_edges()
			result += "[b][font_size=18][color=#%s]%s[/color][/font_size][/b]\n\n" % [header_color, _inline_format(text)]
		elif stripped.begins_with("- ") or stripped.begins_with("* "):
			# Bullet list item
			var text := stripped.substr(2).strip_edges()
			var dim_color := UIColors.TEXT_DIM.to_html()
			result += "  [color=#%s]>[/color] %s\n" % [dim_color, _inline_format(text)]
		elif stripped.begins_with("| ") or (stripped.begins_with("|") and stripped.find("-+-") >= 0):
			# Table row — render as-is with monospace feel via indent
			var dim_color := UIColors.TEXT_DIM.to_html()
			result += "[color=#%s]%s[/color]\n" % [dim_color, stripped]
		elif _is_ordered_list_item(stripped):
			# Ordered list: "1. text", "2. text", etc.
			var dot_idx := stripped.find(". ")
			if dot_idx >= 0:
				var num := stripped.substr(0, dot_idx + 1)
				var text := stripped.substr(dot_idx + 2).strip_edges()
				var dim_color := UIColors.TEXT_DIM.to_html()
				result += "  [color=#%s]%s[/color] %s\n" % [dim_color, num, _inline_format(text)]
			else:
				result += "%s\n" % _inline_format(stripped)
		elif stripped.is_empty():
			result += "\n"
		else:
			result += "%s\n" % _inline_format(stripped)

		i += 1

	return result.strip_edges()


func _is_ordered_list_item(line: String) -> bool:
	# Matches lines like "1. ", "12. ", etc.
	var idx := 0
	while idx < line.length() and line[idx].is_valid_int():
		idx += 1
	if idx > 0 and idx + 1 < line.length() and line[idx] == "." and line[idx + 1] == " ":
		return true
	return false


func _inline_format(text: String) -> String:
	# Process bold-italic first: ***text*** or ___text___
	text = _replace_pattern(text, "***", "***", "[b][i]", "[/i][/b]")
	text = _replace_pattern(text, "___", "___", "[b][i]", "[/i][/b]")
	# Bold: **text** or __text__
	text = _replace_pattern(text, "**", "**", "[b]", "[/b]")
	text = _replace_pattern(text, "__", "__", "[b]", "[/b]")
	# Italic: *text* or _text_ (be careful not to match inside words for _)
	text = _replace_pattern(text, "*", "*", "[i]", "[/i]")
	return text


func _replace_pattern(text: String, open_delim: String, close_delim: String, bbcode_open: String, bbcode_close: String) -> String:
	var result := ""
	var search_start := 0

	while search_start < text.length():
		var open_pos := text.find(open_delim, search_start)
		if open_pos < 0:
			result += text.substr(search_start)
			break

		var close_pos := text.find(close_delim, open_pos + open_delim.length())
		if close_pos < 0:
			result += text.substr(search_start)
			break

		# Add text before the opening delimiter
		result += text.substr(search_start, open_pos - search_start)
		# Add the BBCode-wrapped content
		var inner := text.substr(open_pos + open_delim.length(), close_pos - open_pos - open_delim.length())
		result += bbcode_open + inner + bbcode_close
		search_start = close_pos + close_delim.length()

	return result


func _on_close_pressed() -> void:
	visible = false


func toggle() -> void:
	visible = not visible
	if visible and _selected_index >= 0:
		# Scroll content to top when reopening
		await get_tree().process_frame
		_content_scroll.scroll_vertical = 0
