class_name WeaponData
extends Resource

@export var weapon_name: String = "Shotgun"

@export_group("Combat Stats")
@export var damage_per_pellet: int = 10
@export var pellet_count: int = 7
@export var spread_degrees: float = 5.5
@export var fire_rate_cooldown: float = 0.25 # Used for 3D weapons without SpriteFrames
@export var automatic: bool = false

@export_group("3D Viewmodel (Optional)")
@export var weapon_mesh_scene: PackedScene
@export var model_position: Vector3 = Vector3(0.25, -0.22, -0.45) # Right-hand FPS offset
@export var model_rotation_degrees: Vector3 = Vector3(0.0, 180.0, 0.0)
@export var model_scale: Vector3 = Vector3.ONE
@export var recoil_kickback: Vector3 = Vector3(0.0, 0.03, 0.12) # Up and back kick
@export var recoil_rot_degrees: float = 8.0 # Upward barrel tilt on fire

@export_group("2D Visuals & Offsets")
@export var weapon_frames: SpriteFrames
@export var muzzle_flash_frames: SpriteFrames
@export var sprite_offsets: Dictionary = {}
@export var flash_offsets: Array[Vector2] = []
