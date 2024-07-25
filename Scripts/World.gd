extends Node3D

@export var noise : Noise
@export var chunk_scene : PackedScene
@export var locomotive_scene : PackedScene
@export var train_car_scene : PackedScene
@export var enemy_scene : PackedScene
@export var bullet_scene : PackedScene
@export var reticule_scene : PackedScene
@export var chunk_material : Material
@export var train_speed_miles_per_hour : float = 40
@export var box_car_spacing_feet : float = 60
@export var box_car_count : int = 4
@export var enemy_count : int = 30
@export var mouse_sensitivity : float = 1.5
@export var turret_y_range : float = 40
@export var turret_x_range_min : float = -14
@export var turret_x_range_max : float = 12.5

const units_per_meter : float = 10
const meters_per_mile : float = 1609.34
const meters_per_foot : float = 0.3048

const chunk_size : int = 2048
const chunk_amount : int = 2
const chunk_radius : int = int(chunk_amount * 0.5);
const chunk_subdivide : int = 32
const chunk_height : float = 64

var all_enemies = []
var train_cars = []
var existing_chunks = {}

var mutex : Mutex
var semaphore : Semaphore
var thread : Thread
var pending_chunks = {}
var work_queue = []

var turret_y_negative : bool = false
var turret_y_positive : bool = false
var turret_x_negative : bool = false
var turret_x_positive : bool = false
var turret_fire : bool = false
var turret_y_accel : float = 0
var turret_x_accel : float = 0
var turret_cooldown : float = 0
var turret_reticule : Decal
var shots_fired : int = 0

var tank_base_index : int = 0
var enemies_left_in_wave : int = enemy_count * 2
var train_damage : float = 0
var wave_time : float = 0

func _ready():
	randomize()
	noise.seed = randi()
	$Camera3D.position.y = 45.0
	$Camera3D.rotation_degrees.y = 60
	
	mutex = Mutex.new()
	semaphore = Semaphore.new()
	thread = Thread.new()
	thread.start(run_builder_thread)
	turret_reticule = reticule_scene.instantiate()
	turret_reticule.scale *= units_per_meter
	add_child(turret_reticule)
	move_reticule($Camera3D)
	
	for i in range(0, box_car_count):
		var train_car
		if i > 0:
			train_car = train_car_scene.instantiate()
		else:
			train_car = locomotive_scene.instantiate()
		train_car.scale *= units_per_meter
		train_cars.append(train_car)
		add_child(train_car)
		place_box_car(train_car, i)
		
	for z in range(-1, 1):
		add_chunk(-1, z)
		add_chunk(0, z)
		add_chunk(1, z)
	
	#thread = Thread.new()

func add_damage(dmg : float) -> void:
	train_damage += dmg
	$HUD.set_stat("Train Damage", str(int(round(train_damage))))

func update_scoreboard_kill() -> void:
	var remaining_enemies : int = enemies_left_in_wave
	for tank in all_enemies:
		if tank != null && !tank.is_dead():
			remaining_enemies += 1
	$HUD.set_stat("Enemy Remaining", str(remaining_enemies))

func offer_enemy_redemption() -> void:
	enemies_left_in_wave += 1

func initialize_enemies() -> void:
	assert(all_enemies.is_empty())
	wave_time = 0
	for i in range(0, enemy_count):
		var enemy = enemy_scene.instantiate()
		#enemy.find_child("Model").scale *= units_per_meter
		enemy.scale *= units_per_meter
		enemies_left_in_wave -= 1
		all_enemies.append(enemy)
		add_child(enemy)
		enemy.spawn(self)

func get_train_start_z() -> float:
	return get_box_car_position(0).z - box_car_spacing_feet * meters_per_foot / 2.0

func get_train_end_z() -> float:
	return get_box_car_position(box_car_count - 1).z + box_car_spacing_feet * meters_per_foot / 2.0

func place_box_car(train_car, car_number : int):
	train_car.position = get_box_car_position(car_number)

func get_box_car_position(car_number: int) -> Vector3:
	var box_car_spacing_meters : float = box_car_spacing_feet * meters_per_foot
	var relative_car_number : int = int(float(box_car_count - 1) / 2.0) - car_number
	return Vector3($Camera3D.position.x, 0, $Camera3D.position.z - relative_car_number * box_car_spacing_meters * units_per_meter)

func get_speed() -> float:
	var meters_per_second = meters_per_mile * train_speed_miles_per_hour / 3600.0
	return meters_per_second * units_per_meter
	
