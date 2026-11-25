extends ColorRect
## Red screen flash when the player is hit. Put this on a full-screen ColorRect in the HUD.
## Bigger hits flash brighter; the screen stays tinted red after death.

## Strongest the flash gets (alpha), reached at max_flash_damage or more.
@export var max_alpha: float = 0.6
## A hit this big (or bigger) gives the strongest flash.
@export var max_flash_damage: int = 50
@export var fade_time: float = 0.4
@export var death_alpha: float = 0.35

var _tween: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	owner.damaged.connect(_on_damaged)
	owner.died.connect(_on_died)

func _on_damaged(amount: int) -> void:
	var strength := clampf(float(amount) / max_flash_damage, 0.25, 1.0)
	modulate.a = maxf(modulate.a, strength * max_alpha)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, fade_time)

func _on_died() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", death_alpha, fade_time)
