extends DoomEnemy

# The Cyberdemon: a huge, slow-to-flinch boss that fires three rockets per attack.
# Immune to explosions, so its own rockets can't hurt it. Values from Doom.

const CYBERDEMON_ROCKET_PATH := "res://enemies/projectiles/cyberdemon_rocket.tscn"

@export_group("Cyberdemon Attack")
@export var rocket_scene: PackedScene
## Height above the feet where rockets spawn (the arm cannon). The cannon on the firing
## frame (F) sits about 65px up the 110px sprite.
@export var rocket_spawn_height: float = 2.0

func _ready() -> void:
	max_health = 4000
	pain_chance = 0.08 # Doom Cyberdemon = 20/256 (~8%)
	speed = 7.0 # Doom Cyberdemon speed 16 vs Imp's 8
	has_melee = false
	has_ranged = true
	splash_immune = true
	# Doom never limits the Cyberdemon's range; it just gets less likely to fire far away
	max_attack_range = 40.0
	sight_range = 40.0
	# Attack: E aims (6 tics) -> F fires (12) -> E (12) -> F fires (12) -> E (12) -> F fires (12)
	attack_shots = 3
	windup_time = 0.17
	refire_windup_time = 0.34
	fire_frame_time = 0.34

	if not rocket_scene:
		if ResourceLoader.exists(CYBERDEMON_ROCKET_PATH):
			rocket_scene = load(CYBERDEMON_ROCKET_PATH)
		else:
			push_warning("Cyberdemon: %s not found, firing Baron fireballs instead" % CYBERDEMON_ROCKET_PATH)
			rocket_scene = load("res://enemies/projectiles/baron_fireball.tscn")
	super._ready()

func _perform_ranged_attack() -> void:
	if not is_instance_valid(target) or not rocket_scene:
		return
	var rocket := rocket_scene.instantiate() as EnemyProjectile
	get_tree().current_scene.add_child(rocket)
	var cannon := _get_feet_position() + Vector3.UP * rocket_spawn_height
	var aim := target.global_position + Vector3.UP * 1.0
	# Start the rocket outside the Cyberdemon's wide body, along the cannon->target line so it
	# still lines up with the cannon from the player's view (same trick as the Cacodemon)
	var to_aim := aim - cannon
	var from := cannon + to_aim.normalized() * minf(_get_body_radius() + 0.4, to_aim.length() * 0.5)
	rocket.launch(from, aim, self)
