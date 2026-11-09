extends Decal

func _ready() -> void:
	# Automatically delete the bullet hole after 15 seconds
	get_tree().create_timer(15.0).timeout.connect(queue_free)
