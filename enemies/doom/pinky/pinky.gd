extends DoomEnemy

# The Pinky (Demon) is melee only: it charges fast and bites. Values from Doom.

@export_group("Pinky Attack")
## Doom bite: (1..10) * 4
@export var bite_damage_min: int = 4
@export var bite_damage_max: int = 40

func _ready() -> void:
	max_health = 150
	pain_chance = 0.7 # Doom Demon = 180/256 (~70%)
	pain_time = 0.11 # 4 tics
	mass = 400.0
	species = &"demon"
	speed = 4.4 # Doom Demon speed 10 vs Imp's 8, scaled from the 3.5 default
	has_melee = true
	has_ranged = false
	# Attack: frames E and F wind up (8 tics each, ~0.23s), frame G bites (8 tics)
	windup_time = 0.46
	fire_frame_time = 0.23
	super._ready()

func _perform_melee_attack() -> void:
	_melee_hit(bite_damage_min, bite_damage_max)
