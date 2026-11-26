extends CharacterBody3D

## Emitted whenever health changes (damage, healing, respawn). HUD scripts listen to this.
signal health_changed(health: int, max_health: int)
## Emitted on every hit that does damage (even the killing one). Used by the red flash.
signal damaged(amount: int)
signal died
## Emitted whenever armor changes (hits, pickups, respawn).
signal armor_changed(armor: int)

@export_group("Movement")
@export var move_speed: float = 10.0
@export var acceleration: float = 60.0
@export var friction: float = 50.0
@export var jump_velocity: float = 4.8
@export var gravity_multiplier: float = 2.2         # Increases overall gravity pull
@export var fall_gravity_multiplier: float = 1.8    # Extra weight only applied when falling

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@export_group("Camera")
@export var mouse_sensitivity: float = 0.002
@export var enable_vertical_look: bool = true

@export_group("Health")
## Starting health, and the cap for normal healing (Doom: 100).
@export var max_health: int = 100
## The cap for "bonus" healing like Doom's health bonuses and Soulsphere (Doom: 200).
@export var overheal_max: int = 200
## Defaults are loaded by UID so they survive file moves (pain.wav / death.wav).
@export var pain_sound: AudioStream = preload("uid://6j11cv4nixx5")
@export var death_sound: AudioStream = preload("uid://c8w6sw7sske2s")
## Minimum time between pain sounds, so a chaingun doesn't turn it into a buzz.
@export var pain_sound_cooldown: float = 0.3
## How far the camera sinks when you die (Doom drops your view to the floor).
@export var death_camera_height: float = 0.3

@export_group("Armor")
## Most armor you can stack with bonuses (Doom: 200).
@export var max_armor: int = 200
@export var start_armor: int = 0

## Doom's armor types: how much of each hit the armor soaks up.
const ARMOR_GREEN := 1.0 / 3.0 # Green armor (100 points) and armor bonuses
const ARMOR_BLUE := 0.5 # Blue armor (200 points)

var health: int = 100
var armor: int = 0
## Share of each hit the current armor absorbs; 0 = no armor.
var armor_absorb: float = 0.0
var is_dead: bool = false
## Set from the debug menu: no damage at all.
var invincible: bool = false
var _pain_sound_timer: float = 0.0
var _voice: AudioStreamPlayer

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/RayCast3D
@onready var weapon_manager: Control = $HUD/WeaponManager

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	weapon_manager.setup(raycast)
	health = max_health
	armor = mini(start_armor, max_armor)
	armor_absorb = ARMOR_GREEN if armor > 0 else 0.0
	_voice = AudioStreamPlayer.new()
	add_child(_voice)
	DebugMenu.add_option("Invincibility", func(on: bool) -> void: invincible = on)
	# Deferred so the HUD is ready
	health_changed.emit.call_deferred(health, max_health)
	armor_changed.emit.call_deferred(armor)

## Called by enemy attacks and projectiles (including your own rocket splash).
func take_damage(amount: int, _attacker: Node3D = null, _inflictor_pos: Vector3 = Vector3.INF) -> void:
	if is_dead or amount <= 0 or invincible:
		return
	# Doom's armor: it soaks up its share of the hit until it runs out
	if armor > 0:
		var saved := int(amount * armor_absorb)
		if saved >= armor:
			saved = armor
			armor_absorb = 0.0 # Used up
		armor -= saved
		amount -= saved
		armor_changed.emit(armor)
	health -= amount
	if DebugMenu.log_damage:
		print("Player took %d damage, %d HP left" % [amount, health])
	damaged.emit(amount)
	if health <= 0:
		health = 0
		health_changed.emit(health, max_health)
		_die()
		return
	health_changed.emit(health, max_health)
	if _pain_sound_timer <= 0.0:
		_play_voice(pain_sound)
		_pain_sound_timer = pain_sound_cooldown

## Adds health up to `limit` (defaults to max_health; pass overheal_max for bonus pickups).
## Returns false if you were already at the limit, so a pickup can stay on the floor.
func heal(amount: int, limit: int = -1) -> bool:
	if is_dead:
		return false
	if limit < 0:
		limit = max_health
	if health >= limit:
		return false
	health = mini(health + amount, limit)
	health_changed.emit(health, max_health)
	return true

## Armor pickups (Doom: green = give_armor(100, ARMOR_GREEN), blue = give_armor(200, ARMOR_BLUE)).
## Sets your armor to `points` if you have less. Returns false if you didn't need it.
func give_armor(points: int, absorb: float) -> bool:
	if is_dead or armor >= points:
		return false
	armor = mini(points, max_armor)
	armor_absorb = absorb
	armor_changed.emit(armor)
	return true

## Armor bonuses: adds on top of what you have, up to max_armor (Doom: +1 each).
## Gives you green armor's protection if you had none.
func add_armor(amount: int) -> bool:
	if is_dead or armor >= max_armor:
		return false
	armor = mini(armor + amount, max_armor)
	if armor_absorb == 0.0:
		armor_absorb = ARMOR_GREEN
	armor_changed.emit(armor)
	return true

func _die() -> void:
	is_dead = true
	_play_voice(death_sound)
	died.emit()
	# Put the gun away and stop all weapon input (firing, switching, wheel)
	weapon_manager.hide()
	weapon_manager.process_mode = Node.PROCESS_MODE_DISABLED
	# Sink the view to the floor with a slight tilt, like falling over
	var tween := create_tween().set_parallel()
	tween.tween_property(head, "position:y", death_camera_height, 0.6) 		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(camera, "rotation:z", deg_to_rad(20.0), 0.6)

func _play_voice(stream: AudioStream) -> void:
	if stream:
		_voice.stream = stream
		_voice.play()
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Dead: press shoot or jump to restart the level (Doom's "press use to respawn")
	if is_dead:
		if event.is_action_pressed("shoot") or event.is_action_pressed("jump"):
			get_tree().reload_current_scene.call_deferred()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if enable_vertical_look:
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

func _physics_process(delta: float) -> void:
	_pain_sound_timer -= delta
	if not is_on_floor():
		var current_gravity := gravity * gravity_multiplier
		
		# If the player is moving downward (past the peak of the jump), increase gravity
		if velocity.y < 0:
			current_gravity *= fall_gravity_multiplier
			
		velocity.y -= current_gravity * delta

	if is_dead:
		# No control while dead: just slide to a stop and keep falling
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	if wish_dir:
		velocity.x = move_toward(velocity.x, wish_dir.x * move_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, wish_dir.z * move_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	move_and_slide()

	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	weapon_manager.update_bob(delta, horiz_speed, is_on_floor())

	if Input.is_action_pressed("shoot"):
		weapon_manager.try_fire()
