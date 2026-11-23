class_name WeaponData
extends Resource

## One weapon's stats, animation and sound. Timing works like Doom's weapon states: the
## "shoot" animation runs at 35 fps (Doom's tic rate) with each frame's duration set to its
## tic count, and the attack, flash and refire happen on specific frames of it.

enum AttackType {
	HITSCAN, ## Instant bullets (pistol, shotgun, chaingun)
	MELEE, ## Short-range hit (fist, chainsaw)
	PROJECTILE, ## Fires projectile_scene (rocket launcher, plasma rifle, BFG)
}

@export var weapon_name: String = "Pistol"

@export_group("Attack")
@export var attack_type: AttackType = AttackType.HITSCAN
## Damage per bullet/hit = damage_base * random(1..damage_dice).
## Doom bullets: 5 * (1..3). Fist and chainsaw: 2 * (1..10). Unused for projectiles.
@export var damage_base: int = 5
@export var damage_dice: int = 3
## Bullets per attack (shotgun: 7)
@export var pellet_count: int = 1
## Max horizontal spread. Like Doom it's triangular: most shots land near the middle.
@export var spread_degrees: float = 5.6
@export var vertical_spread_degrees: float = 0.0
## The first shot (or first burst) is dead on; holding the trigger adds spread. Doom pistol/chaingun.
@export var first_shot_accurate: bool = false
## Hitscan/melee reach. Doom melee: 64 units (~2.2 m here).
@export var attack_range: float = 100.0
@export var projectile_scene: PackedScene

@export_group("Animation")
## Needs "idle" (may loop, e.g. the chainsaw) and "shoot". Set "shoot" to 35 fps and each
## frame's duration to its Doom tic count.
@export var weapon_frames: SpriteFrames
## "shoot" frames on which the attack happens (chaingun fires on both: [0, 1])
@export var attack_frames: Array[int] = [0]
## On entering this frame, holding the trigger restarts "shoot" from the top, skipping the
## rest (Doom's A_ReFire). -1 = check when the animation ends.
@export var refire_frame: int = -1
## Optional. When the attack happens on frame N, plays "flash_N" if it exists, else "flash".
## Set the flash animations to 35 fps with tic durations too.
@export var muzzle_flash_frames: SpriteFrames
## "shoot" frames that start the flash. Empty = flash with every attack.
## (Doom's rocket launcher flashes one state before it fires.)
@export var flash_frames: Array[int] = []
## Doom sprite offsets for each texture (gun and flash), as SLADE / the WAD store them,
## e.g. PISGA0 = (-126, -106). They line the flash up with the gun exactly. Textures without
## one are centred at the bottom of the screen (flashes: on top of the gun).
@export var sprite_offsets: Dictionary[Texture2D, Vector2] = {}

@export_group("Sound")
## Plays with every attack (for melee: only on a miss, if hit_sound is set)
@export var fire_sound: AudioStream
## Play fire_sound on these "shoot" frames instead of with each attack.
## (The BFG's sound starts with the charge-up on frame 0, a second before it fires.)
@export var sound_frames: Array[int] = []
## Melee only: plays instead of fire_sound when the hit connects (fist punch, chainsaw bite)
@export var hit_sound: AudioStream


func roll_damage() -> int:
	return damage_base * randi_range(1, maxi(damage_dice, 1))
