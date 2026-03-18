class_name PauseOverlay
extends Control

## Pause menu overlay. Shown when Esc is pressed.
## Pauses the game tree and provides Resume, Main Menu, and Quit options.


func _ready() -> void:
	# Must process while paused
	process_mode = PROCESS_MODE_ALWAYS
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	# Dark overlay background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.65)
	bg.mouse_filter = MOUSE_FILTER_STOP
	add_child(bg)

	# Centered panel
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	var panel_style := UIStyles.overlay_panel()
	panel_style.content_margin_left = 16.0
	panel_style.content_margin_top = 12.0
	panel_style.content_margin_right = 16.0
	panel_style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", panel_style)
	panel.custom_minimum_size = Vector2(200, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", UIColors.TEXT_HEADER)
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	# Separator
	var sep := UIStyles.h_separator(4)
	vbox.add_child(sep)

	# Resume
	var resume_btn := _make_button("Resume")
	resume_btn.pressed.connect(_on_resume)
	vbox.add_child(resume_btn)

	# Main Menu
	var menu_btn := _make_button("Main Menu")
	menu_btn.pressed.connect(_on_main_menu)
	vbox.add_child(menu_btn)

	# Quit
	var quit_btn := _make_button("Quit Game")
	quit_btn.pressed.connect(_on_quit)
	vbox.add_child(quit_btn)


func toggle() -> void:
	if visible:
		_on_resume()
	else:
		visible = true
		get_tree().paused = true


func _on_resume() -> void:
	visible = false
	get_tree().paused = false


func _on_main_menu() -> void:
	# Unpause briefly so modal can work
	get_tree().paused = false
	var confirmed: Variant = await Modals.confirm("Return to Menu", "Return to the main menu?")
	if confirmed:
		Modals.close_all_modals()
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
	else:
		# Re-pause if cancelled
		get_tree().paused = true


func _on_quit() -> void:
	get_tree().paused = false
	var confirmed: Variant = await Modals.confirm("Quit Game", "Are you sure you want to quit?")
	if confirmed:
		get_tree().quit()
	else:
		get_tree().paused = true


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(160, 28)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	btn.add_theme_color_override("font_hover_color", UIColors.TEXT_HEADER)
	UIStyles.apply_button_styles(btn)
	return btn
