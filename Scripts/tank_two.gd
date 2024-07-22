extends Node3D

signal hit
var alive : bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	hit.connect(on_hit)
	name = "tank"

func on_hit() -> void:
	print(name, " hit by bullet")
	#alive = false
	#self.position.y -= 60

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
	
func get_ground_pos(pos : Vector3):
	var start_point = pos + Vector3.UP * 64
	var end_point = pos + Vector3.DOWN * 64

	var query = PhysicsRayQueryParameters3D.create(start_point, end_point)
	query.exclude = [$StaticBody3D.get_rid()]

	var result : Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO
	else:
		return result["position"]
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	#if alive == false:
	#	position.y -= _delta;
	if name == "tank2":
		print(position)
		
	var our_ground : Vector3 = get_ground_pos(global_position)
	if our_ground == Vector3.ZERO:
		return
	var forward_ground : Vector3 = get_ground_pos(-1 * 2 * get_global_transform().basis.z.normalized() + global_position)
	if forward_ground == Vector3.ZERO:
		return
	var forward_pos = global_position + (forward_ground - our_ground)
	look_at(forward_pos)
	global_position.y = (our_ground.y + forward_pos.y) / 2.0 + 2.5

	#var start_point = global_position + Vector3.UP * 64
	#var end_point = global_position + Vector3.DOWN * 64
#
	#var query = PhysicsRayQueryParameters3D.create(start_point, end_point)
	#query.exclude = [$StaticBody3D.get_rid()]
#
	#var result : Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	#if !result.is_empty():
		#var pos : Vector3 = result["position"]
		#var norm : Vector3 = result["normal"]
		#var oldPos = position
		##position = pos + Vector3.UP * 3
		##if position != oldPos:
		#if true:
			##transform.basis = Basis(b_rot * basis.get_rotation_quaternion())
			#if name == "tank2":
				#var b_rot = Quaternion(transform.basis.y, norm)
				#print(position - pos)
				#return
				#print(name, " moved from ", oldPos, " to ", position, " and rot is ", rotation_degrees, " after hitting ", determine_world_object(result["collider"]).name)
