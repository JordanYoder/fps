extends AnimatedSprite3D

## Doom spawns blood with a small upward push (momz = 2) and lets gravity pull it back down.
@export var initial_up_speed: float = 1.0
@export var gravity: float = 6.0
## Random sideways/vertical scatter so repeated hits don't stack on one spot.
@export var spawn_jitter: float = 0.1

var _velocity: Vector3

func _ready() -> void:
	position += Vector3(
		randf_range(-spawn_jitter, spawn_jitter),
		randf_range(-spawn_jitter, spawn_jitter),
		randf_range(-spawn_jitter, spawn_jitter))
	_velocity = Vector3.UP * initial_up_speed
	animation_finished.connect(queue_free)
	play()

func _process(delta: float) -> void:
	_velocity.y -= gravity * delta
	position += _velocity * delta
