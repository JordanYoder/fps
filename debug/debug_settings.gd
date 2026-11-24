class_name DebugSettings
extends Resource
## Startup defaults for the debug menu. Edit res://debug/debug_settings.tres in the Inspector.

## Option label (exactly as shown in the menu, e.g. "Audio") -> on/off when the game starts.
## Options not listed here use the default from the code that registers them.
@export var option_defaults: Dictionary[String, bool] = {}

## Open the debug menu as soon as the game starts.
@export var show_menu_on_start: bool = false
