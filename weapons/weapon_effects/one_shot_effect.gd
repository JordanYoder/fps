extends AnimatedSprite3D
## Plays its animation once, then deletes itself. For hit flashes like the BFG tracer hit.

func _ready() -> void:
	animation_finished.connect(queue_free)
	play()
