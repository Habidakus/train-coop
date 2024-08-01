extends Node3D

func _ready():
	# We only use one of the four possible rocks
	var j = str("0", randi() % 4)
	var child_list = get_children()
	for child in child_list:
		if child.name != j:
			child.queue_free()

func spawn(scale_multiple : float) -> void:
	global_rotation = Vector3(randf(), randf(), randf())
	scale *= scale_multiple
