extends "res://enemies/shotgun_guy/shotgun_guy.gd"

# The Zombieman is a Shotgun Guy with one bullet instead of three pellets, less health and a
# shorter fire frame. Same hitscan attack and same 3-15 damage per hit.

func _ready() -> void:
	super._ready() # Shotgun Guy defaults first, then override them below
	max_health = 20
	health = max_health # super._ready() already set health from the Shotgun Guy's 30
	pain_chance = 0.78 # Doom Zombieman = 200/256 (~78%)
	pain_time = 0.17 # 6 tics
	mass = 100.0
	species = &"zombieman"
	pellet_count = 1
	# Attack: frame E aims for 10 tics (~0.29s, inherited), frame F fires for 8 tics (~0.23s)
	fire_frame_time = 0.23
