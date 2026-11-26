extends EnemyProjectile
## The BFG9000's plasma ball, with Doom's damage model:
##
## 1. Direct hit: 1d8 x 100 damage (100, 200 ... 800) to whatever the ball touches.
## 2. Spray (A_BFGSpray): partway through the explosion, 40 invisible tracers fan out across a
##    90 degree arc FROM THE SHOOTER'S CURRENT POSITION, centred on the direction the ball was
##    fired. Each tracer hits the first monster on its line for 15d8 (15-120) damage. One
##    monster can be caught by many tracers, which is where most of the BFG's damage comes from.
##
## So the ball only decides *when* the spray happens; *where* it comes from is the player.
## Walking up to a group before the ball lands lets the spray hit more of them.

@export_group("BFG Spray")
@export var tracer_count: int = 40
@export var spray_arc_degrees: float = 90.0
## Doom: 1024 units (~32 m at this game's 32 units per metre).
@export var spray_range: float = 32.0
## Each tracer hit sums this many 1d8 rolls (Doom: 15, so 15-120 damage).
@export var tracer_damage_rolls: int = 15
## Frame of the "impact" animation the spray fires on. Doom's BFG explosion fires it as the
## third frame (index 2) starts.
@export var spray_frame: int = 2
## Green flash spawned on each monster a tracer hits (Doom's MT_EXTRABFG).
@export var tracer_hit_scene: PackedScene

## Doom's autoaim window: a target counts if any part of it is within this vertical slope
## (100/160, about 32 degrees up or down) of the tracer at that distance.
const AIM_SLOPE := 100.0 / 160.0

var _sprayed := false


func _roll_direct_damage() -> int:
	return randi_range(1, 8) * 100


func _impact(collider: Object) -> void:
	var has_impact_anim := sprite != null and sprite.sprite_frames != null \
		and sprite.sprite_frames.has_animation("impact")
	if has_impact_anim:
		sprite.frame_changed.connect(_on_sprite_frame_changed)
	super._impact(collider) # Direct-hit damage, then starts the "impact" animation
	if not has_impact_anim:
		_spray()
	else:
		_on_sprite_frame_changed() # In case spray_frame is 0 (play() may not emit frame_changed)


func _on_sprite_frame_changed() -> void:
	if sprite.animation == &"impact" and sprite.frame >= spray_frame:
		_spray()


func _spray() -> void:
	if _sprayed:
		return
	_sprayed = true
	if not is_instance_valid(shooter):
		return # Doom ties the spray to the shooter; no shooter, no spray

	var origin := _spray_origin()
	var forward := Vector3(direction.x, 0.0, direction.z)
	if forward.length_squared() < 0.0001: # Fired straight up/down: use the shooter's facing
		forward = -shooter.global_basis.z
		forward.y = 0.0
	forward = forward.normalized()

	var candidates := _find_candidates(origin)
	if candidates.is_empty():
		return
	# Line-of-sight rays should only be stopped by the level, not by monsters or the shooter
	var los_exclude: Array[RID] = []
	if shooter is CollisionObject3D:
		los_exclude.append((shooter as CollisionObject3D).get_rid())
	for c in candidates:
		los_exclude.append((c.body as CollisionObject3D).get_rid())

	var arc := deg_to_rad(spray_arc_degrees)
	for i in tracer_count:
		# Doom: an = angle - ANG90/2 + ANG90/40 * i
		var dir := forward.rotated(Vector3.UP, -arc * 0.5 + arc / tracer_count * i)
		var victim := _aim_tracer(origin, dir, candidates, los_exclude)
		if victim.is_empty():
			continue
		var damage := 0
		for j in tracer_damage_rolls:
			damage += randi_range(1, 8)
		_spawn_tracer_hit(victim.center)
		victim.body.take_damage(damage, shooter)


# Doom fires the tracers from the shooter's eyes. Use the player's Head (where hitscan
# shots start) if there is one.
func _spray_origin() -> Vector3:
	var head := shooter.get_node_or_null("Head") as Node3D
	if head:
		return head.global_position
	return shooter.global_position + Vector3.UP


