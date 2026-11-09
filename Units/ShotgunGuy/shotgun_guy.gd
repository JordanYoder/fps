extends CharacterBody3D

@export var max_health: int = 30
@export var speed: float = 3.5
@export var attack_range: float = 12.0
@export var damage: int = 8

var health: int
var player: Node3D = null
var is_dead: bool = false
var attack_cooldown: float = false

@onready var anim_sprite: AnimatedSprite3D = $Sprite3D
@onready var attack_ray: RayCast3D = $AttackRay

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	health = max_health
	# Automatically find the player in the main scene group or tree
	player = get_tree().get_first_node_in_group("player")
	if not player:
		# Fallback search by path if group isn't set yet
		player = get_node_or_null("../Player")

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	if player and is_instance_valid(player):
		var distance_to_player := global_position.distance_to(player.global_position)
		var direction := (player.global_position - global_position).normalized()
		direction.y = 0.0 # Stay level on the floor

		if distance_to_player <= attack_range:
			# Stop moving and attack
			velocity.x = move_toward(velocity.x, 0.0, speed * delta)
			velocity.z = move_toward(velocity.z, 0.0, speed * delta)
			
			# Face the player
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
			
			if not attack_cooldown:
				_fire_shotgun()
		else:
			# Chase player
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			look_at(Vector3(player.global_position.x, global_position.y, player.global_position.z), Vector3.UP)
			
			if anim_sprite.animation != "walk":
				anim_sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * delta)

	move_and_slide()

func _fire_shotgun() -> void:
	attack_cooldown = true
	anim_sprite.play("attack")
	
	# Raycast check to damage player
	attack_ray.force_raycast_update()
	if attack_ray.is_colliding():
		var collider := attack_ray.get_collider()
		if collider and collider.has_method("take_damage"):
			collider.take_damage(damage)

	# Cooldown between shotgun bursts (~1.2 seconds)
	await get_tree().create_timer(1.2).timeout
	attack_cooldown = false

# This function links directly with your WeaponManager hitscan loop!
func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	if health <= 0:
		_die()
	else:
		anim_sprite.play("pain")
		# Brief pause on hit before resuming chase
		await get_tree().create_timer(0.25).timeout

func _die() -> void:
	is_dead = true
	anim_sprite.play("death")
	# Disable collision so the player can walk past the corpse
	$CollisionShape3D.set_deferred("disabled", true)
	# Clean up body after 30 seconds to save memory
	get_tree().create_timer(30.0).timeout.connect(queue_free)
