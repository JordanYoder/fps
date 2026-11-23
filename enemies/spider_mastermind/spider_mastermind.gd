extends "res://enemies/shotgun_guy/shotgun_guy.gd"

# The Spider Mastermind: a giant brain on legs with a chaingun. It keeps firing for as long as
# it can see its target, so break line of sight to make it stop. Immune to explosions.
# Values from Doom.

func _ready() -> void:
	super._ready() # Shotgun Guy defaults first, then override them below
	max_health = 3000
	health = max_health # super._ready() already set health from the Shotgun Guy's 30
	pain_chance = 0.16 # Doom Spider Mastermind = 40/256 (~16%)
	speed = 5.25 # Doom Spider speed 12 vs Imp's 8
	splash_immune = true
	max_attack_range = 40.0
	sight_range = 40.0
	# The gun sits low in the middle of the body
	gun_height = 1.4
	# Doom fires 3 pellets on both G and H (4 tics each). Here only the last frame fires,
	# so each G->H cycle fires 6 pellets: same damage per second.
	pellet_count = 6
	# Attack: G aims for 20 tics, then G/H fire back and forth (4 tics each) until it loses you
	windup_time = 0.57
	refire_windup_time = 0.11
	fire_frame_time = 0.11

# Doom's A_SpidRefire: keep shooting while the target is visible. Even without sight it
# has a 10/256 chance per burst to fire one more blind.
func _should_refire(_shots_fired: int) -> bool:
	if not is_instance_valid(target):
		return false
	if target.get("health") is int and target.get("health") <= 0:
		return false
	return _has_line_of_sight() or randf() < 10.0 / 256.0
