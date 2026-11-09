extends DoomEnemy

@export_group("Imp Attacks")
@export var claw_damage_min: int = 3
@export var claw_damage_max: int = 24

func _ready() -> void:
	max_health = 60
	pain_chance = 0.78 # Doom Imp = 200/256 (~78%)
	has_melee = true
	has_ranged = true
	super._ready()

func _perform_melee_attack() -> void:
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= melee_range + 0.5:
		if target.has_method("take_damage"):
			target.take_damage(randi_range(claw_damage_min, claw_damage_max))

func _perform_ranged_attack() -> void:
	if is_instance_valid(target) and _has_line_of_sight():
		if target.has_method("take_damage"):
			target.take_damage(randi_range(claw_damage_min, claw_damage_max))
