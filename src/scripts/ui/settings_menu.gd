extends CanvasLayer

signal back_pressed

@onready var content_vbox: VBoxContainer = %ContentVBox
@onready var tabs_container: HBoxContainer = %Tabs
@onready var back_button: Button = %BackButton
@onready var apply_button: Button = %ApplyButton

var active_category = "Video"

func _ready() -> void:
	# Discard any unapplied changes from previous sessions
	Settings.discard_pending_video_settings()
	
	WindowManager.push_mouse_state(WindowManager.MouseState.VISIBLE)

	# Setup Tabs
	for child in tabs_container.get_children():
		child.queue_free()
	
	for cat in ["Video", "Audio", "Input", "Graphics"]:
		var btn = Button.new()
		btn.text = " " + cat + " "
		btn.pressed.connect(func(): build_category(cat))
		tabs_container.add_child(btn)

	back_button.pressed.connect(_on_back_pressed)
	apply_button.pressed.connect(_on_apply_pressed)

	build_category("Video")

func _on_back_pressed():
	WindowManager.pop_mouse_state()
	back_pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

func _on_apply_pressed():
	Settings.apply_video_settings()

func build_category(cat_name: String):
	active_category = cat_name
	for child in content_vbox.get_children():
		child.queue_free()
	
	match cat_name:
		"Video": setup_video()
		"Audio": setup_audio()
		"Input": setup_input()
		"Graphics": setup_graphics()

func setup_video():
	# Window Mode
	var modes = ["Windowed", "Borderless", "Fullscreen"]
	add_dropdown("Window Mode", modes, Settings.get_video_setting("window_mode"), 
		func(idx): Settings.set_video_setting("window_mode", idx))
	
	# Resolution
	var res_list = Settings.get_compatible_resolutions()
	var res_strings = []
	for r in res_list: res_strings.append(str(r.x) + "x" + str(r.y))
	
	add_dropdown("Resolution", res_strings, Settings.get_video_setting("resolution_index"),
		func(idx): Settings.set_video_setting("resolution_index", idx))
	
	# VSync
	add_toggle("VSync", Settings.get_video_setting("vsync"),
		func(val): Settings.set_video_setting("vsync", val))
	
	# Max FPS
	var fps_opts = ["30", "60", "144", "Unlimited"]
	var fps_vals = [30, 60, 144, 0]
	var current_fps = Settings.get_video_setting("max_fps")
	add_dropdown("Max FPS", fps_opts, fps_vals.find(current_fps),
		func(idx): Settings.set_video_setting("max_fps", fps_vals[idx]))
		
	# FOV
	add_slider("Field of View", 60, 120, 1, Settings.get_video_setting("fov"),
		func(val): Settings.set_video_setting("fov", val))

func setup_audio():
	add_slider("Master Volume", 0, 1, 0.05, Settings.get_audio_setting("master_vol"),
		func(val): Settings.save_audio_setting("master_vol", val))
	
	add_slider("Music Volume", 0, 1, 0.05, Settings.get_audio_setting("music_vol"),
		func(val): Settings.save_audio_setting("music_vol", val))
		
	add_slider("SFX Volume", 0, 1, 0.05, Settings.get_audio_setting("sfx_vol"),
		func(val): Settings.save_audio_setting("sfx_vol", val))

func setup_input():
	add_slider("Mouse Sensitivity", 0.0001, 0.01, 0.0001, Settings.get_input_setting("mouse_sensitivity"),
		func(val): Settings.save_input_setting("mouse_sensitivity", val))
	
	add_slider("Controller Sensitivity", 0.01, 0.1, 0.005, Settings.get_input_setting("joy_sensitivity"),
		func(val): Settings.save_input_setting("joy_sensitivity", val))

func setup_graphics():
	add_toggle("Compatibility Mode", Settings.get_graphics_setting("compatibility_mode"),
		func(val): Settings.save_graphics_setting("compatibility_mode", val))

# --- Row Helpers ---

func add_row(label_text: String) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl)
	
	content_vbox.add_child(hbox)
	return hbox

func add_slider(label: String, min_v: float, max_v: float, step: float, current: float, callback: Callable):
	var row = add_row(label)
	var slider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = current
	slider.custom_minimum_size.x = 200
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(callback)
	row.add_child(slider)

func add_toggle(label: String, current: bool, callback: Callable):
	var row = add_row(label)
	var check = CheckButton.new()
	check.button_pressed = current
	check.toggled.connect(callback)
	row.add_child(check)

func add_dropdown(label: String, options: Array, current_idx: int, callback: Callable):
	var row = add_row(label)
	var opt = OptionButton.new()
	for o in options: opt.add_item(o)
	opt.selected = current_idx if current_idx >= 0 else 0
	opt.item_selected.connect(callback)
	row.add_child(opt)