func _process(delta: float):
	update_chunks()
	clean_up_chunks()
	reset_chunks()

	if !all_enemies.is_empty():
		var previous_wave_time : float = wave_time
		wave_time += delta
		if int(previous_wave_time) != int(wave_time):
			var seconds : int = int(wave_time) % 60
			var minutes : int = int((wave_time - seconds) / 60.0)
			if seconds < 10:
				$HUD.set_stat("Wave Time", str(minutes) + ":0" + str(seconds))
			else:
				$HUD.set_stat("Wave Time", str(minutes) + ":" + str(seconds))
	
	if $DirectionalLight3D is DirectionalLight3D:
		($DirectionalLight3D as DirectionalLight3D).rotation.x -= delta / 300.0
		($DirectionalLight3D as DirectionalLight3D).rotation.y += delta / 300.0
	
	handle_turret(delta)
	
	move_train()
	
	move_reticule($Camera3D)
	
	update_enemies()

func handle_turret(delta: float) -> void:
	$Camera3D.position.z -= get_speed() * delta
	#$Camera3D.rotation.y -= _delta / 10.0
	#$Camera3D.rotation_degrees.y += _delta
	if turret_y_negative != turret_y_positive:
		if turret_y_positive:
			turret_y_accel += delta * mouse_sensitivity
		if turret_y_negative:
			turret_y_accel -= delta * mouse_sensitivity
			#$Camera3D.rotation.y -= _delta * mouse_sensitivity
		turret_y_accel = clampf(turret_y_accel, -1, 1)
	else:
		if abs(turret_y_accel) < 0.05:
			turret_y_accel = 0
		else:
			turret_y_accel = lerpf(turret_y_accel, 0, delta * mouse_sensitivity * 2.0)
			
	if turret_x_negative != turret_x_positive:
		if turret_x_positive:
			turret_x_accel += delta * mouse_sensitivity
		if turret_x_negative:
			turret_x_accel -= delta * mouse_sensitivity
		turret_x_accel = clampf(turret_x_accel, -1, 1)
	else:
		if abs(turret_x_accel) < 0.05:
			turret_x_accel = 0
		else:
			turret_x_accel = lerpf(turret_x_accel, 0, delta * mouse_sensitivity * 2.0)
	
	$Camera3D.rotation.y += turret_y_accel * delta
	#$Camera3D.rotation_degrees.y = clampf($Camera3D.rotation_degrees.y, 90 - turret_y_range, 90 + turret_y_range)
	if $Camera3D.rotation_degrees.y > 90 + turret_y_range:
		$Camera3D.rotation_degrees.y = 90 + turret_y_range
		turret_y_accel = 0
	elif $Camera3D.rotation_degrees.y < 90 - turret_y_range:
		$Camera3D.rotation_degrees.y = 90 - turret_y_range
		turret_y_accel = 0
	$Camera3D.rotation.x += turret_x_accel * delta
	#$Camera3D.rotation_degrees.x = clampf($Camera3D.rotation_degrees.x, turret_x_range_min, turret_x_range_max)
	if $Camera3D.rotation_degrees.x > turret_x_range_max:
		$Camera3D.rotation_degrees.x = turret_x_range_max
		turret_x_accel = 0
	elif $Camera3D.rotation_degrees.x < turret_x_range_min:
		$Camera3D.rotation_degrees.x = turret_x_range_min
		turret_x_accel = 0
	
	turret_cooldown -= delta
	if turret_fire and turret_cooldown <= 0:
		var bullet : Node3D = bullet_scene.instantiate()
		bullet.rotation = $Camera3D.rotation
		bullet.position = $Camera3D.position
		add_child(bullet)
		shots_fired += 1
		$HUD.set_stat("Shots Fired", str(shots_fired))
		turret_cooldown = 0.5
		
func move_train() -> void:
	for i in range(0, box_car_count):
		place_box_car(train_cars[i], i)

func update_enemies() -> void:
	if all_enemies.is_empty():
		return
		
	tank_base_index = (tank_base_index + 1) % all_enemies.size()
	var tank : Node3D = all_enemies[tank_base_index]
	if tank == null:
		print("TANK #", tank_base_index, " is NULL")
		return

	if tank.is_dead() && enemies_left_in_wave > 0:
		if tank.can_respawn():
			enemies_left_in_wave -= 1
			tank.spawn(self)
		return
	
	for i in range(0, 15):
		var tank_comparitor_index = tank.get_comparitor_tank_index()
		tank_comparitor_index = (tank_comparitor_index + 7) % all_enemies.size()
		tank.set_comparitor_tank_index(tank_comparitor_index)
	
		if tank_comparitor_index == tank_base_index:
			continue
		
		var other : Node3D = all_enemies[tank_comparitor_index]
		if other == null:
			print("TANK #", tank_comparitor_index, " is NULL")
			continue

		# If they're on opposite sides of the track, never pair them up
		var other_track_side : bool = other.global_position.x < 0
		var our_track_side : bool = tank.global_position.x < 0
		if other_track_side != our_track_side:
			continue

		var distSqrd : float = tank.global_position.distance_squared_to(other.global_position)
		tank.consider_other(other, distSqrd)
		other.consider_other(tank, distSqrd)

