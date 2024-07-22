extends Node3D

signal hit
var alive : bool = true
var world : Node3D

var state_advancing : bool = false
var state_aiming : bool = false
var state_firing : bool = false
var state_dead : bool = false
const max_aim_time : float = 1
var aim_time : float = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	hit.connect(on_hit)
	name = "tank"
	state_aiming = false
	state_advancing = false
	state_firing = true
	state_dead = false

func on_hit() -> void:
	print(name, " hit by bullet")
	state_aiming = false
	state_advancing = false
	state_firing = false
	state_dead = true
	#alive = false
	#self.position.y -= 60

func determine_world_object(object):
	if not object is Node:
		return null
	var up : Node = object
	while up:
		var up_parent = up.get_parent()
		if up_parent == world:
			return up
		up = up_parent
	return object
	
func assign_train_info(_world: Node3D):
	world = _world
	
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
	#if name == "tank2":
		#print(position)
		
	var our_ground : Vector3 = get_ground_pos(global_position)
	if our_ground == Vector3.ZERO:
		return
	var forward_ground : Vector3 = get_ground_pos(-1 * 2 * get_global_transform().basis.z.normalized() + global_position)
	if forward_ground == Vector3.ZERO:
		return
	var forward_pos = global_position + (forward_ground - our_ground)
	look_at(forward_pos)
	global_position.y = (our_ground.y + forward_pos.y) / 2.0 + 2.5
	
	if state_dead:
		return
	
	if state_firing:
		#TODO: Make fire
		if position.z > world.get_train_end_z():
			state_firing = false
			state_advancing = true
			return

	if state_advancing:
		var goal_z = world.get_train_start_z()
		if position.z < goal_z:
			state_advancing = false
			state_aiming = true
			aim_time = max_aim_time
			#pre_aim_rotation = rotation
			return

		#TODO: Aim at where we're going
		#TODO: Avoid other tanks
		#TODO: Advance in our current aim direction, not just sideways towards our goal
		var goal_pos : Vector3 = get_ground_pos(Vector3(global_position.x, global_position.y + 2.5, goal_z)) + Vector3.UP * 2.5
		global_position += (goal_pos - global_position).normalized() * world.get_speed() * 1.5 * _delta
		return
	
	if state_aiming:
		aim_time -= _delta
		
		var global_pos = global_transform.origin
		var target_pos = Vector3(0, global_pos.y, world.get_train_start_z())
		var rotation_speed = 0.01
		var wtransform = global_transform.looking_at(target_pos)
		var wrotation = global_transform.basis.get_rotation_quaternion().slerp(wtransform.basis.get_rotation_quaternion(), rotation_speed)
		var s = scale
		global_transform = Transform3D(Basis(wrotation), global_transform.origin)
		scale = s
		
		if name == "tank2":
			print("turning: ", rotation_degrees)
		
		#var n : Transform3D = global_transform.looking_at()
		if aim_time <= 0:
			state_aiming = false
			state_firing = true
