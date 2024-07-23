extends Node3D

signal hit
#var alive : bool = true
var world : Node3D

var state_advancing : bool = false
var state_aiming : bool = false
var state_firing : bool = false
var state_dead : bool = false
const rotation_speed : float = 1.5
const max_aim_time : float = 1
const float_height : float = 2.5
var aim_time : float = 0
var speed : float = 0
const max_other_tracked_tanks = 5
var closest_other_tanks : Array[Node3D] = []
var comparitor_index : int = 0

func get_comparitor_tank_index() -> int:
	return comparitor_index

func set_comparitor_tank_index(index : int) -> void:
	comparitor_index = index

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

func is_dead() -> bool:
	return state_dead

func start_resurection() -> void:
	pass

func consider_other(other : Node3D, distSqrd : float) -> void:
	if closest_other_tanks.size() < max_other_tracked_tanks:
		for tank in closest_other_tanks:
			if tank == other:
				return
		closest_other_tanks.append(other)
		return

	var farthest_tank_index : int = -1
	var farthest_tank_distance_sqrd : float = distSqrd
	for i in range(1, max_other_tracked_tanks):
		var d : float = global_position.distance_squared_to(closest_other_tanks[i].global_position)
		if d > farthest_tank_distance_sqrd:
			farthest_tank_distance_sqrd = d
			farthest_tank_index = i

	if farthest_tank_index != -1:
		closest_other_tanks[farthest_tank_index] = other

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

func get_rid():
	return $StaticBody3D.get_rid()
	
func get_ground_pos(pos : Vector3):
	var start_point = pos + Vector3.UP * 64
	var end_point = pos + Vector3.DOWN * 64

	var query = PhysicsRayQueryParameters3D.create(start_point, end_point)

	# TODO: We should make sure we're only testing against ground, not just anything that isn't ourselves
	query.exclude = [$StaticBody3D.get_rid()]
	for tank in closest_other_tanks:
		if tank != null:
			query.exclude.append(tank.get_rid())

	var result : Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO
	else:
		return result["position"]

func self_destruct():
	state_dead = true
	state_firing = false
	state_aiming = false
	state_advancing = false
	print(name, " self destructing")

func handle_state_advancing(delta : float) -> void:
	var goal_z = world.get_train_start_z()
	if position.z < goal_z:
		state_advancing = false
		state_aiming = true
		aim_time = max_aim_time
		#pre_aim_rotation = rotation
		return

	#TODO: Avoid other tanks and the train
	var goal_pos : Vector3 = get_ground_pos(Vector3(global_position.x, global_position.y + float_height, goal_z)) + Vector3.UP * float_height
	
	speed = lerp(speed, world.get_speed() * 1.5, delta)
	
	# If we're too close or too far from the tracks, adjust
	#var dist_from_tracks = abs(global_position.x)
	#var sign_of_x = 1
	#if dist_from_tracks > 0:
		#sign_of_x = global_position.x / dist_from_tracks
	#if dist_from_tracks < 96:
		#goal_pos = Vector3(sign_of_x * 160, global_position.y + float_height, global_position.z - 1)
	#elif abs(global_position.x) > 256:
		#goal_pos = Vector3(0, global_position.y + float_height, global_position.z - 1)

	var goal_normal : Vector3 = Vector3(goal_pos.x - global_transform.origin.x, 0, goal_pos.z - global_transform.origin.z).normalized()
	
	var avoid_train : Vector3 = avoid_loc(Vector3(0, global_position.y, global_position.z))
	const max_dist_from_train : float = 512.0
	if avoid_train == Vector3.ZERO:
		if global_position.x > max_dist_from_train:
			avoid_train = Vector3(-1, 0, 0)
		elif global_position.x < - max_dist_from_train:
			avoid_train = Vector3(1, 0, 0)
	var goal_vec : Vector3 = goal_normal / 5.0 + avoid_train
	if avoid_train != Vector3.ZERO:
		draw_line(global_position + avoid_train * 32.0, Color.RED)

	for tank in closest_other_tanks:
		if tank != null:
			var avoid_tank : Vector3 = avoid_node(tank)
			draw_line(global_position + avoid_tank * 32.0, Color.GREEN)
			goal_vec += avoid_tank

	goal_vec = goal_vec.normalized()

	var dot = goal_vec.dot(get_global_transform().basis.z.normalized() * -1)
	if dot < 0:
		speed = lerpf(speed, 0, delta * 2)
	elif dot < 0.5:
		speed = lerpf(speed, speed * 0.66, delta)
	
	turn_to(global_transform.origin + goal_vec, delta)
	
	draw_line(global_position + goal_normal * 32.0, Color.WHITE)
	
	#global_position += (goal_pos - global_position).normalized() * world.get_speed() * 1.5 * _delta
	#if name == "tank2":
	#	print("advancing: z=", position.z, " dot=", dot, " speed=", speed)
	return

