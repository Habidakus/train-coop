extends Node3D

@export var explosion_scene : PackedScene

var lifetime : float = 3
var speed : float = 750
var time_to_explode : float = 1000

func _process(delta):
	lifetime -= delta
	time_to_explode -= delta
	global_translate(delta * -1 * speed * get_global_transform().basis.z.normalized())
	
	if time_to_explode < 0:
		explode(position)
		queue_free()
	if lifetime < 0:
		queue_free()

func _physics_process(delta):
	var space_state = get_world_3d().direct_space_state
	var travel_length = delta * speed;
	var end_point = -1 * 2 * travel_length * get_global_transform().basis.z.normalized() + global_position
	var query = PhysicsRayQueryParameters3D.create(global_position, end_point)
	var result : Dictionary = space_state.intersect_ray(query)
	if !result.is_empty():
		var pos : Vector3 = result["position"]
		var distance = (pos - global_position).length()
		if distance <= travel_length:
			explode(pos)
			queue_free()
		else:
			time_to_explode = distance / speed

func explode(pos : Vector3):
	var explosion = explosion_scene.instantiate()
	explosion.position = pos
	get_parent().add_child(explosion)
