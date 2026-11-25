extends AnimatedSprite3D

## Doom's bullet puff (P_SpawnPuff): a small smoke sprite where a shot hits a wall. It drifts
## upward while it plays (momz = 1 unit/tic, ~1.1 m/s here) and then deletes itself.

@export var rise_speed: float = 1.1
## Doom nudges each puff up or down a little (up to 4 units, ~0.125 m) so repeated hits don't
## stack on one spot.
@export var vertical_jitter: float = 0.125

## Set before adding to the tree. Melee hits skip the spark frames, like Doom's punch puff.
var skip_spark_frames: bool = false

func _ready() -> void:
	position.y += randf_range(-vertical_jitter, vertical_jitter)
	animation_finished.connect(queue_free)
	play()
	if skip_spark_frames and sprite_frames.get_frame_count(animation) > 2:
		frame = 2

func _process(delta: float) -> void:
	position.y += rise_speed * delta
