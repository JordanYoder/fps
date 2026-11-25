extends Label
## Shows the current weapon's ammo. Put this on a Label inside the player's HUD.
## Blank for melee weapons, which don't use ammo.

@export var ammo_color: Color = Color(1.0, 0.85, 0.2)
@export var empty_color: Color = Color(1.0, 0.0, 0.0)

var _weapons: Node

func _ready() -> void:
	# owner is the Player, the root of player.tscn
	_weapons = owner.get_node("HUD/WeaponManager")
	_weapons.weapon_equipped.connect(func(_w: WeaponData) -> void: _refresh())
	_weapons.ammo_changed.connect(func(_type, _amount, _max) -> void: _refresh())
	_refresh()

func _refresh() -> void:
	var w: WeaponData = _weapons.current_weapon
	if not w or w.ammo_type == WeaponData.AmmoType.NONE:
		text = ""
		return
	var amount: int = _weapons.get_ammo(w.ammo_type)
	text = str(amount)
	modulate = ammo_color if amount >= w.ammo_per_shot else empty_color
