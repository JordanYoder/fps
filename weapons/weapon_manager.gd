extends Control

@export var weapons: Array[WeaponData] = []
@export var weapon_scale: float = 4.5
@export var wall_decal_scene: PackedScene
@export var blood_splatter_scene: PackedScene

@export_group("Weapon Switching")
## How far (in the weapon's 320x200 screen pixels) the weapon drops off screen when switching.
@export var switch_lower_distance: float = 120.0
## Lower/raise speed in those pixels per second. Like Doom, a switch can't start mid-shot and
## you can't fire until the new weapon is fully raised, so switching can't beat the fire rate.
@export var switch_speed: float = 270.0

@onready var weapon_sprite: AnimatedSprite2D = $WeaponSprite
@onready var muzzle_flash: AnimatedSprite2D = $MuzzleFlash

var current_weapon: WeaponData
var current_index: int = 0
var can_shoot: bool = true
var bob_time: float = 0.0
var raycast: RayCast3D

enum SwitchState { READY, LOWERING, RAISING }
var switch_state: SwitchState = SwitchState.READY
var pending_index: int = -1 # Weapon waiting to be switched to, -1 = none
var switch_offset: float = 0.0 # How far the weapon is currently lowered
var _bob_pos: Vector2 # Smoothed position without the switch offset

func _ready() -> void:
	_bob_pos = position
	weapon_sprite.frame_changed.connect(_align_weapon_sprite)
	weapon_sprite.animation_changed.connect(_align_weapon_sprite)
	weapon_sprite.animation_finished.connect(_on_weapon_animation_finished)
	muzzle_flash.frame_changed.connect(_align_muzzle_flash)
	muzzle_flash.animation_finished.connect(_on_muzzle_flash_finished)

