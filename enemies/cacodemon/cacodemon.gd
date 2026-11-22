extends DoomEnemy

# The Cacodemon floats, bites up close and spits fireballs from range. Values from Doom.

const CACODEMON_FIREBALL_PATH := "res://enemies/projectiles/cacodemon_fireball.tscn"

@export_group("Cacodemon Attacks")
## Doom bite: (1..10) * 10
@export var bite_damage_min: int = 10
@export var bite_damage_max: int = 100
@export var fireball_scene: PackedScene
## Height above the Cacodemon's feet where the fireball spawns (its mouth). The open mouth on
## the spit frame (D) is centred ~24px up from the sprite's bottom, which sits on the feet.
@export var fireball_spawn_height: float = 0.7

func _ready() -> void:
	max_health = 400
	pain_chance = 0.5 # Doom Cacodemon = 128/256 (50%)
	speed = 3.5 # Same move speed as the Imp in Doom
	can_fly = true
	has_melee = true
	has_ranged = true
	# Its body is wide and it hovers above the player's feet, so it needs more reach than
	# the default to bite (melee range is measured centre to centre, including height)
	melee_range = 3.0
	# Attack: frames B and C wind up (5 tics each, ~0.14s), frame D bites/spits (5 tics)
	windup_time = 0.29
	fire_frame_time = 0.14

	if not fireball_scene:
		if ResourceLoader.exists(CACODEMON_FIREBALL_PATH):
			fireball_scene = load(CACODEMON_FIREBALL_PATH)
		else:
			push_warning("Cacodemon: %s not found, spitting Imp fireballs instead" % CACODEMON_FIREBALL_PATH)
			fireball_scene = load("res://enemies/projectiles/imp_fireball.tscn")
	super._ready()

func _perform_melee_attack() -> void:
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= melee_range + 0.5:
		if target.has_method("take_damage"):
			target.take_damage(randi_range(bite_damage_min, bite_damage_max))

func _perform_ranged_attack() -> void:
	if not is_instance_valid(target) or not fireball_scene:
		return
	var fireball := fireball_scene.instantiate() as EnemyProjectile
	get_tree().current_scene.add_child(fireball)
	var mouth := _get_feet_position() + Vector3.UP * fireball_spawn_height
	var aim := target.global_position + Vector3.UP * 1.0
	# Push the spawn point forward along the mouth->target line (not horizontally) so it starts
	# in front of the flat sprite but still lines up with the mouth from the player's view.
	# A horizontal push looks too high whenever the Cacodemon is above the player (parallax).
	var to_aim := aim - mouth
	# Never push past the target, or the fireball would launch backwards
	var from := mouth + to_aim.normalized() * minf(1.1, to_aim.length() * 0.5)
	fireball.launch(from, aim, self)
