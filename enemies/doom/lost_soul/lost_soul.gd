extends DoomEnemy

# The Lost Soul: a flying flaming skull that charges straight at its target and bites on
# impact. Getting hurt mid-charge stops it dead (it always flinches). Values from Doom.

@export_group("Lost Soul Charge")
## Doom: (1..8) * 3
@export var charge_damage_min: int = 3
@export var charge_damage_max: int = 24
## Doom charges at 20 units/tic (~26 m/s at this game's scale); a bit slower is easier to read.
@export var charge_speed: float = 20.0
## Gives up if it hasn't hit anything after this long
@export var max_charge_time: float = 1.5

var _charging: bool = false
var _charge_velocity: Vector3 = Vector3.ZERO
var _charge_timer: float = 0.0

func _ready() -> void:
	max_health = 100
	pain_chance = 1.0 # Doom Lost Soul = 256/256: every hit stuns it
	pain_time = 0.17 # 6 tics
	mass = 50.0 # The lightest monster: hits knock it far
	species = &"lost_soul"
	speed = 3.5 # Doom Lost Soul speed 8, same as the Imp
	can_fly = true
	leaves_no_corpse = true # Bursts into flame and is gone, like Doom
	has_melee = false
	has_ranged = true # The charge counts as its ranged attack
	# Doom halves the distance for the Lost Soul's attack check, so it charges more eagerly
	max_attack_range = 30.0
	# Attack: frame C aims (10 tics), frame D launches the charge
	windup_time = 0.29
	fire_frame_time = 0.11
	super._ready()

func _perform_ranged_attack() -> void:
	if not is_instance_valid(target):
		return
	var from := collision_shape.global_position if collision_shape else global_position
	var aim := target.global_position + Vector3.UP * 1.0
	_charge_velocity = (aim - from).normalized() * charge_speed
	_charge_timer = 0.0
	_charging = true
	# Take over from the base attack sequence: the charge ends when it hits something instead
	state_token += 1
	state = State.ATTACK
	# Hold the charging frame (D) for the whole flight
	if anim_sprite:
		anim_sprite.pause()

func _physics_process(delta: float) -> void:
	if not _charging:
		super._physics_process(delta)
		return
	if state == State.DEAD:
		_charging = false
		return

	_charge_timer += delta
	var collision := move_and_collide(_charge_velocity * delta)
	if collision:
		var hit := collision.get_collider()
		if hit and hit.has_method("take_damage"):
			hit.take_damage(randi_range(charge_damage_min, charge_damage_max), self)
		_end_charge()
	elif _charge_timer >= max_charge_time:
		_end_charge()

func _end_charge() -> void:
	if not _charging:
		return
	_charging = false
	_charge_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	if state == State.DEAD:
		return
	state_token += 1
	reaction_cooldown = post_attack_cooldown
	state = State.CHASE
	_pick_new_chase_dir()
	_play_anim("walk")

func take_damage(amount: int, attacker: Node3D = null, inflictor_pos: Vector3 = Vector3.INF) -> void:
	# Doom stops a charging Lost Soul in its tracks when it's hurt
	if _charging and state != State.DEAD:
		_end_charge()
	super.take_damage(amount, attacker, inflictor_pos)