func setup(player_raycast: RayCast3D) -> void:
	raycast = player_raycast
	if not weapons.is_empty():
		equip_weapon(0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var slot: int = event.keycode - KEY_1
		if slot >= 0 and slot < weapons.size():
			request_switch(slot)

# The wheel is read in _input, not _unhandled_input: the captured mouse sits at the screen centre,
# right over the crosshair, and HUD Controls there could otherwise swallow wheel events.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_weapon(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_weapon(-1)

# Steps to the next (step = 1) or previous (step = -1) weapon, wrapping around and skipping
# empty slots.
func _cycle_weapon(step: int) -> void:
	if weapons.is_empty():
		return
	# Keep scrolling from the weapon already queued, so several wheel clicks skip ahead
	var index := pending_index if pending_index != -1 else current_index
	for i in weapons.size():
		index = posmod(index + step, weapons.size())
		if weapons[index] != null:
			request_switch(index)
			return

# Queues a switch; the current weapon lowers (once it's done firing), then the new one raises.
func request_switch(index: int) -> void:
	if index < 0 or index >= weapons.size() or weapons[index] == null:
		return
	if index == current_index:
		# Changed our mind before the old weapon got swapped out: bring it back up
		pending_index = -1
		if switch_state == SwitchState.LOWERING:
			switch_state = SwitchState.RAISING
		return
	pending_index = index

func _process(delta: float) -> void:
	match switch_state:
		SwitchState.READY, SwitchState.RAISING:
			# Start lowering once the current shot has finished
			if pending_index != -1 and can_shoot:
				switch_state = SwitchState.LOWERING
			elif switch_state == SwitchState.RAISING:
				switch_offset -= switch_speed * delta
				if switch_offset <= 0.0:
					switch_offset = 0.0
					switch_state = SwitchState.READY
		SwitchState.LOWERING:
			switch_offset += switch_speed * delta
			if switch_offset >= switch_lower_distance:
				switch_offset = switch_lower_distance
				equip_weapon(pending_index)
				pending_index = -1
				switch_state = SwitchState.RAISING

func equip_weapon(index: int) -> void:
	if index < 0 or index >= weapons.size() or weapons[index] == null:
		return

	current_index = index
	current_weapon = weapons[index]
	can_shoot = true
	muzzle_flash.visible = false

	weapon_sprite.visible = true
	weapon_sprite.sprite_frames = current_weapon.weapon_frames
	if current_weapon.muzzle_flash_frames:
		muzzle_flash.sprite_frames = current_weapon.muzzle_flash_frames
	weapon_sprite.play("idle")
	_align_weapon_sprite()

func try_fire() -> void:
	if not can_shoot or switch_state != SwitchState.READY or not current_weapon or not raycast:
		return

	can_shoot = false

	weapon_sprite.play("shoot")
	if current_weapon.muzzle_flash_frames:
		muzzle_flash.visible = true
		muzzle_flash.play("flash")
		_align_muzzle_flash()

	# Hitscan Raycast Loop
	for i in range(current_weapon.pellet_count):
		var spread_x := deg_to_rad(randf_range(-current_weapon.spread_degrees, current_weapon.spread_degrees))
		var spread_y := deg_to_rad(randf_range(-current_weapon.spread_degrees * 0.35, current_weapon.spread_degrees * 0.35))
		raycast.rotation = Vector3(spread_y, spread_x, 0.0)
		raycast.force_raycast_update()

		if raycast.is_colliding():
			var collider := raycast.get_collider()
			var hit_pos := raycast.get_collision_point()
			var hit_normal := raycast.get_collision_normal()

			if collider.has_method("take_damage"):
				collider.take_damage(current_weapon.damage_per_pellet)
				_spawn_blood(hit_pos)
			else:
				_spawn_wall_decal(hit_pos, hit_normal)

	raycast.rotation = Vector3.ZERO

func update_bob(delta: float, horiz_speed: float, on_floor: bool) -> void:
	if on_floor and horiz_speed > 0.5:
		bob_time += delta * 9.0
	else:
		bob_time = 0.0

	# Update 2D HUD Sprite Bob
	var vp_size := get_viewport().get_visible_rect().size
	scale = Vector2.ONE * weapon_scale
	var base_pos := Vector2(
		(vp_size.x * 0.5) - (160.0 * weapon_scale),
		vp_size.y - (200.0 * weapon_scale)
	)
	var bobbing := can_shoot and switch_state == SwitchState.READY and bob_time > 0.0
	var bob_2d := Vector2(cos(bob_time) * 18.0, absf(sin(bob_time)) * 12.0) if bobbing else Vector2.ZERO
	_bob_pos = _bob_pos.lerp(base_pos + bob_2d, delta * 12.0)
	# The switch offset is added after smoothing so the lower/raise moves at a steady speed
	position = _bob_pos + Vector2(0.0, switch_offset * weapon_scale)

func _align_weapon_sprite() -> void:
	if not current_weapon or not weapon_sprite.sprite_frames:
		return
	var tex := weapon_sprite.sprite_frames.get_frame_texture(weapon_sprite.animation, weapon_sprite.frame)
	if not tex:
		return
	var path := tex.resource_path.get_file().get_basename().to_upper()
	if current_weapon.sprite_offsets.has(path):
		weapon_sprite.position = current_weapon.sprite_offsets[path]
	else:
		weapon_sprite.position = Vector2(160.0 - tex.get_width() * 0.5, 200.0 - tex.get_height())

func _align_muzzle_flash() -> void:
	if not current_weapon or current_weapon.flash_offsets.is_empty():
		return
	var f := clampi(muzzle_flash.frame, 0, current_weapon.flash_offsets.size() - 1)
	muzzle_flash.position = current_weapon.flash_offsets[f]

func _on_weapon_animation_finished() -> void:
	if weapon_sprite.animation == "shoot":
		weapon_sprite.play("idle")
		muzzle_flash.visible = false
		muzzle_flash.stop()
		can_shoot = true

func _on_muzzle_flash_finished() -> void:
	muzzle_flash.visible = false

func _spawn_wall_decal(pos: Vector3, normal: Vector3) -> void:
	if not wall_decal_scene:
		return
	var decal := wall_decal_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(decal)
	decal.global_position = pos
	if normal.length_squared() > 0.001:
		var up := normal.normalized()
		var right := up.cross(Vector3.FORWARD if absf(up.z) < 0.99 else Vector3.RIGHT).normalized()
		var forward := right.cross(up).normalized()
		decal.global_basis = Basis(right, up, forward)
		decal.rotate_object_local(Vector3.UP, randf() * TAU)

func _spawn_blood(pos: Vector3) -> void:
	if not blood_splatter_scene:
		return
	var blood := blood_splatter_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(blood)
	blood.global_position = pos
