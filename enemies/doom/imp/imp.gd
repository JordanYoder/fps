class_name DoomImp
extends DoomEnemy

@export_group("Imp Attacks")
@export var claw_damage_min: int = 3
@export var claw_damage_max: int = 24
## Loaded by UID so it survives file moves (imp_fireball.tscn). Override per scene in the Inspector.
@export var fireball_scene: PackedScene = preload("uid://fuj1kol32kfn")
## Height above the Imp's feet where the fireball spawns (roughly its hand when throwing)
@export var fireball_spawn_height: float = 1.3

func _ready() -> void:
	max_health = 60
	pain_chance = 0.78 # Doom Imp = 200/256 (~78%)
	pain_time = 0.11 # 4 tics
	mass = 100.0
	species = &"imp"
	has_melee = true
	has_ranged = true
	# Attack: frames E and F wind up (~0.23s each), frame G throws/claws and holds briefly
	windup_time = 0.46
	fire_frame_time = 0.17
	super._ready()
	_require(fireball_scene, "fireball_scene")

func _perform_melee_attack() -> void:
	_melee_hit(claw_damage_min, claw_damage_max)

func _perform_ranged_attack() -> void:
	if not is_instance_valid(target):
		return
	# Spawn slightly in front of the Imp so it starts clear of its own body, and aim at the
	# target's chest. It flies in a straight line, so moving sideways dodges it.
	var from := _get_feet_position() + Vector3.UP * fireball_spawn_height + facing_dir * 0.5
	var aim := target.global_position + Vector3.UP * 1.0
	_spawn_projectile(fireball_scene, from, aim)