func move_reticule(aimer : Node3D) -> void:
	var space_state = get_world_3d().direct_space_state
	var start_point = aimer.global_position
	var end_point = -1 * 2000 * aimer.get_global_transform().basis.z.normalized() + start_point
	var query = PhysicsRayQueryParameters3D.create(start_point, end_point)
	var result : Dictionary = space_state.intersect_ray(query)
	if !result.is_empty():
		var pos : Vector3 = result["position"]
		var norm : Vector3 = result["normal"]
		turret_reticule.position = pos
		if !(norm - Vector3.UP).is_zero_approx() and !(norm - Vector3.DOWN).is_zero_approx():
			if norm.dot(Vector3.UP) > 0.001:
				turret_reticule.look_at(turret_reticule.global_transform.origin + norm, Vector3.UP)
				turret_reticule.rotate_object_local(Vector3(1, 0, 0), 90)
		turret_reticule.show()
	else:
		turret_reticule.hide()

func _input(event):
	#if event is InputEventMouseMotion:
	#	$Camera3D.rotation.y -= event.relative.x / mouse_sensitivity
	#	$Camera3D.rotation.x -= event.relative.y / mouse_sensitivity
	if event is InputEventKey:
		var iek = event as InputEventKey
		if iek.is_pressed():
			if iek.keycode == KEY_D:
				turret_y_negative = true
			if iek.keycode == KEY_A:
				turret_y_positive = true
			if iek.keycode == KEY_S:
				turret_x_negative = true
			if iek.keycode == KEY_W:
				turret_x_positive = true
			if iek.keycode == KEY_SPACE:
				turret_fire = true
		if iek.is_released():
			if iek.keycode == KEY_D:
				turret_y_negative = false
			if iek.keycode == KEY_A:
				turret_y_positive = false
			if iek.keycode == KEY_S:
				turret_x_negative = false
			if iek.keycode == KEY_W:
				turret_x_positive = false
			if iek.keycode == KEY_SPACE:
				turret_fire = false

func update_chunks():
	var pt = $Camera3D.position
	var px :int = int(pt.x / chunk_size)
	var pz :int = int(pt.z / chunk_size)
	for x in range(px - chunk_radius, 1 + px + chunk_radius):
		for z in range(pz - 4 * chunk_amount, pz):
			add_chunk(x, z)

func clean_up_chunks():
	var pt = $Camera3D.position
	var pz :int = int(pt.z / chunk_size)
	var fadeZ = pz + chunk_amount
	var all_keys = existing_chunks.keys()
	for key in all_keys:
		if key.y >= fadeZ:
			existing_chunks[key].queue_free()
			existing_chunks.erase(key)

func reset_chunks():
	pass

func add_chunk(x : int, z : int):
	var key = Vector2i(x, z)
	if existing_chunks.has(key) || pending_chunks.has(key):
		return
	
	pending_chunks[key] = 1
	#load_chunk(key)
	
	mutex.lock()
	work_queue.append(key)
	mutex.unlock()
	
	semaphore.post()

func run_builder_thread():
	
	while true:
		semaphore.wait()
		
		var found = true
		while found:
			var key
			found = false
			
			mutex.lock()
			if !work_queue.is_empty():
				found = true
				key = work_queue.pop_front()
			mutex.unlock()
		
			if found:
				var chunk : Node3D = chunk_scene.instantiate()
				var subdivide = chunk_subdivide
				var reduce = key.x
				while reduce > 0:
					reduce -= 1
					subdivide = int(float(subdivide + 1) / 2.0)
				chunk.c_init(noise, key, chunk_size, subdivide, chunk_height, chunk_material)
				call_deferred("load_chunk", key, chunk)

	#if not thread.is_alive():
	#	var callable = Callable(self, "load_chunk").bind(thread, x, z)
	#	thread.start(callable)
	#	building_chunks[key] = 1

func load_chunk(key: Vector2i, chunk):
	chunk.position = Vector3(key.x * chunk_size, 0, key.y * chunk_size)
	add_child(chunk)
	existing_chunks[key] = chunk
	pending_chunks.erase(key)
	if all_enemies.is_empty() && existing_chunks.size() >= 9:
		initialize_enemies()
		

func get_chunk(key : Vector2i):
	if existing_chunks.has(key):
		return existing_chunks.get(key)
	
	return null
