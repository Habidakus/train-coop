extends Node3D

signal hit
#var alive : bool = true
var world : Node3D

enum State {
	Dead,
	Dying,
	Advancing,
	Aiming,
	Firing,
}

var state : State = State.Advancing
var age : float = 0

var reloading : float = 0
var max_reload_time : float = 1

const rotation_speed : float = 1.5
const max_aim_time : float = 1
const float_height : float = 2.5
var aim_time : float = 0
var speed : float = 0
const max_other_tracked_tanks = 15
var closest_other_tanks : Array[Node3D] = []
var comparitor_index : int = 0
const draw_debug_lines : bool = false

func get_comparitor_tank_index() -> int:
	return comparitor_index

func set_comparitor_tank_index(index : int) -> void:
	comparitor_index = index

# Called when the node enters the scene tree for the first time.
func _ready():
	hit.connect(on_hit)
	name = "tank"
	state = State.Advancing

func on_hit() -> void:
	self_destruct("hit by bullet", true)

func is_dead() -> bool:
	return (state == State.Dying) || (state == State.Dead)

func can_respawn() -> bool:
	if !is_dead():
		return false
	return global_position.z > world.get_train_end_z() + 512

func start_resurection() -> void:
	assert(is_dead())
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
	query.collision_mask = 2
	#query.exclude = [$StaticBody3D.get_rid()]
	#for tank in closest_other_tanks:
	#	if tank != null:
	#		query.exclude.append(tank.get_rid())

	var result : Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO
	else:
		return result["position"]

func self_destruct(reason : String, confirmed_kill : bool):
	assert(!is_dead())
	state = State.Dying
	print(name, " self destructing: ", reason)
	if confirmed_kill:
		world.update_scoreboard_kill()
	else:
		world.offer_enemy_redemption()

func handle_state_aiming(delta : float) -> void:
	speed = lerp(speed, 0.0, delta * 2)

	var global_pos = global_transform.origin
	var target_pos = Vector3(0, global_pos.y, world.get_train_start_z())
	turn_to(target_pos, delta)
	
	#if name == "tank2":
		#var dot = (target_pos - global_pos).normalized().dot(get_global_transform().basis.z.normalized() * -1)
		#var cross_front = (target_pos - global_pos).normalized().cross(get_global_transform().basis.z.normalized() * -1)
		#var end_pos = Vector3(0, global_pos.y, world.get_train_end_z())
		#var cross_end = (end_pos - global_pos).normalized().cross(get_global_transform().basis.z.normalized() * -1)
		
		#print("turning: rot=", rotation_degrees.y, " front=", cross_front, " end=", cross_end)
	
	#var n : Transform3D = global_transform.looking_at()
	
	# TODO: Currently we just "aim" for N seconds. Instead we should actually just keep turning until such time as we are aimed somewhere between the start and end of the train
	
	aim_time -= delta
	if aim_time <= 0:
		state = State.Firing

func handle_state_firing() -> void:
	speed = 0
		
	if reloading <= 0:
		# TODO: Don't actually fire unless we're aimed somewhere between the start and end of the train
		var vfx : GPUParticles3D = $TankFireVFX.find_child("GPUParticles3D2") as GPUParticles3D
		if vfx != null:
			vfx.emitting = true
			reloading = max_reload_time
			world.add_damage(1)
			
	if position.z > world.get_train_end_z():
		state = State.Advancing

