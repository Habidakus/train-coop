extends Node3D

var lifetime : float = 2
var speed : float = 500
var time_to_explode : float = 1000

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	lifetime -= delta
	time_to_explode -= delta
	#position += rotation * delta
	
	#var r : RayCast3D = $RayCast3D
	#r.rotation = rotation
	#r.collide_with_areas = true
	#r.target_position = 5 * delta * -1 * speed * get_global_transform().basis.z.normalized() - global_position
	#r.force_raycast_update()
	
	#print("collide_with_areas: ", r.collide_with_areas)
	#print("collide_with_bodies: ", r.collide_with_bodies)
	#print("collision_mask: ", r.collision_mask)
	#print("debug_shape_custom_color: ", r.debug_shape_custom_color)
	#print("debug_shape_thickness: ", r.debug_shape_thickness)
	#print("enabled: ", r.enabled)
	#print("exclude_parent: ", r.exclude_parent)
	#print("hit_back_faces: ", r.hit_back_faces)
	#print("hit_from_inside: ", r.hit_from_inside)
	#print("target_position: ", r.target_position)
	
	#if r.get_collider_rid().get_id() != 0:
	#	var collisionObj = r.get_collider()
	#	print("collider: ", collisionObj)
	#	print("point: ", r.get_collision_point())
	
	#print("collision_point: ", r.get_collision_point())
	#print(r.rotation_degrees)
	
	#global_translate(delta * 1000 * Vector3.FORWARD)
	global_translate(delta * -1 * speed * get_global_transform().basis.z.normalized())
	
	#self.translate(get_global_transform().basis.z.normalized() * delta * -300)
	if time_to_explode < 0:
		print("Bullet exploded: pos = ", position, " rot = ", rotation_degrees)
		queue_free()
	if lifetime < 0:
		print("Bullet removed: pos = ", position, "  rot = ", rotation_degrees)
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
			print("Bullet collision at ", result["position"], " against ", result["collider"])
			queue_free()
		else:
			time_to_explode = distance / speed
