extends DoomImp

# The Baron of Hell attacks like a big Imp: claws up close, throws fireballs from range.
# Only the numbers and the fireball scene differ. Values from Doom.

## baron_fireball.tscn, loaded by UID so it survives file moves
const BARON_FIREBALL := preload("uid://do1ysmwfjgilf")

func _init() -> void:
	# Set before the scene's Inspector values are applied, so a fireball_scene picked in the
	# Inspector still wins over this default
	fireball_scene = BARON_FIREBALL

func _ready() -> void:
	super._ready() # Imp defaults first, then override them below
	max_health = 1000
	health = max_health # super._ready() already set health from the Imp's 60
	pain_chance = 0.2 # Doom Baron = 50/256 (~20%)
	pain_time = 0.11 # 4 tics
	mass = 1000.0
	species = &"baron" # Doom counts Hell Knights as Barons here too
	claw_damage_min = 10
	claw_damage_max = 80
	# Attack: frames E and F wind up (8 tics each, ~0.23s), frame G throws/claws (8 tics)
	windup_time = 0.46
	fire_frame_time = 0.23
	# Taller than the Imp, so the throwing hand is higher (measured from the feet)
	fireball_spawn_height = 1.6
