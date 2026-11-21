extends DoomEnemy

@export_group("Imp Attacks")
@export var claw_damage_min: int = 3
@export var claw_damage_max: int = 24
@export var fireball_scene: PackedScene = preload("res://enemies/projectiles/imp_fireball.tscn")
## Height above the Imp's feet where the fireball spawns (roughly its hand when throwing)
@export var fireball_spawn_height: float = 1.3

func _ready() -> void:
	max_health = 60
	pain_chance = 0.78 # Doom Imp = 200/256 (~78%)
	has_melee = true
	has_ranged = true
	# Attack: frames E and F wind up (~0.23s each), frame G throws/claws and holds briefly
	windup_time = 0.46
	fire_frame_time = 0.17
	super._ready()

func _perform_melee_attack() -> void:
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= melee_range + 0.5:
		if target.has_method("take_damage"):
			target.take_damage(randi_range(claw_damage_min, claw_damage_max))

func _perform_ranged_attack() -> void:
	if not is_instance_valid(target) or not fireball_scene:
		return
	var fireball := fireball_scene.instantiate() as EnemyProjectile
	get_tree().current_scene.add_child(fireball)
	# Spawn slightly in front of the Imp so it starts clear of its own body, and aim at the
	# target's chest. It flies in a straight line, so moving sideways dodges it.
	var from := global_position + Vector3.UP * fireball_spawn_height + facing_dir * 0.5
	var aim := target.global_position + Vector3.UP * 1.0
	fireball.launch(from, aim, self)
