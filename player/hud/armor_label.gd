extends Label
## Shows the player's armor. Put this on a Label inside the player's HUD.

@export var armor_color: Color = Color(0.3, 0.8, 1.0)
@export var no_armor_color: Color = Color(0.5, 0.5, 0.5)

func _ready() -> void:
	# owner is the Player, the root of player.tscn
	owner.armor_changed.connect(_on_armor_changed)

func _on_armor_changed(armor: int) -> void:
	text = "%d%%" % armor
	modulate = armor_color if armor > 0 else no_armor_color
