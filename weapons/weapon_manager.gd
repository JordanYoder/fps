extends Control

@export var weapons: Array[WeaponData] = []
@export var weapon_scale: float = 4.5
@export var wall_decal_scene: PackedScene
@export var blood_splatter_scene: PackedScene

@onready var weapon_sprite: AnimatedSprite2D = $WeaponSprite
@onready var muzzle_flash: AnimatedSprite2D = $MuzzleFlash

var current_weapon: WeaponData
var current_index: int = 0
var can_shoot: bool = true
var bob_time: float = 0.0
var raycast: RayCast3D

func _ready() -> void:
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
			equip_weapon(slot)

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
	if not can_shoot or not current_weapon or not raycast:
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
	var bob_2d := Vector2(cos(bob_time) * 18.0, absf(sin(bob_time)) * 12.0) if (can_shoot and bob_time > 0.0) else Vector2.ZERO
	position = position.lerp(base_pos + bob_2d, delta * 12.0)

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
