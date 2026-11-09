extends CharacterBody3D

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

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/RayCast3D
@onready var weapon_manager: Control = $HUD/WeaponManager
@onready var weapon_holder_3d: Node3D = get_node_or_null("Head/Camera3D/WeaponHolder3D")

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	weapon_manager.setup(raycast, weapon_holder_3d)
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		if enable_vertical_look:
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, deg_to_rad(-80.0), deg_to_rad(80.0))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		var current_gravity := gravity * gravity_multiplier
		
		# If the player is moving downward (past the peak of the jump), increase gravity
		if velocity.y < 0:
			current_gravity *= fall_gravity_multiplier
			
		velocity.y -= current_gravity * delta

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
