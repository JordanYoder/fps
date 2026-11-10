class_name DoomEnemy
extends CharacterBody3D

enum State { IDLE, CHASE, ATTACK, PAIN, DEAD }

@export_group("Doom Stats")
@export var max_health: int = 30
@export var speed: float = 3.5
@export var sight_range: float = 25.0
@export_range(0.0, 1.0) var pain_chance: float = 0.66

@export_group("Combat Ranges")
@export var has_melee: bool = false
@export var melee_range: float = 2.2
@export var has_ranged: bool = true
@export var max_attack_range: float = 20.0
@export var windup_time: float = 0.3
@export var fire_frame_time: float = 0.3
@export var post_attack_cooldown: float = 0.6

var state: State = State.IDLE
var health: int = 30
var target: Node3D = null

var move_dir: Vector3 = Vector3.ZERO
var move_timer: float = 0.0
var attack_check_timer: float = 0.0
var reaction_cooldown: float = 0.0
var state_token: int = 0

var current_base_anim: String = ""

@onready var anim_sprite: AnimatedSprite3D = get_node_or_null("Sprite3D") as AnimatedSprite3D
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

const DIRS_8: Array[Vector3] = [
	Vector3(1, 0, 0),
	Vector3(0.7071, 0, 0.7071),
	Vector3(0, 0, 1),
	Vector3(-0.7071, 0, 0.7071),
	Vector3(-1, 0, 0),
	Vector3(-0.7071, 0, -0.7071),
	Vector3(0, 0, -1),
	Vector3(0.7071, 0, -0.7071)
]

func _ready() -> void:
	health = max_health
	if not anim_sprite:
		anim_sprite = find_child("*", true, false) as AnimatedSprite3D
	if not collision_shape:
		collision_shape = find_child("*", true, false) as CollisionShape3D

	target = get_tree().get_first_node_in_group("player")
	if not target:
		target = get_node_or_null("../Player")

	if anim_sprite:
		# Ensure consistent pivot behavior across Imp and ShotgunGuy
		anim_sprite.centered = true
		anim_sprite.offset = Vector2.ZERO
		anim_sprite.frame_changed.connect(_align_sprite_to_floor)
		anim_sprite.animation_changed.connect(_align_sprite_to_floor)
		if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
			play_safe_anim("idle")
		_align_sprite_to_floor()

func _align_sprite_to_floor() -> void:
	if not anim_sprite or not anim_sprite.sprite_frames:
		return
	var tex := anim_sprite.sprite_frames.get_frame_texture(anim_sprite.animation, anim_sprite.frame)
	if not tex:
		return

	# Find the exact bottom Y of the CollisionShape3D in local space
	var floor_y: float = 0.0
	if collision_shape and collision_shape.shape:
		var shape_height: float = 1.8
		if "height" in collision_shape.shape:
			shape_height = collision_shape.shape.height * collision_shape.scale.y
		elif "size" in collision_shape.shape:
			shape_height = collision_shape.shape.size.y * collision_shape.scale.y
		floor_y = collision_shape.position.y - (shape_height * 0.5)

	var sprite_world_height := tex.get_height() * anim_sprite.pixel_size * anim_sprite.scale.y
	anim_sprite.position.y = floor_y + (sprite_world_height * 0.5)

func _physics_process(delta: float) -> void:
	
	if state == State.DEAD:
		return
		
	if not is_on_floor():
		velocity.y -= gravity * delta

	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0.0, speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 4.0 * delta)
		move_and_slide()
		return

	if reaction_cooldown > 0.0:
		reaction_cooldown -= delta

	match state:
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0
			_look_for_player()
		State.CHASE:
			_process_chase(delta)
		State.ATTACK, State.PAIN:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()
		
	# Constantly update the sprite angle relative to the player
	if state != State.DEAD:
		_update_directional_sprite()

# Safe wrapper to prevent playing empty animation strings (which throws the C++ error)
func play_safe_anim(anim_name: String) -> void:
	current_base_anim = anim_name
	_update_directional_sprite()
	if not anim_sprite or not anim_sprite.sprite_frames:
		return
	
	if anim_name.is_empty():
		print("WARNING: Tried to play an empty animation name on ", name)
		return
		
	if anim_sprite.sprite_frames.has_animation(anim_name):
		if anim_sprite.animation != anim_name:
			anim_sprite.play(anim_name)
	else:
		print("WARNING: Animation '", anim_name, "' does not exist in SpriteFrames for ", name)

func _look_for_player() -> void:
	if not is_instance_valid(target):
		return
	if global_position.distance_to(target.global_position) <= sight_range and _has_line_of_sight():
		_wake_up()

func _wake_up() -> void:
	if state == State.IDLE:
		state = State.CHASE
		_pick_new_chase_dir()
		if anim_sprite:
			play_safe_anim("walk")

