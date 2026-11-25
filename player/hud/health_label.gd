extends Label
## Shows the player's health. Put this on a Label inside the player's HUD.
## Colour shifts like Doom's status bar: normal, then yellow, then red as you get hurt.

@export var healthy_color: Color = Color(1.0, 0.25, 0.2)
@export var low_color: Color = Color(1.0, 0.85, 0.2)    ## At or below low_threshold
@export var critical_color: Color = Color(1.0, 0.0, 0.0) ## At or below critical_threshold
@export var low_threshold: int = 50
@export var critical_threshold: int = 25

func _ready() -> void:
	# owner is the Player, the root of player.tscn
	owner.health_changed.connect(_on_health_changed)

func _on_health_changed(health: int, _max_health: int) -> void:
	text = "%d%%" % health
	if health <= critical_threshold:
		modulate = critical_color
	elif health <= low_threshold:
		modulate = low_color
	else:
		modulate = healthy_color
