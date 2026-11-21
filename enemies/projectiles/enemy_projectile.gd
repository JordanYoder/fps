class_name EnemyProjectile
extends Node3D

## A slow, dodgeable projectile fired by enemies. Moves in a straight line and hits the first
## thing in its path (wall, player or another monster), using a sphere sweep so fast
## projectiles can't pass through thin walls.

@export var speed: float = 12.0
@export var damage_min: int = 3
@export var damage_max: int = 24
@export var radius: float = 0.25
@export var lifetime: float = 5.0
@export_flags_3d_physics var collision_mask: int = 1

## Optional animated sprite for the projectile (e.g. a fireball). If it has an "impact"
## animation, that plays when the projectile hits something.
@onready var sprite: AnimatedSprite3D = get_node_or_null("Sprite") as AnimatedSprite3D

var direction: Vector3 = Vector3.FORWARD
var shooter: Node3D = null

var _shape := SphereShape3D.new()
var _age: float = 0.0
var _done: bool = false


## Call right after adding the projectile to the scene tree.
func launch(from: Vector3, toward: Vector3, fired_by: Node3D) -> void:
	global_position = from
	direction = (toward - from).normalized()
	shooter = fired_by


func _ready() -> void:
	_shape.radius = radius


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
	if collider and collider.has_method("take_damage"):
		var attacker: Node3D = shooter if is_instance_valid(shooter) else null
		collider.take_damage(randi_range(damage_min, damage_max), attacker)

	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("impact"):
		sprite.play("impact")
		await sprite.animation_finished
	queue_free()
