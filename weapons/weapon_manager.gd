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

## Doom's psprite origin: weapon sprites are drawn at this point minus their sprite offset
## (sx = 1, sy = WEAPONTOP = 32), in the weapon's 320x200 screen.
const DOOM_WEAPON_ORIGIN := Vector2(1.0, 32.0)

var current_weapon: WeaponData
var current_index: int = 0
var can_shoot: bool = true # False while the "shoot" animation runs
var bob_time: float = 0.0
var raycast: RayCast3D

# How many times the trigger has been held through a refire (Doom's player->refire).
# 0 = first shot/burst, which first_shot_accurate weapons fire dead on.
var _refire_count: int = 0
var _audio: AudioStreamPlayer
var _restarting_shoot: bool = false

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
	weapon_sprite.frame_changed.connect(_on_weapon_frame_changed)
	muzzle_flash.frame_changed.connect(_align_muzzle_flash)
	muzzle_flash.animation_finished.connect(_on_muzzle_flash_finished)
	_audio = AudioStreamPlayer.new()
	_audio.max_polyphony = 4 # Chaingun shots overlap
	add_child(_audio)

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
	_refire_count = 0
	muzzle_flash.visible = false
	muzzle_flash.stop()

	weapon_sprite.visible = true
	weapon_sprite.sprite_frames = current_weapon.weapon_frames
	if current_weapon.muzzle_flash_frames:
		muzzle_flash.sprite_frames = current_weapon.muzzle_flash_frames
	weapon_sprite.play("idle")
	_align_weapon_sprite()

func try_fire() -> void:
	if not can_shoot or switch_state != SwitchState.READY or not current_weapon or not raycast:
		return
	_refire_count = 0
	_start_shoot()

func _start_shoot() -> void:
	can_shoot = false
	# Jumping back to frame 0 may or may not emit frame_changed (it doesn't if the frame was
	# already 0), so ignore that signal here and run frame 0's actions exactly once ourselves.
	_restarting_shoot = true
	weapon_sprite.play("shoot")
	weapon_sprite.set_frame_and_progress(0, 0.0)
	_restarting_shoot = false
	_on_weapon_frame_changed()

# Runs the actions of whichever "shoot" frame was just entered: attack, flash, refire.
func _on_weapon_frame_changed() -> void:
	if _restarting_shoot or weapon_sprite.animation != "shoot" or not current_weapon:
		return
	var frame := weapon_sprite.frame
	var w := current_weapon
	if frame == w.refire_frame and _try_refire():
		return
	if frame in w.sound_frames:
		_play_sound(w.fire_sound)
	if frame in w.flash_frames:
		_start_flash(frame)
	if frame in w.attack_frames:
		if w.flash_frames.is_empty():
			_start_flash(frame)
		_attack()

# Doom's A_ReFire: still holding the trigger (and not switching) restarts the attack.
func _try_refire() -> bool:
	if pending_index == -1 and Input.is_action_pressed("shoot"):
		_refire_count += 1
		_start_shoot()
		return true
	_refire_count = 0
	return false

func _start_flash(frame: int) -> void:
	var frames := current_weapon.muzzle_flash_frames
	if not frames:
		return
	var anim := "flash_%d" % frame
	if not frames.has_animation(anim):
		anim = "flash"
		if not frames.has_animation(anim):
			return
	muzzle_flash.sprite_frames = frames
	muzzle_flash.visible = true
	muzzle_flash.play(anim)
	_align_muzzle_flash()

func _attack() -> void:
	var w := current_weapon
	match w.attack_type:
		WeaponData.AttackType.HITSCAN:
			_play_sound(w.fire_sound)
			var accurate := w.first_shot_accurate and _refire_count == 0
			for i in w.pellet_count:
				_fire_bullet(w, accurate)
		WeaponData.AttackType.MELEE:
			var hit := _fire_bullet(w, false)
			_play_sound(w.hit_sound if hit and w.hit_sound else w.fire_sound)
		WeaponData.AttackType.PROJECTILE:
			_play_sound(w.fire_sound)
			_fire_projectile(w)

# Doom's spread: the difference of two random numbers, so shots cluster near the middle.
static func _spread(max_degrees: float) -> float:
	return deg_to_rad((randf() - randf()) * max_degrees)

# Aim direction from the crosshair, plus spread unless accurate. Returns [origin, direction].
func _aim(w: WeaponData, accurate: bool) -> Array[Vector3]:
	var basis := raycast.global_basis
	var dir := -basis.z
	if not accurate:
		dir = dir.rotated(basis.y, _spread(w.spread_degrees))
		dir = dir.rotated(basis.x, _spread(w.vertical_spread_degrees))
	return [raycast.global_position, dir.normalized()]

# Casts one bullet/melee hit. Returns true if it hit something that takes damage.
func _fire_bullet(w: WeaponData, accurate: bool) -> bool:
	var aim := _aim(w, accurate)
	var query := PhysicsRayQueryParameters3D.create(aim[0], aim[0] + aim[1] * w.attack_range, raycast.collision_mask)
	var shooter := _get_shooter()
	if shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var result := raycast.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider: Object = result.collider
	if collider.has_method("take_damage"):
		collider.take_damage(w.roll_damage(), shooter)
		_spawn_blood(result.position)
		return true
	_spawn_wall_decal(result.position, result.normal)
	return false

func _fire_projectile(w: WeaponData) -> void:
	if not w.projectile_scene:
		push_warning("%s has no projectile_scene" % w.weapon_name)
		return
	var projectile := w.projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	var aim := _aim(w, true)
	# Start a little ahead of the camera so it's not inside the player
	var from: Vector3 = aim[0] + aim[1] * 0.6
	if projectile.has_method("launch"):
		projectile.launch(from, from + aim[1] * 10.0, _get_shooter())
	else:
		projectile.global_position = from

# The player body: excluded from our own shots, and credited for the damage.
func _get_shooter() -> Node3D:
	var node: Node = raycast
	while node and not node is CharacterBody3D:
		node = node.get_parent()
	return node as Node3D

func _play_sound(stream: AudioStream) -> void:
	# Weapons with sound_frames play fire_sound on their own schedule, not per attack
	if stream and stream == current_weapon.fire_sound and not current_weapon.sound_frames.is_empty() 			and not (weapon_sprite.frame in current_weapon.sound_frames):
		return
	if stream:
		_audio.stream = stream
		_audio.play()

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
	if current_weapon.sprite_offsets.has(tex):
		weapon_sprite.position = DOOM_WEAPON_ORIGIN - current_weapon.sprite_offsets[tex]
	else:
		weapon_sprite.position = Vector2(160.0 - tex.get_width() * 0.5, 200.0 - tex.get_height())

func _align_muzzle_flash() -> void:
	if not current_weapon or not muzzle_flash.sprite_frames:
		return
	var tex := muzzle_flash.sprite_frames.get_frame_texture(muzzle_flash.animation, muzzle_flash.frame)
	if not tex:
		return
	if current_weapon.sprite_offsets.has(tex):
		muzzle_flash.position = DOOM_WEAPON_ORIGIN - current_weapon.sprite_offsets[tex]
	else:
		# No offset: centre it on top of the gun
		muzzle_flash.position = Vector2(160.0 - tex.get_width() * 0.5, weapon_sprite.position.y - tex.get_height() * 0.5)

func _on_weapon_animation_finished() -> void:
	if weapon_sprite.animation != "shoot":
		return
	if current_weapon.refire_frame < 0 and _try_refire():
		return
	weapon_sprite.play("idle")
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
