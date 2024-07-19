extends Node3D

@export var explosion_scene : PackedScene

var lifetime : float = 3
var speed : float = 750
var time_to_explode : float = 1000
var maybe_world_object : Node = null

func _process(delta):
	lifetime -= delta
	time_to_explode -= delta
	global_translate(delta * -1 * speed * get_global_transform().basis.z.normalized())
	
	if time_to_explode < 0:
		if maybe_world_object:
			print("bullet might have hit ", maybe_world_object.get_path())
		explode(position)
		queue_free()
	if lifetime < 0:
		queue_free()

func determine_world_object(object):
	if not object is Node:
		return null
	var world = get_parent()
	var up : Node = object
	while up:
		var up_parent = up.get_parent()
		if up_parent == world:
			return up
		up = up_parent
	return object
		
func _physics_process(delta):
	var space_state = get_world_3d().direct_space_state
	var travel_length = delta * speed;
	var end_point = -1 * 2 * travel_length * get_global_transform().basis.z.normalized() + global_position
	var query = PhysicsRayQueryParameters3D.create(global_position, end_point)
	query.collide_with_areas = true
	var result : Dictionary = space_state.intersect_ray(query)
	if !result.is_empty():
		var pos : Vector3 = result["position"]
		var distance = (pos - global_position).length()
		if distance <= travel_length:
			var world_object = determine_world_object(result["collider"])
			if world_object:
				if world_object.has_user_signal("hit"):
					print("bullet thinks it has hit user signal object ", world_object.get_path())
					world_object.emit_signal("hit")
				elif world_object.has_signal("hit"):
					print("bullet thinks it has hit regular signal object ", world_object.get_path())
					world_object.emit_signal("hit")
				else:
					print("bullet thinks it has hit non signal object ", world_object.get_path())
			explode(pos)
			queue_free()
		else:
			time_to_explode = distance / speed
			maybe_world_object = determine_world_object(result["collider"]) as Node

func explode(pos : Vector3):
	var explosion = explosion_scene.instantiate()
	explosion.position = pos
	get_parent().add_child(explosion)