# Everything damageable within range, with the size of its collision shape so tracers can be
# tested against it. Bodies without a usable CollisionShape3D are skipped.
func _find_candidates(origin: Vector3) -> Array[Dictionary]:
	var sphere := SphereShape3D.new()
	sphere.radius = spray_range
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, origin)
	params.collision_mask = collision_mask
	if shooter is CollisionObject3D:
		params.exclude = [(shooter as CollisionObject3D).get_rid()]

	var result: Array[Dictionary] = []
	var seen := {}
	for hit in get_world_3d().direct_space_state.intersect_shape(params, 256):
		var body := hit.collider as CollisionObject3D
		if not body or seen.has(body) or not body.has_method("take_damage") or _is_dead(body):
			continue
		seen[body] = true
		var shape := _get_collision_shape(body)
		if not shape:
			continue
		var extents := _shape_extents(shape)
		result.append({
			"body": body,
			"center": shape.global_position,
			"radius": extents.x,
			"half_height": extents.y,
		})
	return result


# Doom's P_AimLineAttack: the closest live target the horizontal tracer passes through, that
# is inside the vertical aim window and not behind a wall. Returns {} if nothing.
func _aim_tracer(origin: Vector3, dir: Vector3, candidates: Array[Dictionary],
		los_exclude: Array[RID]) -> Dictionary:
	var best: Dictionary = {}
	var best_dist := INF
	for c in candidates:
		# Re-check every tracer: earlier tracers may have killed it, and Doom's tracers then
		# pass through the corpse to whatever is behind it.
		if not is_instance_valid(c.body) or _is_dead(c.body):
			continue
		var rel: Vector3 = c.center - origin
		var dist := rel.x * dir.x + rel.z * dir.z # Distance along the tracer (top-down)
		if dist <= 0.0 or dist > spray_range or dist >= best_dist:
			continue
		if absf(rel.x * dir.z - rel.z * dir.x) > c.radius: # Tracer passes beside it
			continue
		var top: float = (rel.y + c.half_height) / dist
		var bottom: float = (rel.y - c.half_height) / dist
		if bottom > AIM_SLOPE or top < -AIM_SLOPE:
			continue
		var ray := PhysicsRayQueryParameters3D.create(origin, c.center, collision_mask, los_exclude)
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue # A wall is in the way
		best = c
		best_dist = dist
	return best


func _spawn_tracer_hit(pos: Vector3) -> void:
	if not tracer_hit_scene:
		return
	var flash := tracer_hit_scene.instantiate() as Node3D
	if not Spawner.add_to_level(flash, self):
		return
	flash.global_position = pos


static func _is_dead(body: Object) -> bool:
	return body is DoomEnemy and (body as DoomEnemy).state == DoomEnemy.State.DEAD


static func _get_collision_shape(body: Node) -> CollisionShape3D:
	for child in body.get_children():
		var cs := child as CollisionShape3D
		if cs and cs.shape and not cs.disabled:
			return cs
	return null


# (horizontal radius, half height) of a collision shape in world units
static func _shape_extents(cs: CollisionShape3D) -> Vector2:
	var s := cs.global_basis.get_scale()
	var horizontal := maxf(s.x, s.z)
	if cs.shape is CapsuleShape3D:
		var cap := cs.shape as CapsuleShape3D
		return Vector2(cap.radius * horizontal, cap.height * 0.5 * s.y)
	if cs.shape is CylinderShape3D:
		var cyl := cs.shape as CylinderShape3D
		return Vector2(cyl.radius * horizontal, cyl.height * 0.5 * s.y)
	if cs.shape is BoxShape3D:
		var box := cs.shape as BoxShape3D
		return Vector2(maxf(box.size.x * s.x, box.size.z * s.z) * 0.5, box.size.y * 0.5 * s.y)
	if cs.shape is SphereShape3D:
		var r := (cs.shape as SphereShape3D).radius * maxf(horizontal, s.y)
		return Vector2(r, r)
	return Vector2(0.5, 0.9)