func _process_chase(delta: float) -> void:
	if not is_instance_valid(target):
		return

	# Don't overwrite higher-priority state animations (like pain, attack, or death) with walk
	if anim_sprite and state == State.CHASE:
		if anim_sprite.animation != "walk":
			play_safe_anim("walk")

	var dist := global_position.distance_to(target.global_position)

	# Immediate melee check if within scratch range
	if has_melee and dist <= melee_range and _has_line_of_sight():
		_start_attack(true)
		return

	move_timer -= delta
	attack_check_timer -= delta

	if is_on_wall() or move_timer <= 0.0:
		_pick_new_chase_dir()

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed

	if has_ranged and attack_check_timer <= 0.0:
		attack_check_timer = 0.25
		if reaction_cooldown <= 0.0 and _should_ranged_attack(dist):
			_start_attack(false)

func _pick_new_chase_dir() -> void:
	if not is_instance_valid(target):
		return

	var dx := target.global_position.x - global_position.x
	var dz := target.global_position.z - global_position.z
	var old_dir := move_dir
	var turnaround := -old_dir

	# 1. Determine X and Z cardinal components (with a small ~0.3m deadzone like Doom's 10 map units)
	var dir_x := Vector3.ZERO
	if dx > 0.3:
		dir_x = Vector3(1, 0, 0)
	elif dx < -0.3:
		dir_x = Vector3(-1, 0, 0)

	var dir_z := Vector3.ZERO
	if dz > 0.3:
		dir_z = Vector3(0, 0, 1)
	elif dz < -0.3:
		dir_z = Vector3(0, 0, -1)

	# 2. Try exact diagonal first if offset on both axes
	if dir_x != Vector3.ZERO and dir_z != Vector3.ZERO:
		var diag := (dir_x + dir_z).normalized()
		if diag.dot(turnaround) < 0.9 and not _is_dir_blocked(diag):
			move_dir = diag
			move_timer = randi_range(0, 15) * 0.085 # 0-15 steps at ~3 tics per step
			return

	# 3. Try cardinal axes (prioritize larger delta, or ~21.5% chance to swap like P_Random() > 200)
	var primary := dir_x
	var secondary := dir_z
	if abs(dz) > abs(dx) or randf() < 0.215:
		primary = dir_z
		secondary = dir_x

	if primary != Vector3.ZERO and primary.dot(turnaround) < 0.9 and not _is_dir_blocked(primary):
		move_dir = primary
		move_timer = randi_range(0, 15) * 0.085
		return

	if secondary != Vector3.ZERO and secondary.dot(turnaround) < 0.9 and not _is_dir_blocked(secondary):
		move_dir = secondary
		move_timer = randi_range(0, 15) * 0.085
		return

	# 4. Try continuing old direction
	if old_dir != Vector3.ZERO and not _is_dir_blocked(old_dir):
		move_dir = old_dir
		move_timer = randi_range(0, 15) * 0.085
		return

	# 5. Sweep all 8 directions in normal or reverse order (50/50 chance)
	var sweep := DIRS_8.duplicate()
	if randi() & 1:
		sweep.reverse()
	for d in sweep:
		if d.dot(turnaround) < 0.9 and not _is_dir_blocked(d):
			move_dir = d
			move_timer = randi_range(0, 15) * 0.085
			return

	# 6. Last resort: allow 180-degree turnaround
	if turnaround != Vector3.ZERO and not _is_dir_blocked(turnaround):
		move_dir = turnaround
		move_timer = randi_range(0, 15) * 0.085
		return

	move_dir = Vector3.ZERO
	move_timer = 0.25	# --- TEMPORARY TEST CODE START ---
	move_dir = Vector3(1, 0, 0) # Force movement strictly along the positive X-axis
	move_timer = 999.0
	return
	# --- TEMPORARY TEST CODE END ---
	if not is_instance_valid(target):
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return
	to_target = to_target.normalized()

	var valid_dirs: Array[Vector3] = []
	var opposite_dir := -move_dir

	for d in DIRS_8:
		if d.dot(opposite_dir) > 0.9:
			continue
		if d.dot(to_target) > 0.15 and not _is_dir_blocked(d):
			valid_dirs.append(d)

	if valid_dirs.is_empty():
		for d in DIRS_8:
			if not _is_dir_blocked(d):
				valid_dirs.append(d)

	move_dir = valid_dirs.pick_random() if not valid_dirs.is_empty() else to_target
	move_timer = randf_range(0.45, 1.1)

func _is_dir_blocked(dir: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	var from := collision_shape.global_position if collision_shape else global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 1.5)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	return not result.is_empty() and result.collider != target

func _should_ranged_attack(dist: float) -> bool:
	if dist > max_attack_range or not _has_line_of_sight():
		return false
	var attack_prob := clampf(1.0 - (dist / max_attack_range), 0.15, 0.85)
	return randf() < attack_prob