func handle_state_advancing(delta : float) -> void:
	var goal_z = world.get_train_start_z()
	if position.z < goal_z:
		state = State.Aiming
		aim_time = max_aim_time
		return

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
	
	var avoid_train : Vector3 = avoid_loc(Vector3(0, global_position.y, global_position.z), 256)
	const max_dist_from_train : float = 512.0
	if avoid_train == Vector3.ZERO:
		if global_position.x > max_dist_from_train:
			avoid_train = Vector3(-1, 0, 0)
		elif global_position.x < - max_dist_from_train:
			avoid_train = Vector3(1, 0, 0)
	var goal_vec : Vector3 = goal_normal / 5.0 + avoid_train
	if avoid_train != Vector3.ZERO:
		draw_line(global_position + avoid_train * 32.0, Color.RED)

	var avoid_tanks : Vector3 = Vector3.ZERO
	for tank in closest_other_tanks:
		if tank != null:
			avoid_tanks = avoid_tanks + avoid_node(tank, 128)
	
	goal_vec = goal_vec + avoid_tanks.normalized() / 2.0
	if avoid_tanks != Vector3.ZERO:
		draw_line(global_position + avoid_tanks.normalized() * 32.0, Color.GREEN)

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
	if !draw_debug_lines:
		return
		
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

func avoid_node(node : Node3D, max_dist : float) -> Vector3:
	if node == null:
		return Vector3.ZERO
	return avoid_loc(node.global_position, max_dist)

func avoid_loc(loc : Vector3, max_dist : float) -> Vector3:
	var distSqrd : float = loc.distance_squared_to(global_position)
	var max_dist_sqrd : float = max_dist * max_dist
	if distSqrd > max_dist_sqrd:
		return Vector3.ZERO
	
	var away_from_node : Vector3 = (global_position - loc)
	
	# If we're already headed away from it, ignore it
	var dot = away_from_node.dot(get_global_transform().basis.z.normalized() * -1)
	if dot > -0.1:
		return Vector3.ZERO
	
	var weight : float = 1.0 - (sqrt(distSqrd) / max_dist)
	return away_from_node.normalized() * weight

func spawn(train : Node3D) -> void:
	# TODO: For now we just hard code every enemy on the -x side
	var x : float = 0 - (randf() * 2048.0 + 512.0)
	var z : float = train.get_train_start_z() + randf() * 512.0
	position = Vector3(x, 10, z)
	age = 0
	assign_train_info(train)
	state = State.Advancing

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	age += _delta
	
	if state == State.Dead:
		speed = 0
		return

	if state == State.Dying:
		speed = 0
		if global_position.y < -60:
			state = State.Dead
		else:
			global_position.y -= _delta * 2.0
		return
		
		
	reloading -= _delta

	#if name == "tank2":
		#print(position)
	if speed > 0:
		global_position = get_ground_pos(-1 * speed * _delta * get_global_transform().basis.z.normalized() + global_position) + float_height * Vector3.UP
	
	if position.y > 256:
		self_destruct("too high: " + str(position), age > 1)
		return
	if position.y < -256:
		self_destruct("too low: " + str(position), age > 1)
		return
		
	var our_ground : Vector3 = get_ground_pos(global_position)
	if our_ground == Vector3.ZERO:
		self_destruct("no ground under us: " + str(global_position), age > 1)
		return

	var proj : Vector3 = -1 * 2 * get_global_transform().basis.z.normalized() + global_position
	var forward_ground : Vector3 = get_ground_pos(proj)
	if forward_ground == Vector3.ZERO:
		self_destruct("no ground under our projected path at spawn: " + str(proj), age > 1)
		return
		
	var forward_pos = global_position + (forward_ground - our_ground)
	if forward_pos.is_equal_approx(global_position):
		var err = "forward == current!!! rot=" + str(global_rotation_degrees) + " our_ground=" + str(our_ground) + " forward_pos=" + str(forward_ground)
		self_destruct(err, age > 1)
		return
		
	look_at(forward_pos)
	global_position.y = (our_ground.y + forward_pos.y) / 2.0 + float_height
	
	if state == State.Firing:
		handle_state_firing()
		return

	if state == State.Advancing:
		handle_state_advancing(_delta)
		return
	
	if state == State.Aiming:
		handle_state_aiming(_delta)
		return

func turn_to(target_pos : Vector3, delta : float):
	#var global_pos = global_transform.origin
	if Vector3.UP.cross(- (target_pos - global_position).normalized()).is_zero_approx():
		#TODO: This tank is in a bad way, we should fix it getting in this state
		return
	
	if (target_pos - global_position).is_zero_approx():
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
