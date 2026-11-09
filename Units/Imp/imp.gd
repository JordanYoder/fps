extends CharacterBody3D

@export var move_speed: float = 4.0
@export var max_health: int = 60
@export var sight_range: float = 15.0
@export var stop_distance: float = 1.8
@export var hurt_duration: float = 0.2
@export var floor_sink_pixels: float = 3.5

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

enum State { IDLE, CHASE, HURT, DEAD }
var current_state: State = State.IDLE
var health: int
var hurt_timer: float = 0.0
var player: Node3D = null

func _ready() -> void:
	health = max_health
	player = get_tree().get_first_node_in_group("player")
	sprite.frame_changed.connect(_align_sprite_to_floor)
	sprite.animation_changed.connect(_align_sprite_to_floor)
	play_idle_animation()
	_align_sprite_to_floor()
	
	if has_node("FacingIndicator"):
		$FacingIndicator.hide()

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if not is_instance_valid(player):
		move_and_slide()
		return

	match current_state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			if _can_see_player():
				current_state = State.CHASE
				play_walk_animation()

		State.HURT:
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
			hurt_timer -= delta
			if hurt_timer <= 0.0:
				sprite.modulate = Color.WHITE
				current_state = State.CHASE
				play_walk_animation()

		State.CHASE:
			var to_player := player.global_position - global_position
			to_player.y = 0.0
			var distance := to_player.length()

			if distance > stop_distance:
				var dir := to_player.normalized()
				velocity.x = dir.x * move_speed
				velocity.z = dir.z * move_speed
				look_at(global_position + dir, Vector3.UP)
			else:
				velocity.x = 0.0
				velocity.z = 0.0

	move_and_slide()

func _can_see_player() -> bool:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > sight_range:
		return false

	# Cast a ray directly in physics space from Imp's chest to Player's chest
	# (Automatically ignores the Imp's own collision capsule via [self.get_rid()])
	var space_state := get_world_3d().direct_space_state
	var from := global_position + Vector3(0.0, 1.0, 0.0)
	var to := player.global_position + Vector3(0.0, 1.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, [self.get_rid()])
	var result := space_state.intersect_ray(query)

	return not result.is_empty() and result["collider"] == player

func take_damage(amount: int) -> void:
	if current_state == State.DEAD:
		return

	health -= amount
	if health <= 0:
		die()
	else:
		enter_hurt_state()

func enter_hurt_state() -> void:
	current_state = State.HURT
	hurt_timer = hurt_duration
	sprite.modulate = Color(1.0, 0.4, 0.4)
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")

func die() -> void:
	current_state = State.DEAD
	velocity = Vector3.ZERO
	sprite.modulate = Color.WHITE
	if sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
	collision_shape.set_deferred("disabled", true)

func play_idle_animation() -> void:
	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
	elif sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
		sprite.stop() # Holds cleanly on frame 0 (standing pose) until woken up
	elif sprite.sprite_frames.has_animation("default"):
		sprite.play("default")
		sprite.stop()

func play_walk_animation() -> void:
	if sprite.sprite_frames.has_animation("walk"):
		sprite.play("walk")
	elif sprite.sprite_frames.has_animation("default"):
		sprite.play("default")

func _align_sprite_to_floor() -> void:
	var tex := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if tex:
		sprite.offset.y = (tex.get_height() * 0.5) - floor_sink_pixels