func _has_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var space_state := get_world_3d().direct_space_state
	var from := collision_shape.global_position if collision_shape else global_position
	var to := target.global_position + Vector3(0, 0.5, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	return not result.is_empty() and result.collider == target

func _start_attack(is_melee: bool) -> void:
	state = State.ATTACK
	state_token += 1
	var my_token := state_token

	if anim_sprite:
		play_safe_anim("attack")
		anim_sprite.frame = 0
		anim_sprite.pause()

	await get_tree().create_timer(windup_time).timeout
	if state_token != my_token or state == State.DEAD:
		return

	if anim_sprite and anim_sprite.sprite_frames.get_frame_count("attack") > 1:
		anim_sprite.frame = 1

	# Calls the child monster's custom attack implementation
	if is_melee:
		_perform_melee_attack()
	else:
		_perform_ranged_attack()

	await get_tree().create_timer(fire_frame_time).timeout
	if state_token != my_token or state == State.DEAD:
		return

	reaction_cooldown = post_attack_cooldown
	state = State.CHASE
	_pick_new_chase_dir()
	if anim_sprite:
		anim_sprite.play("walk")

# Virtual methods to be overridden by ShotgunGuy, Imp, etc.
func _perform_melee_attack() -> void:
	pass

func _perform_ranged_attack() -> void:
	pass

func take_damage(amount: int, attacker: Node3D = null) -> void:
	print(name, " took ", amount, " damage! Remaining HP: ", health - amount)
	if state == State.DEAD:
		return

	health -= amount

	# Optional Doom Infighting: switch target if hit by another monster
	if is_instance_valid(attacker) and attacker != self:
		target = attacker

	if state == State.IDLE:
		_wake_up()

	if health <= 0:
		_die()
		return

	if randf() <= pain_chance:
		state = State.PAIN
		state_token += 1
		var my_token := state_token
		if anim_sprite:
			play_safe_anim("pain")

		await get_tree().create_timer(0.25).timeout
		if state_token != my_token or state == State.DEAD:
			return

		reaction_cooldown = 0.0
		state = State.CHASE
		_pick_new_chase_dir()
func _die() -> void:
	state = State.DEAD
	state_token += 1
	velocity = Vector3.ZERO
	if anim_sprite:
		play_safe_anim("death")
		_align_sprite_to_floor()
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	get_tree().create_timer(30.0).timeout.connect(queue_free)
	
func _get_angle_suffix() -> String:
	if not is_instance_valid(target):
		return "1"

	# Flat vector from enemy to player
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	to_player = to_player.normalized()

	# Flat vector of where the enemy is facing/moving
	var forward := move_dir
	if forward.length_squared() < 0.01:
		# If standing still, assume they are facing the player
		forward = to_player 

	# Calculate the angle between where they are looking and where the player is
	var angle := forward.signed_angle_to(to_player, Vector3.UP)
	var octant := int(round(angle / (PI / 4.0)))

	# Map Godot's signed radian octants to Doom's 1-8 sprite numbering
	match octant:
		0: return "1"       # Front
		1: return "2"       # Front-Left
		2: return "3"       # Left
		3: return "4"       # Back-Left
		4, -4: return "5"   # Back
		-3: return "6"      # Back-Right
		-2: return "7"      # Right
		-1: return "8"      # Front-Right
		_: return "1"

func _update_directional_sprite() -> void:
	if not anim_sprite or current_base_anim.is_empty():
		return
		
	var to_player := target.global_position - global_position
	to_player.y = 0.0
	to_player = to_player.normalized()

	var forward := move_dir
	if forward.length_squared() < 0.01:
		forward = to_player 

	# Calculate the angle between where they are looking and where the player is
	var angle := forward.signed_angle_to(to_player, Vector3.UP)
	var octant := int(round(angle / (PI / 4.0)))

	var suffix := "1"
	var flip := false

	# Map Godot's signed radian octants to Doom's 1-5 sprite definitions
	match octant:
		0: 
			suffix = "1" # Front
		1: 
			suffix = "2" # Front-Left
		2: 
			suffix = "3" # Left
		3: 
			suffix = "4" # Back-Left
		4, -4: 
			suffix = "5" # Back
		-3: 
			suffix = "4" # Back-Right (Uses Back-Left, mirrored)
			flip = true
		-2: 
			suffix = "3" # Right (Uses Left, mirrored)
			flip = true
		-1: 
			suffix = "2" # Front-Right (Uses Front-Left, mirrored)
			flip = true

	var target_anim := current_base_anim
	var directional_anim = current_base_anim + "_" + suffix

	# Check if we have 8-way directional frames for this state
	if anim_sprite.sprite_frames.has_animation(directional_anim):
		target_anim = directional_anim
		anim_sprite.flip_h = flip
	else:
		# Fallback for 1-way animations like "pain" or "death"
		anim_sprite.flip_h = false

	# Apply the animation seamlessly without restarting the frame counter
	if anim_sprite.animation != target_anim:
		var current_frame = anim_sprite.frame
		var current_progress = anim_sprite.frame_progress
		
		anim_sprite.play(target_anim)
		
		# Sync the walk cycle legs across directional transitions
		if anim_sprite.sprite_frames.get_frame_count(target_anim) > current_frame:
			anim_sprite.frame = current_frame
			anim_sprite.frame_progress = current_progress
