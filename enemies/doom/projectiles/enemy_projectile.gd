class_name EnemyProjectile
extends Node3D

## A slow, dodgeable projectile fired by enemies. Moves in a straight line and hits the first
## thing in its path (wall, player or another monster), using a sphere sweep so fast
## projectiles can't pass through thin walls.

@export var speed: float = 12.0
@export var damage_min: int = 3
@export var damage_max: int = 24
## If > 0, direct hits use Doom's missile formula instead: 1d8 x this (plasma ball: 5, so
## 5, 10 ... 40). damage_min/damage_max are then ignored.
@export var damage_per_roll: int = 0
@export var radius: float = 0.25
@export var lifetime: float = 5.0
@export_flags_3d_physics var collision_mask: int = 1
## Played where the projectile hits (e.g. the rocket's explosion).
@export var impact_sound: AudioStream

@export_group("Explosion")
## Damage at the centre of the blast, falling to 0 at splash_radius. 0 = no explosion.
## Doom rocket: 128 damage over 128 units (~4 m here).
@export var splash_damage: int = 0
@export var splash_radius: float = 4.0

## Optional animated sprite for the projectile (e.g. a fireball). If it has an "impact"
## animation, that plays when the projectile hits something. If it has 8-direction fly
## animations ("fly_front", "fly_front_left", ... "fly_back"), the right one is shown from the
## camera angle relative to the flight direction, like the monsters' sprites.
@onready var sprite: AnimatedSprite3D = get_node_or_null("Sprite") as AnimatedSprite3D

var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null

var _shape := SphereShape3D.new()
var _age: float = 0.0
var _done: bool = false
var _directional: bool = false


## Call right after adding the projectile to the scene tree.
func launch(from: Vector3, toward: Vector3, fired_by: Node3D) -> void:
	global_position = from
	direction = (toward - from).normalized()
	shooter = fired_by
	_update_directional_sprite()


func _ready() -> void:
	_shape.radius = radius
	_directional = sprite != null and sprite.sprite_frames != null \
		and sprite.sprite_frames.has_animation("fly_front")


func _process(_delta: float) -> void:
	_update_directional_sprite()


func _update_directional_sprite() -> void:
	if _done or not _directional:
		return
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var anim := "fly_" + DoomEnemy.view_suffix_for(global_position, direction, camera.global_position)
	if sprite.animation == anim or not sprite.sprite_frames.has_animation(anim):
		return
	# Swap views without restarting the flicker cycle
	var frame := sprite.frame
	var progress := sprite.frame_progress
	sprite.play(anim)
	sprite.set_frame_and_progress(mini(frame, sprite.sprite_frames.get_frame_count(anim) - 1), progress)


func _physics_process(delta: float) -> void:
	if _done:
		return

	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	var motion := direction * speed * delta
	var space := get_world_3d().direct_space_state

	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _shape
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.motion = motion
	params.collision_mask = collision_mask
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		params.exclude = [(shooter as CollisionObject3D).get_rid()]

	# [safe_fraction, unsafe_fraction]; unsafe < 1 means we hit something this frame
	var fractions := space.cast_motion(params)
	if fractions[1] >= 1.0:
		global_position += motion
		return

	global_position += motion * fractions[1]
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.motion = Vector3.ZERO
	var hits := space.intersect_shape(params, 1)
	_impact(hits[0].collider if not hits.is_empty() else null)


func _impact(collider: Object) -> void:
	_done = true
	_play_impact_sound()
	if collider and collider.has_method("take_damage") and not _is_same_species(collider):
		var attacker: Node3D = shooter if is_instance_valid(shooter) else null
		collider.take_damage(_roll_direct_damage(), attacker, global_position)
	if splash_damage > 0:
		_explode(collider)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("impact"):
		sprite.play("impact")
		await sprite.animation_finished
	queue_free()


# The sound gets its own node in the level, so it isn't cut off when the projectile frees itself.
func _play_impact_sound() -> void:
	if not impact_sound:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = impact_sound
	if not Spawner.add_to_level(player, self):
		return
	player.global_position = global_position
	player.finished.connect(player.queue_free)
	player.play()


# Doom: a monster's projectile does no direct damage to its own kind (an Imp's fireball just
# fizzles on another Imp), so they never start infighting with each other. Blasts still hurt.
func _is_same_species(body: Object) -> bool:
	if not is_instance_valid(shooter) or not shooter is DoomEnemy or not body is DoomEnemy:
		return false
	var mine: StringName = (shooter as DoomEnemy).species
	return mine != &"" and mine == (body as DoomEnemy).species

## Damage dealt to whatever the projectile hits directly. Subclasses can override this.
func _roll_direct_damage() -> int:
	if damage_per_roll > 0:
		return randi_range(1, 8) * damage_per_roll
	return randi_range(damage_min, damage_max)


# Doom-style radius damage: everything with take_damage within splash_radius that the blast can
# see gets hurt, falling off linearly with distance. The direct-hit target takes splash too.
# The shooter can hurt itself, unless it's splash_immune (Cyberdemon, Spider Mastermind).
func _explode(direct_hit: Object) -> void:
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = splash_radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = collision_mask
	var attacker: Node3D = shooter if is_instance_valid(shooter) else null

	for hit in space.intersect_shape(params, 32):
		var body := hit.collider as Node3D
		if not body or not body.has_method("take_damage"):
			continue
		if body.get("splash_immune") == true:
			continue
		# The blast is touching whatever it hit directly, so that takes the full amount
		var dist := 0.0 if body == direct_hit else global_position.distance_to(body.global_position)
		var damage := roundi(splash_damage * (1.0 - dist / splash_radius))
		if damage <= 0:
			continue
		# Walls block the blast
		var ray := PhysicsRayQueryParameters3D.create(global_position, body.global_position, collision_mask)
		var blocker := space.intersect_ray(ray)
		if not blocker.is_empty() and blocker.collider != body:
			continue
		body.take_damage(damage, attacker, global_position) # Pushed away from the blast
