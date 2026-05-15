extends Node

# --- SIGNALS ---
signal setting_changed(section: String, key: String, value: Variant)

# --- CONFIGURATION ---
const SETTINGS_PATH = "user://portable_settings.cfg"

const MODE_WINDOWED = 0
const MODE_BORDERLESS = 1
const MODE_FULLSCREEN = 2

# Supported Resolutions
const RESOLUTIONS = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

var default_settings = {
	"video": {
		"window_mode": MODE_WINDOWED,
		"resolution_index": 0,
		"vsync": true,
		"max_fps": 60,
		"render_scale": 1.0,
		"fov": 75.0,
	},
	"audio": {
		"master_vol": 0.8,
		"music_vol": 0.5,
		"sfx_vol": 0.6
	},
	"input": {
		"mouse_sensitivity": 0.002,
		"keybinds": {
			"move_forward": KEY_W,
			"move_backward": KEY_S,
			"move_left": KEY_A,
			"move_right": KEY_D,
			"jump": KEY_SPACE,
			"interact": KEY_E,
			"sprint": KEY_SHIFT,
			"crouch": KEY_CTRL
		}
	},
	"graphics": {
		"compatibility_mode": false
	}
}

var _config = ConfigFile.new()
var _pending_video_settings = {}

func _ready() -> void:
	load_settings()

func load_settings() -> void:
	var err = _config.load(SETTINGS_PATH)
	if err != OK:
		_initial_setup()
	
	# Load Video
	for key in default_settings.video:
		var val = _config.get_value("video", key, default_settings.video[key])
		_pending_video_settings[key] = val
		_apply_video_setting(key, val)

	# Load Audio
	for key in default_settings.audio:
		var val = _config.get_value("audio", key, default_settings.audio[key])
		_apply_audio_setting(key, val)
	
	# Load Input
	var sensitivity = _config.get_value("input", "mouse_sensitivity", default_settings.input.mouse_sensitivity)
	_apply_input_setting("mouse_sensitivity", sensitivity)
	
	var binds = _config.get_value("input", "keybinds", default_settings.input.keybinds)
	for action in binds:
		_apply_keybind(action, binds[action])
			
	# Load Graphics
	var compat = _config.get_value("graphics", "compatibility_mode", default_settings.graphics.compatibility_mode)
	_apply_graphics_setting("compatibility_mode", compat)

func _initial_setup() -> void:
	for section in default_settings:
		if section == "input":
			_config.set_value(section, "mouse_sensitivity", default_settings.input.mouse_sensitivity)
			_config.set_value(section, "keybinds", default_settings.input.keybinds)
		else:
			for key in default_settings[section]:
				_config.set_value(section, key, default_settings[section][key])
	
	# Auto-detect resolution
	var screen_size = DisplayServer.screen_get_size()
	var best_idx = 0
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i].x <= screen_size.x and RESOLUTIONS[i].y <= screen_size.y:
			best_idx = i
	_config.set_value("video", "resolution_index", best_idx)
	_config.save(SETTINGS_PATH)

# --- PUBLIC API ---

func set_video_setting(key: String, value: Variant) -> void:
	_pending_video_settings[key] = value

func apply_video_settings() -> void:
	for key in _pending_video_settings:
		_config.set_value("video", key, _pending_video_settings[key])
		_apply_video_setting(key, _pending_video_settings[key])
	_config.save(SETTINGS_PATH)

func save_audio_setting(key: String, value: Variant) -> void:
	_config.set_value("audio", key, value)
	_config.save(SETTINGS_PATH)
	_apply_audio_setting(key, value)
	setting_changed.emit("audio", key, value)

func save_input_setting(key: String, value: Variant) -> void:
	_config.set_value("input", key, value)
	_config.save(SETTINGS_PATH)
	_apply_input_setting(key, value)
	setting_changed.emit("input", key, value)

func save_keybind(action: String, keycode: int) -> void:
	var binds = _config.get_value("input", "keybinds", default_settings.input.keybinds)
	binds[action] = keycode
	_config.set_value("input", "keybinds", binds)
	_config.save(SETTINGS_PATH)
	_apply_keybind(action, keycode)
	setting_changed.emit("input", "keybind", [action, keycode])

func save_graphics_setting(key: String, value: Variant) -> void:
	_config.set_value("graphics", key, value)
	_config.save(SETTINGS_PATH)
	_apply_graphics_setting(key, value)
	setting_changed.emit("graphics", key, value)

func discard_pending_video_settings() -> void:
	_pending_video_settings.clear()
	for key in default_settings.video:
		var val = _config.get_value("video", key, default_settings.video[key])
		_pending_video_settings[key] = val

func get_video_setting(key: String):
	return _pending_video_settings.get(key, default_settings.video[key])

func get_audio_setting(key: String):
	return _config.get_value("audio", key, default_settings.audio[key])

func get_input_setting(key: String):
	return _config.get_value("input", key, default_settings.input[key])

func get_graphics_setting(key: String):
	return _config.get_value("graphics", key, default_settings.graphics[key])

# --- INTERNAL APPLICATORS ---

func _apply_video_setting(key: String, value: Variant) -> void:
	match key:
		"window_mode":
			match int(value):
				MODE_WINDOWED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
				MODE_BORDERLESS:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
					DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
					DisplayServer.window_set_size(DisplayServer.screen_get_size())
					DisplayServer.window_set_position(DisplayServer.screen_get_position())
				MODE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		
		"resolution_index":
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
				var res = RESOLUTIONS[value]
				DisplayServer.window_set_size(res)
				var screen_center = DisplayServer.screen_get_position() + DisplayServer.screen_get_size() / 2
				DisplayServer.window_set_position(screen_center - (res / 2))

		"vsync":
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value else DisplayServer.VSYNC_DISABLED)
		
		"max_fps":
			Engine.max_fps = value
			
		"render_scale":
			var vp = get_viewport()
			if vp: vp.scaling_3d_scale = value
			
		"fov":
			setting_changed.emit("video", "fov", value)

func _apply_audio_setting(key: String, value: Variant) -> void:
	var bus_name = key.replace("_vol", "").capitalize()
	var bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
		AudioServer.set_bus_mute(bus_index, value < 0.01)

func _apply_input_setting(_key: String, _value: Variant) -> void:
	pass

func _apply_keybind(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		return
		
	InputMap.action_erase_events(action)
	var new_event = InputEventKey.new()
	new_event.physical_keycode = keycode
	InputMap.action_add_event(action, new_event)

func _apply_graphics_setting(key: String, value: Variant) -> void:
	if key == "compatibility_mode":
		pass

# Helper for UI
func get_compatible_resolutions() -> Array:
	var screen_size = DisplayServer.screen_get_size()
	var compatible = []
	for res in RESOLUTIONS:
		if res.x <= screen_size.x and res.y <= screen_size.y:
			compatible.append(res)
	return compatible