func draw_line(dest : Vector3, color : Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()
	var material := ORMMaterial3D.new()

	mesh_instance.mesh = immediate_mesh
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	immediate_mesh.surface_add_vertex(dest + 6 * float_height * Vector3.UP)
	immediate_mesh.surface_add_vertex(global_position + 6 * float_height * Vector3.UP)
	immediate_mesh.surface_end()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color

	# keep it on the screen for one frame
	get_tree().get_root().add_child(mesh_instance)
	await get_tree().physics_frame
	mesh_instance.queue_free()

func avoid_node(node : Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return avoid_loc(node.global_position)

func avoid_loc(loc : Vector3) -> Vector3:
	var distSqrd : float = loc.distance_squared_to(global_position)
	const max_dist : float = 128
	const max_dist_sqrd : float = max_dist * max_dist
	if distSqrd > max_dist_sqrd:
		return Vector3.ZERO
	
	var away_from_node : Vector3 = (global_position - loc)
	
	# If we're already headed away from it, ignore it
	var dot = away_from_node.dot(get_global_transform().basis.z.normalized() * -1)
	if dot > 0:
		return Vector3.ZERO
	
	var weight : float = 1.0 - (sqrt(distSqrd) / max_dist)
	return away_from_node.normalized() * weight

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if state_dead:
		return

	#if name == "tank2":
		#print(position)
	if speed > 0:
		global_position = get_ground_pos(-1 * speed * _delta * get_global_transform().basis.z.normalized() + global_position) + float_height * Vector3.UP
	
	if position.y > 100 || position.y < -100:
		self_destruct()
		return
		
	var our_ground : Vector3 = get_ground_pos(global_position)
	if our_ground == Vector3.ZERO:
		self_destruct()
		return
	var forward_ground : Vector3 = get_ground_pos(-1 * 2 * get_global_transform().basis.z.normalized() + global_position)
	if forward_ground == Vector3.ZERO:
		self_destruct()
		return
	var forward_pos = global_position + (forward_ground - our_ground)
	if forward_pos.is_equal_approx(global_position):
		print("forward == current!!! rot=", global_rotation_degrees, " our_ground=", our_ground, " forward_pos=", forward_ground)
		self_destruct()
		return
		
	look_at(forward_pos)
	global_position.y = (our_ground.y + forward_pos.y) / 2.0 + float_height
	
	if state_dead:
		if name == "tank2":
			print("dead: z=", position.z)
		return
	
	if state_firing:
		#TODO: Make fire
		speed = 0
		if name == "tank2":
			print("firing: z=", position.z)
			
		if position.z > world.get_train_end_z():
			state_firing = false
			state_advancing = true
			return

	if state_advancing:
		handle_state_advancing(_delta)
		return
	
	if state_aiming:
		aim_time -= _delta
		speed = lerp(speed, 0.0, _delta * 2)
		
		var global_pos = global_transform.origin
		var target_pos = Vector3(0, global_pos.y, world.get_train_start_z())
		turn_to(target_pos, _delta)
		
		#if name == "tank2":
			#var dot = (target_pos - global_pos).normalized().dot(get_global_transform().basis.z.normalized() * -1)
			#var cross_front = (target_pos - global_pos).normalized().cross(get_global_transform().basis.z.normalized() * -1)
			#var end_pos = Vector3(0, global_pos.y, world.get_train_end_z())
			#var cross_end = (end_pos - global_pos).normalized().cross(get_global_transform().basis.z.normalized() * -1)
			
			#print("turning: rot=", rotation_degrees.y, " front=", cross_front, " end=", cross_end)
		
		#var n : Transform3D = global_transform.looking_at()
		if aim_time <= 0:
			state_aiming = false
			state_firing = true

func turn_to(target_pos : Vector3, delta : float):
	#var global_pos = global_transform.origin
	if Vector3.UP.cross(- (target_pos - global_position).normalized()).is_zero_approx():
		#TODO: This tank is in a bad way, we should fix it getting in this state
		return

	var wtransform = global_transform.looking_at(target_pos)
	var target_quaternion = wtransform.basis.get_rotation_quaternion();
	
	var current_rotation : Quaternion = global_transform.basis.get_rotation_quaternion();
	var rotation_difference: Quaternion = target_quaternion * current_rotation.inverse()
	var amount_of_roation_needed : float = rotation_difference.get_angle()
	if abs(amount_of_roation_needed) < 0.01:
		return
		
	if amount_of_roation_needed > PI:
		amount_of_roation_needed = amount_of_roation_needed - TAU
	elif amount_of_roation_needed < -PI:
		amount_of_roation_needed = TAU + amount_of_roation_needed
	
	var rotation_this_impulse: float = rotation_speed * delta

	# Cache scale
	var s = scale
	
	# Apply the incremental rotation
	var fraction = abs(rotation_this_impulse / amount_of_roation_needed);
	if fraction < 1.0:
		var wrotation = current_rotation.slerp(target_quaternion, fraction)
		global_transform = Transform3D(Basis(wrotation), global_transform.origin)
	else:
		global_transform = Transform3D(Basis(target_quaternion), global_transform.origin)
	
	# Restore Scale
	scale = s
