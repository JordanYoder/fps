extends CanvasLayer
## Debug menu (autoload as "DebugMenu"). Press ` / ~ to show it, then 1-9 to toggle options.
## While it's open, number keys go to the menu instead of switching weapons.
##
## Add options from here (see _ready) or from any script:
##     DebugMenu.add_option("God mode", func(on): god_mode = on)

const TOGGLE_KEY := KEY_QUOTELEFT # The ` / ~ key (physical position, so any keyboard layout)

class Option:
	var label: String
	var enabled: bool
	var on_toggle: Callable # Called with the new bool value
	func _init(l: String, e: bool, cb: Callable) -> void:
		label = l
		enabled = e
		on_toggle = cb

## Startup on/off values for options, edited in the Inspector. Optional.
const SETTINGS_PATH := "res://debug/debug_settings.tres"

var _options: Array[Option] = []
var _settings: DebugSettings
var _panel: PanelContainer
var _label: Label

func _ready() -> void:
	layer = 100 # Draw above the HUD and weapon sprites
	process_mode = Node.PROCESS_MODE_ALWAYS # Still works if the game is paused
	if ResourceLoader.exists(SETTINGS_PATH):
		_settings = load(SETTINGS_PATH) as DebugSettings
	_build_ui()
	visible = _settings != null and _settings.show_menu_on_start

	add_option("Audio", _set_audio, true)
	# Other scripts register options in their own _ready, which runs after this autoload's,
	# so check the settings for typos once everything has loaded.
	_warn_unknown_defaults.call_deferred()

func _set_audio(on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), not on)

## Registers a toggle. `on_toggle` receives the new value; it is also called once right
## away so the game starts in sync with the menu. `enabled` is the default, unless
## debug_settings.tres has an entry for this label.
func add_option(label: String, on_toggle: Callable, enabled: bool = false) -> void:
	if _options.size() >= 9:
		push_warning("DebugMenu: only 9 options fit on the number keys; '%s' not added" % label)
		return
	if _settings and _settings.option_defaults.has(label):
		enabled = _settings.option_defaults[label]
	_options.append(Option.new(label, enabled, on_toggle))
	on_toggle.call(enabled)
	_refresh()

func _warn_unknown_defaults() -> void:
	if not _settings:
		return
	for label in _settings.option_defaults:
		if not _options.any(func(o: Option) -> bool: return o.label == label):
			push_warning("DebugMenu: debug_settings.tres has a default for '%s', but no option has that name" % label)

func is_enabled(label: String) -> bool:
	for opt in _options:
		if opt.label == label:
			return opt.enabled
	return false

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key := event as InputEventKey
	if key.physical_keycode == TOGGLE_KEY:
		visible = not visible
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	var index := key.physical_keycode - KEY_1
	if index >= 0 and index < _options.size():
		var opt := _options[index]
		opt.enabled = not opt.enabled
		opt.on_toggle.call(opt.enabled)
		_refresh()
		get_viewport().set_input_as_handled()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(16, 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 20)
	_panel.add_child(_label)

func _refresh() -> void:
	if not _label:
		return
	var lines: PackedStringArray = ["DEBUG  ( ~ to close )", ""]
	for i in _options.size():
		var opt := _options[i]
		lines.append("%d. [%s] %s" % [i + 1, "ON " if opt.enabled else "OFF", opt.label])
	_label.text = "\n".join(lines)
