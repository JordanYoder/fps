class_name WeaponData
extends Resource

@export var weapon_name: String = "Shotgun"

@export_group("Combat Stats")
@export var damage_per_pellet: int = 10
@export var pellet_count: int = 7
@export var spread_degrees: float = 5.5
@export var automatic: bool = false

@export_group("2D Visuals & Offsets")
@export var weapon_frames: SpriteFrames
@export var muzzle_flash_frames: SpriteFrames
@export var sprite_offsets: Dictionary = {}
@export var flash_offsets: Array[Vector2] = []
