extends DoomEnemy

@export_group("Shotgun Pellets")
@export var pellet_count: int = 3
@export var pellet_spread_deg: float = 5.6
@export var damage_per_pellet_min: int = 3
@export var damage_per_pellet_max: int = 15

func _ready() -> void:
	max_health = 30
	pain_chance = 0.66
	has_melee = false
	has_ranged = true
	super._ready()

func _perform_ranged_attack() -> void:
	if not is_instance_valid(target):
		return
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 1.2, 0)
	var base_dir := ((target.global_position + Vector3(0, 1.0, 0)) - from).normalized()

	for i in range(pellet_count):
		var spread_rad := deg_to_rad(randf_range(-pellet_spread_deg, pellet_spread_deg))
		var pellet_dir := base_dir.rotated(Vector3.UP, spread_rad)
		var to := from + pellet_dir * max_attack_range

		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [get_rid()]
		var result := space_state.intersect_ray(query)

		if not result.is_empty() and result.collider.has_method("take_damage"):
			var dmg := randi_range(damage_per_pellet_min, damage_per_pellet_max)
			result.collider.take_damage(dmg)
